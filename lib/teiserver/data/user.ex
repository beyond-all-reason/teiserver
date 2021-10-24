defmodule Teiserver.User do
  @moduledoc """
  Users here are a combination of Central.Account.User and the data within. They are merged like this into a map as their expected use case is very different.
  """
  alias Teiserver.{Client, Coordinator}
  alias Teiserver.EmailHelper
  alias Teiserver.Account
  alias Teiserver.Account.{UserCache, RelationsLib}
  alias Argon2
  alias Central.Account.Guardian
  alias Teiserver.Data.Types, as: T
  import Central.Helpers.TimexHelper, only: [parse_ymd_t_hms: 1, date_to_str: 2]

  require Logger
  alias Phoenix.PubSub
  alias Teiserver.EmailHelper
  alias Teiserver.Account

  @timer_sleep 500
  @max_username_length 20

  @spec role_list :: [String.t()]
  def role_list(), do: ~w(Tester Streamer Donor Contributor Dev Moderator Admin Verified Bot)

  @keys [:id, :name, :email, :inserted_at, :clan_id]
  def keys(), do: @keys

  @data_keys [
    :rank,
    :ip,
    :moderator,
    :bot,
    :friends,
    :friend_requests,
    :ignored,
    :password_hash,
    :verification_code,
    :verified,
    :email_change_code,
    :last_login,
    :banned,
    :muted,
    :warned,
    :shadowbanned,
    :springid,
    :lobby_hash,
    :roles
  ]
  def data_keys(), do: @data_keys

  @default_data %{
    rank: 1,
    ip: "default_ip",
    moderator: false,
    bot: false,
    friends: [],
    friend_requests: [],
    ignored: [],
    password_hash: nil,
    verification_code: nil,
    verified: false,
    email_change_code: nil,
    last_login: nil,
    banned: [false, nil],
    muted: [false, nil],
    warned: [false, nil],
    shadowbanned: false,
    springid: nil,
    lobby_hash: [],
    roles: []
  }

  def default_data(), do: @default_data

  @rank_levels [
    5,
    15,
    30,
    100,
    300,
    1000,
    3000
  ]

  def next_springid() do
    ConCache.isolated(:id_counters, :springid, fn ->
      new_value = ConCache.get(:id_counters, :springid) + 1
      ConCache.put(:id_counters, :springid, new_value)
      new_value
    end)
  end

  @spec clean_name(String.t()) :: String.t()
  def clean_name(name) do
    ~r/([^a-zA-Z0-9_\[\]\{\}]|\s)/
    |> Regex.replace(name, "")
  end

  @spec encrypt_password(any) :: binary | {binary, binary, {any, any, any, any, any}}
  def encrypt_password(password) do
    Argon2.hash_pwd_salt(password)
  end

  def spring_md5_password(password) do
    :crypto.hash(:md5, password) |> Base.encode64()
  end

  def user_register_params(name, email, md5_password, extra_data \\ %{}) do
    name = clean_name(name)
    verification_code = :rand.uniform(899_999) + 100_000
      |> to_string
    encrypted_password = encrypt_password(md5_password)

    data =
      @default_data
      |> Map.new(fn {k, v} -> {to_string(k), v} end)

    %{
      name: name,
      email: email,
      password: encrypted_password,
      colour: "#AA0000",
      icon: "fas fa-user",
      admin_group_id: Teiserver.user_group_id(),
      permissions: ["teiserver", "teiserver.player", "teiserver.player.account"],
      springid: next_springid(),
      data:
        data
        |> Map.merge(%{
          "password_hash" => encrypted_password,
          "verification_code" => verification_code,
          "verified" => false
        })
        |> Map.merge(extra_data)
    }
  end

  @spec register_user_with_md5(String.t(), String.t(), String.t(), String.t()) :: :success | {:error, String.t()}
  def register_user_with_md5(name, email, md5_password, ip) do
    name = String.trim(name)
    email = String.trim(email)

    cond do
      clean_name(name) |> String.length() > @max_username_length ->
        {:error, "Max length #{@max_username_length} characters"}

      clean_name(name) != name ->
        {:error, "Invalid characters in name (only a-z, A-Z, 0-9, [, ] allowed)"}

      get_user_by_name(name) ->
        {:error, "Username already taken"}

      get_user_by_email(email) ->
        {:error, "User already exists"}

      true ->
        case do_register_user(name, email, md5_password, ip) do
          :ok ->
            :success
          :error ->
            {:error, "Server error, please inform admin"}
        end
    end
  end

  @spec do_register_user(String.t(), String.t(), String.t(), String.t()) :: :ok | :error
  defp do_register_user(name, email, md5_password, ip) do
    name = String.trim(name)
    email = String.trim(email)

    params =
      user_register_params(name, email, md5_password, %{
        "ip" => ip
      })

    case Account.script_create_user(params) do
      {:ok, user} ->
        Account.create_group_membership(%{
          user_id: user.id,
          group_id: Teiserver.user_group_id()
        })

        # Now add them to the cache
        user
        |> convert_user
        |> Map.put(:springid, next_springid())
        |> add_user

        case EmailHelper.new_user(user) do
          {:error, error} ->
            Logger.error("Error sending new user email - #{user.email} - #{error}")
          {:ok, _email, _response} ->
            :ok
            # Logger.error("Email sent, response of #{Kernel.inspect response}")
        end
        :ok

      {:error, changeset} ->
        Logger.error(
          "Unable to create user with params #{Kernel.inspect(params)}\n#{
            Kernel.inspect(changeset)
          }"
        )
        :error
    end
  end

  def register_bot(bot_name, bot_host_id) do
    existing_bot = get_user_by_name(bot_name)

    cond do
      allow?(bot_host_id, :moderator) == false ->
        {:error, "no permission"}

      existing_bot != nil ->
        existing_bot

      true ->
        host = get_user_by_id(bot_host_id)

        params =
          user_register_params(bot_name, host.email, host.password_hash, %{
            "bot" => true,
            "verified" => true,
            "password_hash" => host.password_hash,
            "roles" => ["Bot", "Verified"]
          })
          |> Map.merge(%{
            email: String.replace(host.email, "@", ".bot#{bot_name}@")
          })

        case Account.script_create_user(params) do
          {:ok, user} ->
            Account.create_group_membership(%{
              user_id: user.id,
              group_id: Teiserver.user_group_id()
            })

            # Now add them to the cache
            user
            |> convert_user
            |> add_user

          {:error, changeset} ->
            Logger.error(
              "Unable to create user with params #{Kernel.inspect(params)}\n#{
                Kernel.inspect(changeset)
              } in register_bot(#{bot_name}, #{bot_host_id})"
            )
        end
    end
  end

  @spec rename_user(T.userid(), String.t()) :: :success | {:error, String.t()}
  def rename_user(userid, new_name) do
    cond do
      clean_name(new_name) |> String.length() > @max_username_length ->
        {:error, "Max length #{@max_username_length} characters"}

      clean_name(new_name) != new_name ->
        {:error, "Invalid characters in name (only a-z, A-Z, 0-9, [, ] allowed)"}

      get_user_by_name(new_name) ->
        {:error, "Username already taken"}

      true ->
        do_rename_user(userid, new_name)
        :success
    end
  end

  @spec do_rename_user(T.userid(), String.t()) :: :ok
  defp do_rename_user(userid, new_name) do
    user = get_user_by_id(userid)
    ban_time = Timex.now() |> Timex.shift(seconds: 15) |> date_to_str(format: :ymd_t_hms)
    update_user(%{user | banned: [true, ban_time]}, persist: true)

    # Log the current name in their history
    previous_names = Account.get_user_stat_data(userid)
      |> Map.get("previous_names", [])

    Account.update_user_stat(userid, %{"previous_names" => [user.name | previous_names]})

    # We need to re-get the user to ensure we don't overwrite our banned flag
    user = get_user_by_id(userid)
    delete_user(user.id)

    db_user = Account.get_user!(userid)
    Account.update_user(db_user, %{"name" => new_name})

    :timer.sleep(5000)
    recache_user(userid)
    user = get_user_by_id(userid)
    update_user(%{user | banned: [false, nil]}, persist: true)
    :ok
  end


  def request_password_reset(user) do
    db_user = Account.get_user!(user.id)

    Central.Account.UserLib.reset_password_request(db_user)
    |> Central.Mailer.deliver_now()
  end

  def request_email_change(nil, _), do: nil

  def request_email_change(user, new_email) do
    code = :rand.uniform(899_999) + 100_000
    update_user(%{user | email_change_code: ["#{code}", new_email]})
  end

  def change_email(user, new_email) do
    ConCache.delete(:users_lookup_id_with_email, String.downcase(user.email))
    ConCache.put(:users_lookup_id_with_email, String.downcase(new_email), user.id)
    update_user(%{user | email: new_email, email_change_code: [nil, nil]})
  end

  # Cache functions
  @spec get_username(T.userid()) :: String.t()
  defdelegate get_username(userid), to: UserCache

  @spec get_userid(String.t()) :: integer() | nil
  defdelegate get_userid(username), to: UserCache

  @spec get_user_by_name(String.t()) :: User.t() | nil
  defdelegate get_user_by_name(username), to: UserCache

  @spec get_user_by_email(String.t()) :: User.t() | nil
  defdelegate get_user_by_email(email), to: UserCache

  @spec get_user_by_token(String.t()) :: User.t() | nil
  defdelegate get_user_by_token(token), to: UserCache

  @spec get_user_by_id(T.userid()) :: User.t() | nil
  defdelegate get_user_by_id(id), to: UserCache

  @spec list_users(list) :: list
  defdelegate list_users(id_list), to: UserCache

  @spec recache_user(Integer.t()) :: :ok
  defdelegate recache_user(id), to: UserCache

  @spec pre_cache_users(atom) :: :ok
  defdelegate pre_cache_users(type), to: UserCache

  @spec convert_user(User.t()) :: User.t()
  defdelegate convert_user(user), to: UserCache

  @spec add_user(User.t()) :: User.t()
  defdelegate add_user(user), to: UserCache

  @spec update_user(User.t(), boolean) :: User.t()
  defdelegate update_user(user, persist \\ false), to: UserCache

  @spec delete_user(T.userid()) :: :ok | :no_user
  defdelegate delete_user(userid), to: UserCache


  # Friend related
  @spec accept_friend_request(T.userid() | nil, T.userid() | nil) :: User.t() | nil
  defdelegate accept_friend_request(requester, accepter), to: RelationsLib

  @spec decline_friend_request(T.userid() | nil, T.userid() | nil) :: User.t() | nil
  defdelegate decline_friend_request(requester, accepter), to: RelationsLib

  @spec create_friend_request(T.userid() | nil, T.userid() | nil) :: User.t() | nil
  defdelegate create_friend_request(requester, accepter), to: RelationsLib

  @spec ignore_user(T.userid() | nil, T.userid() | nil) :: User.t() | nil
  defdelegate ignore_user(requester, accepter), to: RelationsLib

  @spec unignore_user(T.userid() | nil, T.userid() | nil) :: User.t() | nil
  defdelegate unignore_user(requester, accepter), to: RelationsLib

  @spec remove_friend(T.userid() | nil, T.userid() | nil) :: User.t() | nil
  defdelegate remove_friend(requester, accepter), to: RelationsLib

  @spec list_combined_friendslist([T.userid()]) :: [User.t()]
  defdelegate list_combined_friendslist(userids), to: RelationsLib

  @spec send_direct_message(T.userid(), T.userid(), String.t()) :: :ok
  def send_direct_message(from_id, to_id, "!start" <> s), do: send_direct_message(from_id, to_id, "!cv start" <> s)
  def send_direct_message(from_id, to_id, "!joinas" <> s), do: send_direct_message(from_id, to_id, "!cv joinas" <> s)

  def send_direct_message(from_id, to_id, message_content) do
    sender = get_user_by_id(from_id)
    if not is_muted?(sender) do
      PubSub.broadcast(
        Central.PubSub,
        "legacy_user_updates:#{to_id}",
        {:direct_message, from_id, message_content}
      )

      PubSub.broadcast(
        Central.PubSub,
        "teiserver_client_messages:#{to_id}",
        {:client_message, :direct_message, to_id, {from_id, message_content}}
      )
    end
    :ok
  end

  @spec ring(T.userid(), T.userid()) :: :ok
  def ring(ringee_id, ringer_id) do
    PubSub.broadcast(Central.PubSub, "legacy_user_updates:#{ringee_id}", {:action, {:ring, ringer_id}})
    PubSub.broadcast(Central.PubSub, "teiserver_client_application:#{ringee_id}", {:teiserver_client_application, :ring, ringee_id, ringer_id})
    :ok
  end

  @spec test_password(String.t(), String.t()) :: boolean
  def test_password(plain_password, encrypted_password) do
    Argon2.verify_pass(plain_password, encrypted_password)
  end

  def verify_user(user) do
    %{user | verification_code: nil, verified: true, roles: ["Verified" | user.roles]}
    |> update_user(persist: true)
  end

  @spec create_token(Central.Account.User.t()) :: String.t()
  def create_token(user) do
    {:ok, jwt, _} = Guardian.encode_and_sign(user)
    jwt
  end

  @spec wait_for_precache() :: :ok
  defp wait_for_precache() do
    if ConCache.get(:application_metadata_cache, "teiserver_startup_completed") != true do
      :timer.sleep(@timer_sleep)
      wait_for_precache()
    else
      :ok
    end
  end

  @spec login_flood_check(integer()) :: :allow | :block
  def login_flood_check(userid) do
    login_count = ConCache.get(:teiserver_login_count, userid) || 0

    if login_count > 3 do
      :block
    else
      ConCache.put(:teiserver_login_count, userid, login_count + 1)
      :allow
    end
  end

  @spec internal_client_login(integer()) :: {:ok, Map.t()} | :error
  def internal_client_login(userid) do
    case get_user_by_id(userid) do
      nil -> :error
      user ->
        do_login(user, "127.0.0.1", "Teiserver Internal Client", "IC")
        Client.login(user, self())
        {:ok, user}
    end
  end

  @spec try_login(String.t(), String.t(), String.t(), String.t()) :: {:ok, Map.t()} | {:error, String.t()} | {:error, String.t(), Integer.t()}
  def try_login(token, ip, lobby, lobby_hash) do
    wait_for_precache()

    case Guardian.resource_from_token(token) do
      {:error, _bad_token} ->
        {:error, "token_login_failed"}

      {:ok, db_user, _claims} ->
        user = get_user_by_id(db_user.id)

        cond do
          not is_bot?(user) and login_flood_check(user.id) == :block ->
            {:error, "Flood protection - Please wait 20 seconds and try again"}

          Enum.member?(["", "0", nil], lobby_hash) == true and not is_bot?(user) ->
            {:error, "LobbyHash/UserID missing in login"}

          # Used for testing, this should never be enabled in production
          Application.get_env(:central, Teiserver)[:autologin] ->
            do_login(user, ip, lobby, lobby_hash)

          is_banned?(user) ->
            [_, until] = user.data.banned

            if until == nil do
              {:error, "Banned"}
            else
              {:error, "Banned until #{until}"}
            end

          not is_verified?(user) ->
            Account.update_user_stat(user.id, %{
              lobby_client: lobby,
              lobby_hash: lobby_hash,
              last_ip: ip
            })
            {:error, "Unverified", user.id}

          Client.get_client_by_id(user.id) != nil ->
            Client.disconnect(user.id, "Already logged in")
            do_login(user, ip, lobby, lobby_hash)

          true ->
            do_login(user, ip, lobby, lobby_hash)
        end
    end
  end

  @spec try_md5_login(String.t(), String.t(), String.t(), String.t(), String.t()) :: {:ok, Map.t()} | {:error, String.t()} | {:error, String.t(), Integer.t()}
  def try_md5_login(username, md5_password, ip, lobby, lobby_hash) do
    wait_for_precache()

    case get_user_by_name(username) do
      nil ->
        {:error, "No user found for '#{username}'"}

      user ->
        cond do
          user.name != username ->
            {:error, "Username is case sensitive, try '#{user.name}'"}

          not is_bot?(user) and login_flood_check(user.id) == :block ->
            {:error, "Flood protection - Please wait 20 seconds and try again"}

          Enum.member?(["", "0", nil], lobby_hash) == true and not is_bot?(user) ->
            {:error, "LobbyHash/UserID missing in login"}

          # Used for testing, this should never be enabled in production
          Application.get_env(:central, Teiserver)[:autologin] ->
            do_login(user, ip, lobby, lobby_hash)

          test_password(md5_password, user.password_hash) == false ->
            {:error, "Invalid password"}

          is_banned?(user) ->
            {:error, "Banned"}

          not is_verified?(user) ->
            Account.update_user_stat(user.id, %{
              lobby_client: lobby,
              lobby_hash: lobby_hash,
              last_ip: ip
            })
            {:error, "Unverified", user.id}

          Client.get_client_by_id(user.id) != nil ->
            Client.disconnect(user.id, "Already logged in")
            do_login(user, ip, lobby, lobby_hash)

          true ->
            do_login(user, ip, lobby, lobby_hash)
        end
    end
  end

  @spec do_login(Map.t(), String.t(), String.t(), String.t()) :: {:ok, Map.t()}
  defp do_login(user, ip, lobby_client, lobby_hash) do
    stats = Account.get_user_stat_data(user.id)

    # If they don't want a flag shown, don't show it, otherwise check for an override before trying geoip
    country =
      cond do
        Central.Config.get_user_config_cache(user.id, "teiserver.Show flag") == false ->
          "??"

        stats["country_override"] != nil ->
          stats["country_override"]

        true ->
          Teiserver.Geoip.get_flag(ip)
      end

    last_login = round(:erlang.system_time(:seconds) / 60)

    ip_list = [ip | (stats["ip_list"] || [])] |> Enum.uniq |> Enum.take(20)

    rank = calculate_rank(user.id)

    springid = if Map.get(user, :springid) != nil, do: user.springid, else: next_springid()
    |> Central.Helpers.NumberHelper.int_parse

    user =
      %{
        user
        | ip: ip,
          last_login: last_login,
          rank: rank,
          springid: springid,
          lobby_hash: lobby_hash
      }

    update_user(user, persist: true)

    # User stats
    Account.update_user_stat(user.id, %{
        bot: user.bot,
        country: country,
        last_login: :erlang.system_time(:seconds),
        rank: rank,
        lobby_client: lobby_client,
        lobby_hash: lobby_hash,
        last_ip: ip,
        ip_list: ip_list
      })

    {:ok, user}
  end

  def logout(nil), do: nil

  def logout(_user_id) do
    # We used to calculate ingame_minutes here but we now use telemetry logs for that
    nil
  end

  @spec create_report(Integer.t()) :: :ok
  def create_report(report_id) do
    report = Account.get_report!(report_id)

    if report.response_text != nil do
      update_report(report_id)
    else
      Teiserver.Bridge.DiscordBridge.moderator_report(report_id)
    end
  end

  @spec update_report(Integer.t()) :: :ok
  def update_report(report_id) do
    report = Account.get_report!(report_id)
    user = get_user_by_id(report.target_id)

    if Enum.member?(~w(Warn Mute Ban), report.response_action) do
      Teiserver.Bridge.DiscordBridge.moderator_action(report_id)
      Coordinator.update_report(user, report)
    end

    changes =
      case {report.response_action, report.expires} do
        {"Mute", nil} ->
          %{muted: [true, nil]}

        {"Mute", expires} ->
          %{muted: [true, expires]}

        {"Unmute", _} ->
          %{muted: [false, nil]}

        {"Ban", nil} ->
          %{banned: [true, nil]}

        {"Ban", expires} ->
          %{banned: [true, expires]}

        {"Unban", _} ->
          %{banned: [false, nil]}

        {"Warn", expires} ->
          %{warned: [true, expires]}

        {"Unwarn", _} ->
          %{warned: [false, nil]}

        {"Ignore report", nil} ->
          %{}

        {action, _} ->
          throw("No handler for action type '#{action}' in #{__MODULE__}")
      end

    Map.merge(user, changes)
    |> update_user(persist: true)

    # We recache because the json conversion process converts the date
    # from a date to a string of the date
    recache_user(user.id)

    if is_banned?(user.id) do
      Client.disconnect(user.id, "Banned")
    end

    :ok
  end

  @spec is_banned?(T.userid() | T.user()) :: boolean()
  def is_banned?(nil), do: true
  def is_banned?(userid) when is_integer(userid), do: is_banned?(get_user_by_id(userid))
  def is_banned?(%{banned: banned}) do
    case banned do
      [false, _] -> false
      [true, nil] -> true
      [true, until_str] ->
        until = parse_ymd_t_hms(until_str)
        Timex.compare(Timex.now(), until) != 1
    end
  end

  @spec is_muted?(T.userid() | T.user()) :: boolean()
  def is_muted?(nil), do: true
  def is_muted?(userid) when is_integer(userid), do: is_muted?(get_user_by_id(userid))
  def is_muted?(%{muted: muted}) do
    case muted do
      [false, _] -> false
      [true, nil] -> true
      [true, until_str] ->
        until = parse_ymd_t_hms(until_str)
        Timex.compare(Timex.now(), until) != 1
    end
  end

  @spec is_warned?(T.userid() | T.user()) :: boolean()
  def is_warned?(nil), do: true
  def is_warned?(userid) when is_integer(userid), do: is_warned?(get_user_by_id(userid))
  def is_warned?(%{warned: warned}) do
    case warned do
      [false, _] -> false
      [true, nil] -> true
      [true, until_str] ->
        until = parse_ymd_t_hms(until_str)
        Timex.compare(Timex.now(), until) != 1
    end
  end

  @spec is_shadowbanned?(T.userid() | T.user()) :: boolean()
  def is_shadowbanned?(nil), do: true
  def is_shadowbanned?(userid) when is_integer(userid), do: is_shadowbanned?(get_user_by_id(userid))
  def is_shadowbanned?(%{shadowbanned: true}), do: true
  def is_shadowbanned?(_), do: false

  @spec shadowban(T.userid() | T.user()) :: :ok
  def shadowban(nil), do: :ok
  def shadowban(userid) when is_integer(userid), do: shadowban(get_user_by_id(userid))
  def shadowban(user) do
    update_user(%{user | shadowbanned: true, muted: [true, nil]}, persist: true)
    Client.shadowban(user.id)
    :ok
  end

  @spec is_bot?(T.userid() | T.user()) :: boolean()
  def is_bot?(nil), do: true
  def is_bot?(userid) when is_integer(userid), do: is_bot?(get_user_by_id(userid))
  def is_bot?(%{bot: true}), do: true# TODO: Remove this once the transition is complete
  def is_bot?(%{roles: roles}), do: Enum.member?(roles, "Bot")
  def is_bot?(_), do: false

  @spec is_moderator?(T.userid() | T.user()) :: boolean()
  def is_moderator?(nil), do: true
  def is_moderator?(userid) when is_integer(userid), do: is_moderator?(get_user_by_id(userid))
  def is_moderator?(%{moderator: true}), do: true# TODO: Remove this once the transition is complete
  def is_moderator?(%{roles: roles}), do: Enum.member?(roles, "Moderator")
  def is_moderator?(_), do: false

  @spec is_verified?(T.userid() | T.user()) :: boolean()
  def is_verified?(nil), do: true
  def is_verified?(userid) when is_integer(userid), do: is_verified?(get_user_by_id(userid))
  def is_verified?(%{verified: true}), do: true# TODO: Remove this once the transition is complete
  def is_verified?(%{roles: roles}), do: Enum.member?(roles, "Verified")
  def is_verified?(_), do: false

  @spec rank_time(T.userid()) :: non_neg_integer()
  def rank_time(userid) do
    stats = Account.get_user_stat(userid) || %{data: %{}}
    ingame_minutes = (stats.data["player_minutes"] || 0) + ((stats.data["spectator_minutes"] || 0) * 0.5)
    round(ingame_minutes / 60)
  end

  # Based on actual ingame time
  @spec calculate_rank(T.userid()) :: non_neg_integer()
  def calculate_rank(userid) do
    ingame_hours = rank_time(userid)

    @rank_levels
      |> Enum.filter(fn r -> r < ingame_hours end)
      |> Enum.count()
  end

  # Used to reset the spring password of the user when the site password is updated
  def set_new_spring_password(userid, new_password) do
    user = get_user_by_id(userid)

    case user do
      nil ->
        nil

      _ ->
        md5_password = spring_md5_password(new_password)
        encrypted_password = encrypt_password(md5_password)

        update_user(%{user | password_hash: encrypted_password, verified: true},
          persist: true
        )
    end
  end

  def allow?(userid, permission) do
    user = get_user_by_id(userid)

    case permission do
      :moderator ->
        user.moderator

      :bot ->
        user.moderator or user.bot

      _ ->
        false
    end
  end
end
