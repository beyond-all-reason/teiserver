defmodule Teiserver.Account.Login do
  @moduledoc false

  alias Argon2
  alias Teiserver.Account
  alias Teiserver.Account.Auth
  alias Teiserver.Account.AuthLib
  alias Teiserver.Account.CalculateSmurfKeyTask
  alias Teiserver.Account.Guardian
  alias Teiserver.Account.LoginThrottleServer
  alias Teiserver.Account.User
  alias Teiserver.Client
  alias Teiserver.Config
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Geoip
  alias Teiserver.Plugins
  alias Teiserver.Telemetry

  use Plugins

  require Logger

  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  @timer_sleep 500

  @suspended_string "This account is temporarily suspended. You can see the #moderation-bot on discord for more details; if you need to appeal anything please use the #open-ticket channel on the discord. Be aware, trying to evade moderation by creating new accounts will result in extending the suspension or even a permanent ban."

  @smurf_string "Alt account detected. We do not allow alt accounts. Please login as your main account. Repeatedly creating alts can result in suspension or bans. If you think this account was flagged incorrectly please open a ticket on our discord and explain why."

  @spec create_token(Account.User.t()) :: String.t()
  def create_token(user) do
    {:ok, jwt, _claims} = Guardian.encode_and_sign(user)
    jwt
  end

  @spec wait_for_startup() :: :ok
  def wait_for_startup do
    if Teiserver.cache_get(:application_metadata_cache, "teiserver_partial_startup_completed") !=
         true do
      :timer.sleep(@timer_sleep)
      wait_for_startup()
    else
      :ok
    end
  end

  @spec set_flood_level(User.id(), pos_integer()) :: :ok
  def set_flood_level(user_id, value \\ 10) do
    Teiserver.cache_put(:teiserver_login_count, user_id, value)
    :ok
  end

  @spec login_flood_check(User.id()) :: :allow | :block
  def login_flood_check(userid) do
    login_count = Teiserver.cache_get(:teiserver_login_count, userid) || 0
    rate_limit = Config.get_site_config_cache("system.Login limit count")

    if login_count >= rate_limit do
      :block
    else
      Teiserver.cache_put(:teiserver_login_count, userid, login_count + 1)
      :allow
    end
  end

  @spec internal_client_login(User.id()) :: {:ok, User.t(), T.client()} | :error
  def internal_client_login(userid) do
    case Account.get_user_by_id(userid) do
      nil ->
        :error

      user ->
        {:ok, user} = do_login(user, "127.0.0.1", "Teiserver Internal Client", "IC")
        client = Client.login(user, :internal, "127.0.0.1")
        {:ok, user, client}
    end
  end

  @spec server_capacity() :: non_neg_integer()
  def server_capacity do
    client_count =
      (Teiserver.cache_get(:application_temp_cache, :telemetry_data) || %{})
      |> Map.get(:client, %{})
      |> Map.get(:total, 0)

    Config.get_site_config_cache("system.User limit") - client_count
  end

  @doc """
  This is purely used for the teiserver_test_lib async_auth_setup function
  TODO: Remove this function and create something more appropriate for the test
  """
  @spec try_login(String.t(), String.t(), String.t(), String.t()) ::
          {:ok, User.t()} | {:error, String.t()} | {:error, String.t(), User.id()}
  def try_login(token, ip, lobby, lobby_hash) do
    wait_for_startup()

    case Guardian.resource_from_token(token) do
      {:error, _bad_token} ->
        {:error, "token_login_failed"}

      {:ok, user, _claims} ->
        cond do
          user.smurf_of_id != nil ->
            Telemetry.log_complex_server_event(user.id, "Banned login", %{
              error: "Smurf"
            })

            {:error, @smurf_string}

          not Auth.is_bot?(user) and login_flood_check(user.id) == :block ->
            {:error, "Flood protection - Please wait 20 seconds and try again"}

          Enum.member?(["", "0 0", nil], lobby_hash) == true and not Auth.is_bot?(user) ->
            {:error, "LobbyHash/UserID missing in login"}

          Account.restricted?(user, ["Permanently banned"]) ->
            Telemetry.log_complex_server_event(user.id, "Banned login", %{
              error: "Permanently banned"
            })

            {:error, "Banned account"}

          Account.restricted?(user, ["Login"]) ->
            Telemetry.log_complex_server_event(user.id, "Banned login", %{
              error: "Suspended"
            })

            {:error, @suspended_string}

          not Auth.verified?(user) ->
            Account.update_user_stat(user.id, %{
              lobby_client: lobby,
              lobby_hash: lobby_hash,
              last_ip: ip
            })

            # One way hash of the creation IP. If enabled during testing we
            # will get foreign key errors as the test shuts down
            if not Application.get_env(:teiserver, Teiserver)[:test_mode] do
              Account.create_smurf_key(
                user.id,
                "ip",
                CalculateSmurfKeyTask.calculate_string_fingerprint(ip)
              )
            end

            {:error, "Unverified", user.id}

          true ->
            if Client.get_client_by_id(user.id) != nil do
              Client.disconnect(user.id, "Already logged in")
              :timer.sleep(1000)
            end

            # Okay, we're good, what's capacity looking like?
            cond do
              Auth.is_bot?(user) ->
                do_login(user, ip, lobby, lobby_hash)

              Config.get_site_config_cache("system.Use login throttle") ->
                if LoginThrottleServer.attempt_login(self(), user.id) do
                  do_login(user, ip, lobby, lobby_hash)
                else
                  {:error, "Queued", user.id, lobby, lobby_hash}
                end

              not Auth.has_any_role?(user, ["VIP", "Contributor"]) and
                  server_capacity() <= 0 ->
                {:error, "The server is currently full, please try again in a minute or two."}

              true ->
                do_login(user, ip, lobby, lobby_hash)
            end
        end
    end
  end

  @spec try_md5_login(String.t(), String.t(), String.t(), String.t(), String.t()) ::
          {:ok, User.t()} | {:error, String.t()} | {:error, String.t(), integer()}
  def try_md5_login(username, md5_password, ip, lobby, lobby_hash) do
    wait_for_startup()

    case Account.get_user_by_name(username) do
      nil ->
        {:error, "No user found for '#{username}'"}

      user ->
        cond do
          user.smurf_of_id != nil ->
            Telemetry.log_complex_server_event(user.id, "Banned login", %{
              error: "Smurf"
            })

            {:error, @smurf_string}

          user.name != username ->
            {:error, "Username is case sensitive, try '#{user.name}'"}

          not Auth.is_bot?(user) and login_flood_check(user.id) == :block ->
            {:error, "Flood protection - Please wait 20 seconds and try again"}

          Enum.member?(["", "0 0", nil], lobby_hash) == true and not Auth.is_bot?(user) ->
            {:error, "LobbyHash/UserID missing in login"}

          # Rate limited?
          Auth.can_login?(user) == false ->
            :telemetry.execute([:tachyon, :login, :error], %{count: 1}, %{
              reason: :rate_limited,
              user_id: user.id
            })

            {:error, "Flood protection"}

          Account.verify_md5_password(md5_password, user.password) == false ->
            if String.contains?(username, "@") do
              {:error,
               "Invalid password for username, check you are not using your email address as the name"}
            else
              {:error, "Invalid password"}
            end

          Account.restricted?(user, ["Permanently banned"]) ->
            Telemetry.log_complex_server_event(user.id, "Banned login", %{
              error: "Permanently banned"
            })

            {:error, "Banned account"}

          Account.restricted?(user, ["Login"]) ->
            Telemetry.log_complex_server_event(user.id, "Banned login", %{
              error: "Suspended"
            })

            {:error, @suspended_string}

          not Auth.verified?(user) ->
            # Log them in to save some details we'd not otherwise get
            do_login(user, ip, lobby, lobby_hash)

            Account.update_user_stat(user.id, %{
              lobby_client: lobby,
              lobby_hash: lobby_hash,
              last_ip: ip
            })

            {:error, "Unverified", user.id}

          # This is also defined in UserLib but that imports CacheUser so we
          # repeat it here as we don't want a circular dependency and the plan is to remove
          # this module later.
          not is_nil(user.gdpr_forget_after) ->
            host = Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]
            {:error, "You must login via the website to activate this account - #{host}/login"}

          true ->
            if Client.get_client_by_id(user.id) != nil do
              Client.disconnect(user.id, "Already logged in")
              :timer.sleep(1000)
            end

            # Okay, we're good, what's capacity looking like?
            cond do
              Auth.is_bot?(user) ->
                do_login(user, ip, lobby, lobby_hash)

              Config.get_site_config_cache("system.Use login throttle") ->
                if LoginThrottleServer.attempt_login(self(), user.id) do
                  do_login(user, ip, lobby, lobby_hash)
                else
                  {:error, "Queued", user.id, lobby, lobby_hash}
                end

              not Auth.has_any_role?(user, ["VIP", "Contributor"]) and
                  server_capacity() <= 0 ->
                {:error, "The server is currently full, please try again in a minute or two."}

              true ->
                do_login(user, ip, lobby, lobby_hash)
            end
        end
    end
  end

  @spec tachyon_login(User.t(), String.t(), String.t()) ::
          {:ok, User.t()} | {:error, String.t()} | {:error, :rate_limited, String.t()}
  def tachyon_login(user, ip, lobby_client) do
    lobby_hash = "tachyon_lobby_hash(maybe_useless)"

    cond do
      user.smurf_of_id != nil ->
        Telemetry.log_complex_server_event(user.id, "Banned login", %{
          error: "Smurf"
        })

        :telemetry.execute([:tachyon, :login, :error], %{count: 1}, %{reason: :smurf})

        {:error, @smurf_string}

      login_flood_check(user.id) == :block ->
        :telemetry.execute([:tachyon, :login, :error], %{count: 1}, %{reason: :rate_limited})
        {:error, :rate_limited, "Flood protection - Please wait 20 seconds and try again"}

      Account.restricted?(user, ["Permanently banned"]) ->
        Telemetry.log_complex_server_event(user.id, "Banned login", %{
          error: "Permanently banned"
        })

        :telemetry.execute([:tachyon, :login, :error], %{count: 1}, %{reason: :banned})

        {:error, "Banned account"}

      Account.restricted?(user, ["Login"]) ->
        Telemetry.log_complex_server_event(user.id, "Banned login", %{
          error: "Suspended"
        })

        :telemetry.execute([:tachyon, :login, :error], %{count: 1}, %{reason: :suspended})

        {:error, @suspended_string}

      not Auth.verified?(user) ->
        # Log them in to save some details we'd not otherwise get
        do_login(user, ip, lobby_client, lobby_hash)

        Account.update_user_stat(user.id, %{
          lobby_client: lobby_client,
          lobby_hash: lobby_hash,
          last_ip: ip
        })

        :telemetry.execute([:tachyon, :login, :error], %{count: 1}, %{reason: :not_verified})

        {:error, "Account is not verified"}

      # This is also defined in UserLib but that imports CacheUser so we
      # repeat it here as we don't want a circular dependency and the plan is to remove
      # this module later.
      not is_nil(user.gdpr_forget_after) ->
        host = Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]
        {:error, "You must login via the website to activate this account - #{host}/login"}

      true ->
        # TODO: copy/paste the capacity restriction and queuing from try_md5_login later
        :telemetry.execute([:tachyon, :login, :ok], %{count: 1})
        do_login(user, ip, lobby_client, lobby_hash)
    end
  end

  # TODO: once we got rid of spring, do_login should not accept the IP as a string
  # but as a :inet.ip_address which is what we get from the conn object
  # And then we need to stringify it as usual when storing in DB
  @spec do_login(User.t(), String.t(), String.t(), String.t()) :: {:ok, User.t()}
  def do_login(user, ip, lobby_client, lobby_hash) do
    stats = Account.get_user_stat_data(user.id)
    ip = Map.get(stats, "ip_override", ip)
    bot? = Auth.is_bot?(user.id)

    # If they don't want a flag shown, don't show it, otherwise
    # check for an override before trying geoip
    country = get_country(user, ip)

    # Rank
    rank =
      if is_nil(stats["rank_override"]) do
        calculate_rank(user.id)
      else
        stats["rank_override"] |> int_parse()
      end

    # We don't care about the lobby version so much as we do about the lobby itself
    lobby_client =
      case Regex.run(~r/^[a-zA-Z\ ]+/, lobby_client) do
        [match | _rest] ->
          match

        _no_match ->
          lobby_client
      end

    last_login = DateTime.utc_now()
    user = %{user | last_login: last_login}

    Account.script_update_user(user, %{last_login: last_login})

    Account.update_user_stat(user.id, %{
      country: country,
      rank: rank,
      lobby_client: lobby_client,
      lobby_hash: lobby_hash,
      last_ip: ip
    })

    # These steps are not needed for most tests so we can skip them as they
    # can cause flakiness
    if not Application.get_env(:teiserver, Teiserver)[:test_mode] do
      Telemetry.log_simple_server_event(user.id, "account.user_login")

      if not bot? do
        Account.create_smurf_key(
          user.id,
          "ip",
          CalculateSmurfKeyTask.calculate_string_fingerprint(ip)
        )

        Account.create_smurf_key(user.id, "client_app_hash", lobby_hash)
      end
    end

    {:ok, user}
  end

  @spec get_country(User.t(), String.t()) :: String.t()
  @decorate Plugins.plugin(:get_country)
  def get_country(user, ip) do
    stats = Account.get_user_stat_data(user.id)

    raw_country =
      cond do
        Config.get_user_config_cache(user.id, "teiserver.Show flag") == false ->
          "??"

        AuthLib.allow?(user, "BAR+") and Map.has_key?(stats, "bar_plus.flag") ->
          stats["bar_plus.flag"]

        stats["country_override"] != nil ->
          stats["country_override"]

        true ->
          # Only call to geoip if the IP has changed
          last_ip = Account.get_user_stat_data(user.id) |> Map.get("last_ip")

          if last_ip != ip or (stats["country"] || "??") == "??" do
            Geoip.get_flag(ip, stats["country"])
          else
            stats["country"] || "??"
          end
      end

    c =
      raw_country
      |> String.trim()
      |> String.upcase()

    # Handler in case they somehow have an empty country after this
    case c do
      "" -> "??"
      c -> c
    end
  end

  @spec rank_time(User.id()) :: non_neg_integer()
  @decorate Plugins.plugin(:rank_time)
  def rank_time(userid) do
    stats = Account.get_user_stat(userid) || %{data: %{}}

    ingame_minutes =
      (stats.data["player_minutes"] || 0) + (stats.data["spectator_minutes"] || 0) * 0.5

    # Hours are rounded down which helps to determine if a user has hit a
    # chevron hours threshold. So a user with 4.9 hours is still chevron 1 or rank 0
    trunc(ingame_minutes / 60)
  end

  # Based on actual ingame time
  @spec calculate_rank(User.id(), String.t()) :: non_neg_integer()
  def calculate_rank(userid, "Playtime") do
    ingame_hours = rank_time(userid)

    [5, 15, 30, 100, 300, 1000, 3000]
    |> Enum.count(fn r -> r <= ingame_hours end)
  end

  # Using leaderboard rating
  def calculate_rank(userid, "Leaderboard rating") do
    rating = Account.get_player_highest_leaderboard_rating(userid)

    [3, 7, 12, 21, 26, 35, 1000]
    |> Enum.count(fn r -> r <= rating end)
  end

  def calculate_rank(userid, "Uncertainty") do
    uncertainty =
      Account.get_player_lowest_uncertainty(userid)
      |> :math.ceil()

    (8 - uncertainty)
    |> max(0)
    |> max(7)
  end

  def calculate_rank(userid, "Role") do
    ingame_hours = rank_time(userid)

    # Thresholds should match what is on the website:
    # https://www.beyondallreason.info/guide/rating-and-lobby-balance#rank-icons
    cond do
      Auth.has_any_role?(userid, ["Tournament winner"]) ->
        7

      Auth.contributor?(userid) and
          !Account.hide_contributor_rank?(userid) ->
        6

      ingame_hours >= 1000 ->
        5

      ingame_hours >= 250 ->
        4

      ingame_hours >= 100 ->
        3

      ingame_hours >= 15 ->
        2

      ingame_hours >= 5 ->
        1

      true ->
        0
    end
  end

  @spec calculate_rank(User.id()) :: non_neg_integer()
  def calculate_rank(userid) do
    method = Config.get_site_config_cache("profile.Rank method")
    calculate_rank(userid, method)
  end
end
