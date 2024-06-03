defmodule Teiserver.CacheUser do
  @moduledoc """
  Users here are a combination of Teiserver.Account.User and the data within. They are merged like this into a map as their expected use case is very different.
  """
  alias Teiserver.{Account, Config, Client, Coordinator, Telemetry, Chat, EmailHelper}
  alias Teiserver.Account.{LoginThrottleServer, UserCacheLib, Guardian}
  alias Teiserver.Chat.WordLib
  alias Argon2
  alias Teiserver.Data.Types, as: T
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  require Logger
  alias Phoenix.PubSub

  @timer_sleep 500

  @default_colour "#666666"
  @default_icon "fa-solid fa-user"

  @suspended_string "This account is temporarily suspended. You can see the #moderation-bot on discord for more details; if you need to appeal anything please use the #open-ticket channel on the discord. Be aware, trying to evade moderation by creating new accounts will result in extending the suspension or even a permanent ban."

  @smurf_string "Alt account detected. We do not allow alt accounts. Please login as your main account. Repeatedly creating alts can result in suspension or bans. If you think this account was flagged incorrectly please open a ticket on our discord and explain why."

  # Keys kept from the raw user and merged into the memory user
  @spec keys() :: [atom]
  def keys(),
    do:
      ~w(id name email inserted_at clan_id permissions colour icon behaviour_score trust_score  social_score smurf_of_id last_login_timex last_played last_logout roles discord_id)a

  # This is the version of keys with the extra fields we're going to be moving from data to the object itself
  # def keys(),
  #   do: ~w(id name email inserted_at clan_id permissions colour icon behaviour_score trust_score smurf_of_id roles restrictions restricted_until shadowbanned last_login last_played last_logout discord_id steam_id)a

  @data_keys [
    :rank,
    :country,
    :bot,
    :password_hash,
    :verified,
    :email_change_code,
    :last_login,
    :last_login_mins,
    :last_login_timex,
    :restrictions,
    :restricted_until,
    :shadowbanned,
    :lobby_hash,
    :hw_hash,
    :chobby_hash,
    :lobby_client,
    :roles,
    :print_client_messages,
    :print_server_messages,
    :spring_password,
    :discord_id,
    :discord_dm_channel,
    :discord_dm_channel_id,
    :steam_id
  ]
  def data_keys(), do: @data_keys

  @default_data %{
    rank: 0,
    country: "??",
    moderator: false,
    bot: false,
    password_hash: nil,
    verified: false,
    email_change_code: nil,
    last_login: nil,
    last_login_mins: nil,
    last_login_timex: nil,
    restrictions: [],
    restricted_until: nil,
    shadowbanned: false,
    lobby_hash: [],
    hw_hash: nil,
    chobby_hash: nil,
    roles: [],
    print_client_messages: false,
    print_server_messages: false,
    spring_password: true,
    discord_id: nil,
    discord_dm_channel: nil,
    discord_dm_channel_id: nil,
    steam_id: nil
  }

  def default_data(), do: @default_data

  @spec clean_name(String.t()) :: String.t()
  def clean_name(name) do
    ~r/([^a-zA-Z0-9_\[\]\{\}]|\s)/
    |> Regex.replace(name, "")
  end

  @spec encrypt_password(any) :: binary | {binary, binary, {any, any, any, any, any}}
  def encrypt_password(password) do
    Argon2.hash_pwd_salt(password)
  end

  @spec spring_md5_password(String.t()) :: String.t()
  def spring_md5_password(password) do
    :crypto.hash(:md5, password) |> Base.encode64()
  end

  @spec user_register_params(String.t(), String.t(), String.t(), map()) :: map()
  def user_register_params(name, email, password, extra_data \\ %{}) do
    name = clean_name(name)
    encrypted_password = encrypt_password(password)

    data =
      @default_data
      |> Map.new(fn {k, v} -> {to_string(k), v} end)

    %{
      name: name,
      email: email,
      password: encrypted_password,
      colour: @default_colour,
      icon: @default_icon,
      roles: ["Verified"],
      permissions: ["Verified"],
      behaviour_score: 10_000,
      trust_score: 10_000,
      data:
        data
        |> Map.merge(%{
          "password_hash" => encrypted_password,
          "verified" => false
        })
        |> Map.merge(extra_data)
    }
  end

  def user_register_params_with_md5(name, email, md5_password, extra_data \\ %{}) do
    name = clean_name(name)
    encrypted_password = encrypt_password(md5_password)

    data =
      @default_data
      |> Map.new(fn {k, v} -> {to_string(k), v} end)

    %{
      name: name,
      email: email,
      password: encrypted_password,
      colour: @default_colour,
      icon: @default_icon,
      roles: ["Verified"],
      permissions: ["Verified"],
      behaviour_score: 10_000,
      trust_score: 10_000,
      data:
        data
        |> Map.merge(%{
          "password_hash" => encrypted_password,
          "verified" => false
        })
        |> Map.merge(extra_data)
    }
  end

  @spec register_user(String.t(), String.t(), String.t()) :: :success | {:error, String.t()}
  def register_user(name, email, password) do
    name = String.trim(name)
    email = String.trim(email)

    max_username_length = Config.get_site_config_cache("teiserver.Username max length")

    cond do
      Config.get_site_config_cache("teiserver.Enable registrations") == false ->
        {:error, "Registrations are currently disabled"}

      WordLib.reserved_name?(name) ->
        {:error, "That name is in restricted for use by the server, please choose another"}

      WordLib.acceptable_name?(name) == false ->
        {:error, "Not an acceptable name, please see section 1.4 of the code of conduct"}

      clean_name(name) |> String.length() > max_username_length ->
        {:failure, "Max length #{max_username_length} characters"}

      clean_name(name) != name ->
        {:failure, "Invalid characters in name (only a-z, A-Z, 0-9, [, ] and _ allowed)"}

      get_user_by_name(name) ->
        {:failure, "Username already taken"}

      get_user_by_email(email) ->
        {:failure, "Email already in use"}

      valid_email?(email) == false ->
        {:error, "Invalid email"}

      valid_password?(password) == false ->
        {:error, "Invalid password"}

      true ->
        case do_register_user(name, email, password) do
          :ok ->
            :success

          :error ->
            {:error, "Server error, please inform admin"}
        end
    end
  end

  @spec register_user_with_md5(String.t(), String.t(), String.t(), String.t()) ::
          :success | {:error, String.t()}
  def register_user_with_md5(name, email, md5_password, ip) do
    name = String.trim(name)
    email = String.trim(email)
    max_username_length = Config.get_site_config_cache("teiserver.Username max length")

    cond do
      Config.get_site_config_cache("teiserver.Enable registrations") == false ->
        {:error, "Registrations are currently disabled"}

      WordLib.reserved_name?(name) ->
        {:error, "That name is in restricted for use by the server, please choose another"}

      WordLib.acceptable_name?(name) == false ->
        {:error, "Not an acceptable name, please see section 1.4 of the code of conduct"}

      clean_name(name) |> String.length() > max_username_length ->
        {:error, "Max length #{max_username_length} characters"}

      clean_name(name) != name ->
        {:error, "Invalid characters in name (only a-z, A-Z, 0-9, [, ] and _ allowed)"}

      get_user_by_name(name) ->
        {:error, "Username already taken"}

      get_user_by_email(email) ->
        {:error, "Email already attached to a user (#{email})"}

      valid_email?(email) == false ->
        {:error, "Invalid email"}

      # MD5 hash of empty password from Chobby
      md5_password == "1B2M2Y8AsgTpgAmY7PhCfg==" ->
        {:error, "Invalid password"}

      true ->
        case do_register_user_with_md5(name, email, md5_password, ip) do
          :ok ->
            :success

          :error ->
            {:error, "Server error, please inform admin"}
        end
    end
  end

  @spec do_register_user(String.t(), String.t(), String.t()) :: :ok | :error
  defp do_register_user(name, email, password) do
    name = String.trim(name)
    email = String.trim(email)

    params = user_register_params(name, email, password)

    case Account.script_create_user(params) do
      {:ok, user} ->
        Account.update_user_stat(user.id, %{
          "verification_code" => (:rand.uniform(899_999) + 100_000) |> to_string
        })

        # Now add them to the cache
        user
        |> convert_user
        |> Map.put(:password_hash, spring_md5_password(password))
        |> Map.put(:spring_password, false)
        |> add_user
        |> update_user(persist: true)

        cond do
          String.ends_with?(user.email, "@agents") ->
            :ok

          String.ends_with?(user.email, "@hailstorm") ->
            :ok

          String.ends_with?(user.email, "@hailstorm_spring") ->
            :ok

          String.ends_with?(user.email, "@hailstorm_tachyon") ->
            :ok

          true ->
            case EmailHelper.new_user(user) do
              {:error, error} ->
                Logger.error("Error sending new user email - #{user.email} - #{error}")

              :no_verify ->
                verify_user(get_user_by_id(user.id))

              {:ok, _, _} ->
                :ok
            end
        end

        :ok

      {:error, _changeset} ->
        :error
    end
  end

  @spec do_register_user_with_md5(String.t(), String.t(), String.t(), String.t()) :: :ok | :error
  defp do_register_user_with_md5(name, email, md5_password, ip) do
    name = String.trim(name)
    email = String.trim(email)

    params = user_register_params_with_md5(name, email, md5_password, %{})

    case Account.script_create_user(params) do
      {:ok, user} ->
        Account.update_user_stat(user.id, %{
          "country" => Teiserver.Geoip.get_flag(ip),
          "verification_code" => (:rand.uniform(899_999) + 100_000) |> to_string
        })

        # Now add them to the cache
        user
        |> convert_user
        |> add_user

        if not String.ends_with?(user.email, "@agents") do
          case EmailHelper.new_user(user) do
            {:error, error} ->
              Logger.error(
                "Error sending new user email - #{user.email} - #{Kernel.inspect(error)}"
              )

            :no_verify ->
              verify_user(get_user_by_id(user.id))
              :ok

            {:ok, _, _} ->
              :ok
          end
        end

        :ok

      {:error, _changeset} ->
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
          user_register_params_with_md5(bot_name, host.email, host.password_hash, %{
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
            # Now add them to the cache
            user
            |> convert_user
            |> add_user

          {:error, changeset} ->
            Logger.error(
              "Unable to create bot with params #{Kernel.inspect(params)}\n#{Kernel.inspect(changeset)} in register_bot(#{bot_name}, #{bot_host_id})"
            )
        end
    end
  end

  @spec rename_user(T.userid(), String.t(), boolean) :: :success | {:error, String.t()}
  def rename_user(userid, new_name, admin_action \\ false) do
    rename_log =
      Account.get_user_stat_data(userid)
      |> Map.get("rename_log", [])

    new_name = String.trim(new_name)

    now = System.system_time(:second)
    # since_most_recent_rename = now - (Enum.slice(rename_log, 0..0) ++ [0] |> hd)
    since_rename_two = now - ((Enum.slice(rename_log, 1..1) ++ [0, 0, 0]) |> hd)
    since_rename_three = now - ((Enum.slice(rename_log, 2..2) ++ [0, 0, 0]) |> hd)
    max_username_length = Config.get_site_config_cache("teiserver.Username max length")

    cond do
      is_restricted?(userid, ["Community", "Renaming"]) ->
        {:error, "Your account is restricted from renaming"}

      admin_action == false and WordLib.reserved_name?(new_name) == true ->
        {:error, "That name is in restricted for use by the server, please choose another"}

      admin_action == false and WordLib.acceptable_name?(new_name) == false ->
        {:error, "Not an acceptable name, please see section 1.4 of the code of conduct"}

      # Can't rename more than 2 times in 5 days
      admin_action == false and since_rename_two < 60 * 60 * 24 * 5 ->
        {:error,
         "If you keep changing your name people won't know who you are; give it a bit of time (5 days)"}

      # Can't rename more than 3 times in 30 days
      admin_action == false and since_rename_three < 60 * 60 * 24 * 30 ->
        {:error,
         "If you keep changing your name people won't know who you are; give it a bit of time (30 days)"}

      admin_action == false and is_restricted?(userid, ["All chat", "Renaming"]) ->
        {:error, "Muted"}

      clean_name(new_name) |> String.length() > max_username_length ->
        {:error, "Max length #{max_username_length} characters"}

      clean_name(new_name) != new_name ->
        {:error, "Invalid characters in name (only a-z, A-Z, 0-9, [, ] allowed)"}

      get_user_by_name(new_name) &&
          get_user_by_name(new_name).name |> String.downcase() == String.downcase(new_name) ->
        {:error, "Username already taken"}

      true ->
        do_rename_user(userid, new_name)
        :success
    end
  end

  @spec do_rename_user(T.userid(), String.t()) :: :ok
  defp do_rename_user(userid, new_name) do
    client = Account.get_client_by_id(userid)

    user = get_user_by_id(userid)
    old_name = user.name

    set_flood_level(user.id, 10)
    Client.disconnect(userid, "Rename")
    :timer.sleep(100)

    # Log the current name in their history
    previous_names =
      Account.get_user_stat_data(userid)
      |> Map.get("previous_names", [])

    rename_log =
      Account.get_user_stat_data(userid)
      |> Map.get("rename_log", [])

    Account.update_user_stat(userid, %{
      "rename_log" => [System.system_time(:second) | rename_log],
      "previous_names" => Enum.uniq([old_name | previous_names])
    })

    # We need to re-get the user to ensure we don't overwrite our banned flag
    user = get_user_by_id(userid)
    decache_user(user.id)

    db_user = Account.get_user!(userid)
    Account.update_user(db_user, %{"name" => new_name})

    if client != nil do
      :timer.sleep(5000)
    end

    Teiserver.cache_delete(:users_lookup_id_with_name, old_name)
    recache_user(userid)
    :ok
  end

  @doc """
  Used to change the name of an internal client, should not be triggered
  by user events.
  """
  @spec system_change_user_name(T.userid(), String.t()) :: :ok
  def system_change_user_name(userid, new_name) do
    Client.disconnect(userid, "System rename")

    db_user = Account.get_user!(userid)
    Account.update_user(db_user, %{"name" => new_name})

    :timer.sleep(100)
    recache_user(userid)
    :ok
  end

  @spec request_email_change(T.user() | nil, String.t()) :: {:ok, T.user()} | {:error, String.t()}
  def request_email_change(nil, _), do: {:error, "no user"}

  def request_email_change(user, new_email) do
    case get_user_by_email(new_email) do
      nil ->
        code = :rand.uniform(899_999) + 100_000
        {:ok, update_user(%{user | email_change_code: ["#{code}", new_email]})}

      _ ->
        {:error, "Email already in use"}
    end
  end

  @spec change_email(T.user(), String.t()) :: T.user()
  def change_email(user, new_email) do
    decache_user(user.id)
    update_user(%{user | email: new_email, email_change_code: [nil, nil]}, persist: true)
  end

  # Cache functions
  @spec get_username(T.userid()) :: String.t() | nil
  defdelegate get_username(userid), to: UserCacheLib

  @spec get_userid(String.t()) :: integer() | nil
  defdelegate get_userid(username), to: UserCacheLib

  @spec get_user_by_name(String.t()) :: T.user() | nil
  defdelegate get_user_by_name(username), to: UserCacheLib

  @spec get_user_by_email(String.t()) :: T.user() | nil
  defdelegate get_user_by_email(email), to: UserCacheLib

  @spec get_user_by_discord_id(String.t()) :: T.user() | nil
  defdelegate get_user_by_discord_id(discord_id), to: UserCacheLib

  @spec get_userid_by_discord_id(String.t()) :: T.userid() | nil
  defdelegate get_userid_by_discord_id(discord_id), to: UserCacheLib

  @spec get_user_by_token(String.t()) :: T.user() | nil
  defdelegate get_user_by_token(token), to: UserCacheLib

  @spec get_user_by_id(T.userid()) :: T.user() | nil
  defdelegate get_user_by_id(id), to: UserCacheLib

  @spec list_users(list) :: list
  defdelegate list_users(id_list), to: UserCacheLib

  @spec recache_user(Integer.t()) :: :ok
  defdelegate recache_user(id), to: UserCacheLib

  @spec convert_user(T.user()) :: T.user()
  defdelegate convert_user(user), to: UserCacheLib

  @spec add_user(T.user()) :: T.user()
  defdelegate add_user(user), to: UserCacheLib

  @spec update_user(T.user(), boolean) :: T.user()
  defdelegate update_user(user, persist \\ false), to: UserCacheLib

  @spec decache_user(T.userid()) :: :ok | :no_user
  defdelegate decache_user(userid), to: UserCacheLib

  @spec send_direct_message(T.userid(), T.userid(), String.t()) :: :ok
  def send_direct_message(from_id, to_id, "!joinas" <> s),
    do: send_direct_message(from_id, to_id, "!cv joinas" <> s)

  def send_direct_message(sender_id, to_id, message_parts) when is_list(message_parts) do
    sender = get_user_by_id(sender_id)
    msg_str = Enum.join(message_parts, "\n")

    blacklisted = is_bot?(sender) == false and WordLib.blacklisted_phrase?(msg_str)

    allowed =
      cond do
        blacklisted -> false
        is_restricted?(sender, ["All chat", "Direct chat"]) -> false
        true -> true
      end

    if blacklisted do
      shadowban_user(sender_id)
    end

    if allowed do
      if is_bot?(to_id) do
        message_parts
        |> Enum.each(fn line ->
          cond do
            String.starts_with?(line, "!clan ") ->
              clan =
                line
                |> String.replace("!clan ", "")
                |> String.trim()

              Account.update_user_stat(sender_id, %{"clan" => clan})

            true ->
              :ok
          end
        end)
      end

      # Persist but only if no bots are involved
      if not is_bot?(to_id) and not is_bot?(sender_id) do
        Chat.create_direct_message(%{
          to_id: to_id,
          from_id: sender_id,
          content: msg_str,
          inserted_at: Timex.now(),
          delivered: true
        })
      end

      PubSub.broadcast(
        Teiserver.PubSub,
        "legacy_user_updates:#{to_id}",
        {:direct_message, sender_id, message_parts}
      )

      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_client_messages:#{to_id}",
        %{
          channel: "teiserver_client_messages:#{to_id}",
          event: :received_direct_message,
          sender_id: sender_id,
          message_content: message_parts
        }
      )
    end

    :ok
  end

  def send_direct_message(_, _, nil), do: :ok

  def send_direct_message(from_id, to_id, message) do
    if String.starts_with?(message, "!clan") do
      host = Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]
      website_url = "https://#{host}"

      Coordinator.send_to_user(
        from_id,
        "SPADS clans have been replaced by parties. You can access them via #{website_url}/teiserver/parties."
      )

      uuid = ExULID.ULID.generate()
      client = Account.get_client_by_id(from_id)

      {:ok, _code} =
        Account.create_code(%{
          value: uuid <> "$#{client.ip}",
          purpose: "one_time_login",
          expires: Timex.now() |> Timex.shift(minutes: 5),
          user_id: from_id
        })

      url = "https://#{host}/one_time_login/#{uuid}"

      Coordinator.send_to_user(
        from_id,
        "If you have not already logged in, here is a one-time link to do so automatically - #{url}"
      )
    end

    send_direct_message(from_id, to_id, [message])
  end

  @spec ring(T.userid(), T.userid()) :: :ok
  def ring(ringee_id, ringer_id) do
    PubSub.broadcast(
      Teiserver.PubSub,
      "legacy_user_updates:#{ringee_id}",
      {:action, {:ring, ringer_id}}
    )

    PubSub.broadcast(
      Teiserver.PubSub,
      "client_application:#{ringee_id}",
      %{
        channel: "client_application:#{ringee_id}",
        event: :ring,
        userid: ringee_id,
        ringer_id: ringer_id
      }
    )

    :ok
  end

  @spec test_password(String.t(), String.t()) :: boolean
  def test_password(plain_password, encrypted_password) do
    Argon2.verify_pass(plain_password, encrypted_password)
  end

  @spec verify_user(T.user()) :: T.user()
  def verify_user(user) do
    Account.delete_user_stat_keys(user.id, ~w(verification_code))

    %{user | verified: true, roles: ["Verified" | user.roles]}
    |> update_user(persist: true)
  end

  @spec add_roles(T.user() | T.userid(), [String.t()]) :: nil | T.user()
  def add_roles(nil, _), do: nil
  def add_roles(_, []), do: nil
  def add_roles(_, nil), do: nil

  def add_roles(userid, roles) when is_integer(userid),
    do: add_roles(get_user_by_id(userid), roles)

  def add_roles(user, roles) do
    new_roles = Enum.uniq(roles ++ user.roles)
    update_user(%{user | roles: new_roles}, persist: true)
  end

  @spec remove_roles(T.user() | T.userid(), [String.t()]) :: nil | T.user()
  def remove_roles(nil, _), do: nil
  def remove_roles(_, []), do: nil

  def remove_roles(userid, roles) when is_integer(userid),
    do: remove_roles(get_user_by_id(userid), roles)

  def remove_roles(user, removed_roles) do
    new_roles =
      user.roles
      |> Enum.reject(fn r -> Enum.member?(removed_roles, r) end)

    update_user(%{user | roles: new_roles}, persist: true)
  end

  @spec create_token(Teiserver.Account.User.t()) :: String.t()
  def create_token(user) do
    {:ok, jwt, _} = Guardian.encode_and_sign(user)
    jwt
  end

  @spec wait_for_startup() :: :ok
  def wait_for_startup() do
    if Teiserver.cache_get(:application_metadata_cache, "teiserver_partial_startup_completed") !=
         true do
      :timer.sleep(@timer_sleep)
      wait_for_startup()
    else
      :ok
    end
  end

  @spec set_flood_level(T.userid(), Integer) :: :ok
  def set_flood_level(userid, value \\ 10) do
    Teiserver.cache_put(:teiserver_login_count, userid, value)
    :ok
  end

  @spec login_flood_check(T.userid()) :: :allow | :block
  def login_flood_check(userid) do
    login_count = Teiserver.cache_get(:teiserver_login_count, userid) || 0
    rate_limit = Config.get_site_config_cache("system.Login limit count")

    if login_count > rate_limit do
      :block
    else
      Teiserver.cache_put(:teiserver_login_count, userid, login_count + 1)
      :allow
    end
  end

  @spec internal_client_login(T.userid()) :: {:ok, T.user(), T.client()} | :error
  def internal_client_login(userid) do
    case get_user_by_id(userid) do
      nil ->
        :error

      user ->
        {:ok, user} = do_login(user, "127.0.0.1", "Teiserver Internal Client", "IC")
        client = Client.login(user, :internal, "127.0.0.1")
        {:ok, user, client}
    end
  end

  @spec server_capacity() :: non_neg_integer()
  def server_capacity() do
    client_count =
      (Teiserver.cache_get(:application_temp_cache, :telemetry_data) || %{})
      |> Map.get(:client, %{})
      |> Map.get(:total, 0)

    Config.get_site_config_cache("system.User limit") - client_count
  end

  @spec ip_to_string(String.t() | tuple()) :: Tuple.t()
  defp ip_to_string({a, b, c, d}) do
    "#{a}.#{b}.#{c}.#{d}"
  end

  defp ip_to_string(ip) do
    to_string(ip)
  end

  @spec login_from_token(String.t(), map()) ::
          {:ok, T.user()} | {:error, String.t()} | {:error, String.t(), T.userid()}
  def login_from_token(token, ws_state) do
    ip = get_in(ws_state, [:connect_info, :peer_data, :address]) |> ip_to_string
    _user_agent = get_in(ws_state, [:connect_info, :user_agent])
    application_hash = ws_state.params["application_hash"]
    application_name = ws_state.params["application_name"]
    application_version = ws_state.params["application_version"]

    wait_for_startup()

    user = get_user_by_id(token.user.id)

    # # If they're a smurf, log them in as the smurf!
    # user =
    #   if user.smurf_of_id != nil do
    #     get_user_by_id(user.smurf_of_id)
    #   else
    #     user
    #   end

    cond do
      user.smurf_of_id != nil ->
        Telemetry.log_complex_server_event(user.id, "Banned login", %{
          error: "Smurf"
        })

        {:error, @smurf_string}

      token.expires != nil and Timex.compare(token.expires, Timex.now()) == -1 ->
        {:error, "Token expired"}

      not is_bot?(user) and login_flood_check(user.id) == :block ->
        {:error, "Flood protection - Please wait 20 seconds and try again"}

      Enum.member?(["", "0", nil], application_hash) == true ->
        {:error, "Application hash missing in login"}

      is_restricted?(user, ["Permanently banned"]) ->
        Telemetry.log_complex_server_event(user.id, "Banned login", %{
          error: "Permanently banned"
        })

        {:error, "Banned account"}

      is_restricted?(user, ["Login"]) ->
        Telemetry.log_complex_server_event(user.id, "Banned login", %{
          error: "Suspended"
        })

        {:error, @suspended_string}

      not is_verified?(user) ->
        Account.update_user_stat(user.id, %{
          application_name: application_name,
          application_version: application_version,
          application_hash: application_hash,
          last_ip: ip
        })

        {:error, "Unverified", user.id}

      Client.get_client_by_id(user.id) != nil ->
        Client.disconnect(user.id, "Already logged in")

        if is_bot?(user) do
          :timer.sleep(1000)
          do_login(user, ip, application_name, application_hash)
        else
          Teiserver.cache_put(:teiserver_login_count, user.id, 10)
          {:error, "Existing session, please retry in 20 seconds to clear the cache"}
        end

      true ->
        {:ok, user} = do_login(user, ip, application_name, application_hash)

        _client = Client.login(user, :tachyon, ip)

        {:ok, user}
    end
  end

  @spec try_login(String.t(), String.t(), String.t(), String.t()) ::
          {:ok, T.user()} | {:error, String.t()} | {:error, String.t(), T.userid()}
  def try_login(token, ip, lobby, lobby_hash) do
    wait_for_startup()

    case Guardian.resource_from_token(token) do
      {:error, _bad_token} ->
        {:error, "token_login_failed"}

      {:ok, db_user, _claims} ->
        user = get_user_by_id(db_user.id)

        # # If they're a smurf, log them in as the smurf!
        # user =
        #   if user.smurf_of_id != nil do
        #     get_user_by_id(user.smurf_of_id)
        #   else
        #     user
        #   end

        cond do
          user.smurf_of_id != nil ->
            Telemetry.log_complex_server_event(user.id, "Banned login", %{
              error: "Smurf"
            })

            {:error, @smurf_string}

          not is_bot?(user) and login_flood_check(user.id) == :block ->
            {:error, "Flood protection - Please wait 20 seconds and try again"}

          Enum.member?(["", "0", nil], lobby_hash) == true and not is_bot?(user) ->
            {:error, "LobbyHash/UserID missing in login"}

          is_restricted?(user, ["Permanently banned"]) ->
            Telemetry.log_complex_server_event(user.id, "Banned login", %{
              error: "Permanently banned"
            })

            {:error, "Banned account"}

          is_restricted?(user, ["Login"]) ->
            Telemetry.log_complex_server_event(user.id, "Banned login", %{
              error: "Suspended"
            })

            {:error, @suspended_string}

          not is_verified?(user) ->
            Account.update_user_stat(user.id, %{
              lobby_client: lobby,
              lobby_hash: lobby_hash,
              last_ip: ip
            })

            {:error, "Unverified", user.id}

          Client.get_client_by_id(user.id) != nil ->
            Client.disconnect(user.id, "Already logged in")

            if is_bot?(user) do
              :timer.sleep(1000)
              do_login(user, ip, lobby, lobby_hash)
            else
              Teiserver.cache_put(:teiserver_login_count, user.id, 10)
              {:error, "Existing session, please retry in 20 seconds to clear the cache"}
            end

          true ->
            # Okay, we're good, what's capacity looking like?
            cond do
              is_bot?(user) ->
                do_login(user, ip, lobby, lobby_hash)

              Config.get_site_config_cache("system.Use login throttle") ->
                if LoginThrottleServer.attempt_login(self(), user.id) do
                  do_login(user, ip, lobby, lobby_hash)
                else
                  {:error, "Queued", user.id, lobby, lobby_hash}
                end

              not has_any_role?(user, ["VIP", "Contributor"]) and server_capacity() <= 0 ->
                {:error, "The server is currently full, please try again in a minute or two."}

              true ->
                do_login(user, ip, lobby, lobby_hash)
            end
        end
    end
  end

  @spec try_md5_login(String.t(), String.t(), String.t(), String.t(), String.t()) ::
          {:ok, T.user()} | {:error, String.t()} | {:error, String.t(), Integer.t()}
  def try_md5_login(username, md5_password, ip, lobby, lobby_hash) do
    wait_for_startup()

    case get_user_by_name(username) do
      nil ->
        {:error, "No user found for '#{username}'"}

      user ->
        # # If they're a smurf, log them in as the smurf!
        # {user, username} =
        #   if user.smurf_of_id != nil do
        #     origin_user = get_user_by_id(user.smurf_of_id)

        #     {origin_user, origin_user.name}
        #   else
        #     {user, user.name}
        #   end

        cond do
          user.smurf_of_id != nil ->
            Telemetry.log_complex_server_event(user.id, "Banned login", %{
              error: "Smurf"
            })

            {:error, @smurf_string}

          user.name != username ->
            {:error, "Username is case sensitive, try '#{user.name}'"}

          not is_bot?(user) and login_flood_check(user.id) == :block ->
            {:error, "Flood protection - Please wait 20 seconds and try again"}

          Enum.member?(["", "0", nil], lobby_hash) == true and not is_bot?(user) ->
            {:error, "LobbyHash/UserID missing in login"}

          test_password(md5_password, user.password_hash) == false ->
            if String.contains?(username, "@") do
              {:error,
               "Invalid password for username, check you are not using your email address as the name"}
            else
              {:error, "Invalid password"}
            end

          is_restricted?(user, ["Permanently banned"]) ->
            Telemetry.log_complex_server_event(user.id, "Banned login", %{
              error: "Permanently banned"
            })

            {:error, "Banned account"}

          is_restricted?(user, ["Login"]) ->
            Telemetry.log_complex_server_event(user.id, "Banned login", %{
              error: "Suspended"
            })

            {:error, @suspended_string}

          not is_verified?(user) ->
            # Log them in to save some details we'd not otherwise get
            do_login(user, ip, lobby, lobby_hash)

            Account.update_user_stat(user.id, %{
              lobby_client: lobby,
              lobby_hash: lobby_hash,
              last_ip: ip
            })

            {:error, "Unverified", user.id}

          Client.get_client_by_id(user.id) != nil ->
            Client.disconnect(user.id, "Already logged in")

            if is_bot?(user) do
              :timer.sleep(1000)
              do_login(user, ip, lobby, lobby_hash)
            else
              Teiserver.cache_put(:teiserver_login_count, user.id, 10)
              {:error, "Existing session, please retry in 20 seconds to clear the cache"}
            end

          true ->
            # Okay, we're good, what's capacity looking like?
            cond do
              is_bot?(user) ->
                do_login(user, ip, lobby, lobby_hash)

              Config.get_site_config_cache("system.Use login throttle") ->
                if LoginThrottleServer.attempt_login(self(), user.id) do
                  do_login(user, ip, lobby, lobby_hash)
                else
                  {:error, "Queued", user.id, lobby, lobby_hash}
                end

              not has_any_role?(user, ["VIP", "Contributor"]) and server_capacity() <= 0 ->
                {:error, "The server is currently full, please try again in a minute or two."}

              true ->
                do_login(user, ip, lobby, lobby_hash)
            end
        end
    end
  end

  @spec do_login(T.user(), String.t(), String.t(), String.t()) :: {:ok, T.user()}
  def do_login(user, ip, lobby_client, lobby_hash) do
    stats = Account.get_user_stat_data(user.id)
    ip = Map.get(stats, "ip_override", ip)

    # If they don't want a flag shown, don't show it, otherwise check for an override before trying geoip
    country = get_country(user, ip)

    # Rank
    rank =
      cond do
        stats["rank_override"] != nil ->
          stats["rank_override"] |> int_parse

        true ->
          calculate_rank(user.id)
      end

    # We don't care about the lobby version so much as we do about the lobby itself
    lobby_client =
      case Regex.run(~r/^[a-zA-Z\ ]+/, lobby_client) do
        [match | _] ->
          match

        _ ->
          lobby_client
      end

    user = %{
      user
      | last_login: round(System.system_time(:second) / 60),
        last_login_timex: Timex.now(),
        last_login_mins: round(System.system_time(:second) / 60),
        country: country,
        rank: rank,
        lobby_client: lobby_client,
        lobby_hash: lobby_hash
    }

    update_user(user, persist: true)

    # User stats
    Account.update_user_stat(user.id, %{
      bot: is_bot?(user),
      country: country,
      rank: rank,
      lobby_client: lobby_client,
      lobby_hash: lobby_hash,
      last_ip: ip
    })

    Telemetry.log_simple_server_event(user.id, "account.user_login")

    if not is_bot?(user) do
      Account.create_smurf_key(user.id, "client_app_hash", lobby_hash)
    end

    {:ok, user}
  end

  @spec get_country(T.user(), String.t()) :: String.t()
  def get_country(user, ip) do
    stats = Account.get_user_stat_data(user.id)

    raw_country =
      cond do
        Config.get_user_config_cache(user.id, "teiserver.Show flag") == false ->
          "??"

        allow?(user, "BAR+") and Map.has_key?(stats, "bar_plus.flag") ->
          stats["bar_plus.flag"]

        stats["country_override"] != nil ->
          stats["country_override"]

        true ->
          # Only call to geoip if the IP has changed
          last_ip = Account.get_user_stat_data(user.id) |> Map.get("last_ip")

          if last_ip != ip or (user.country || "??") == "??" do
            Teiserver.Geoip.get_flag(ip, user.country)
          else
            user.country || "??"
          end
      end

    c =
      raw_country
      |> String.trim()
      |> String.upcase()

    # Handler incase they somehow have an empty country after this
    case c do
      "" -> "??"
      c -> c
    end
  end

  @spec restrict_user(T.userid() | T.user(), String.t()) :: any
  def restrict_user(userid, restriction) when is_integer(userid),
    do: restrict_user(get_user_by_id(userid), restriction)

  def restrict_user(user, restrictions) when is_list(restrictions) do
    new_restrictions = Enum.uniq(restrictions ++ user.restrictions)
    update_user(%{user | restrictions: new_restrictions}, persist: true)
  end

  def restrict_user(user, restriction) do
    new_restrictions = Enum.uniq([restriction | user.restrictions])
    update_user(%{user | restrictions: new_restrictions}, persist: true)
  end

  @spec is_restricted?(T.userid() | T.user(), String.t()) :: boolean()
  def is_restricted?(nil, _), do: true

  def is_restricted?(userid, restriction) when is_integer(userid),
    do: is_restricted?(get_user_by_id(userid), restriction)

  def is_restricted?(user_restrictions, restriction) when is_list(user_restrictions),
    do: is_restricted?(%{restrictions: user_restrictions}, restriction)

  def is_restricted?(%{restrictions: restrictions}, restriction_list)
      when is_list(restriction_list) do
    restriction_list
    |> Enum.map(fn r -> Enum.member?(restrictions, r) end)
    |> Enum.any?()
  end

  def is_restricted?(%{restrictions: restrictions}, the_restriction) do
    Enum.member?(restrictions, the_restriction)
  end

  @spec has_mute?(T.userid() | T.user()) :: boolean()
  def has_mute?(user) do
    is_restricted?(user, [
      "All chat",
      "Room chat",
      "Direct chat",
      "Lobby chat",
      "Battle chat"
    ])
  end

  @spec has_warning?(T.userid() | T.user()) :: boolean()
  def has_warning?(user) do
    is_restricted?(user, [
      "Warning reminder"
    ])
  end

  @spec is_shadowbanned?(T.userid() | T.user()) :: boolean()
  def is_shadowbanned?(nil), do: true

  def is_shadowbanned?(userid) when is_integer(userid),
    do: is_shadowbanned?(get_user_by_id(userid))

  def is_shadowbanned?(%{shadowbanned: true}), do: true
  def is_shadowbanned?(_), do: false

  @spec shadowban_user(T.userid()) :: :ok
  def shadowban_user(nil), do: :ok

  def shadowban_user(userid) when is_integer(userid) do
    Account.update_cache_user(userid, %{shadowbanned: true})
    Client.shadowban_client(userid)
    :ok
  end

  @spec is_bot?(T.userid() | T.user()) :: boolean()
  def is_bot?(nil), do: true
  def is_bot?(userid) when is_integer(userid), do: is_bot?(get_user_by_id(userid))
  def is_bot?(%{roles: roles}), do: Enum.member?(roles, "Bot")
  def is_bot?(_), do: false

  @spec is_moderator?(T.userid() | T.user()) :: boolean()
  def is_moderator?(nil), do: true
  def is_moderator?(userid) when is_integer(userid), do: is_moderator?(get_user_by_id(userid))
  def is_moderator?(%{roles: roles}), do: Enum.member?(roles, "Moderator")
  def is_moderator?(_), do: false

  @spec is_verified?(T.userid() | T.user()) :: boolean()
  def is_verified?(nil), do: true
  def is_verified?(userid) when is_integer(userid), do: is_verified?(get_user_by_id(userid))
  def is_verified?(%{roles: roles}), do: Enum.member?(roles, "Verified")
  def is_verified?(_), do: false

  @spec rank_time(T.userid()) :: non_neg_integer()
  def rank_time(userid) do
    stats = Account.get_user_stat(userid) || %{data: %{}}

    ingame_minutes =
      (stats.data["player_minutes"] || 0) + (stats.data["spectator_minutes"] || 0) * 0.5

    round(ingame_minutes / 60)
  end

  # Based on actual ingame time
  @spec calculate_rank(T.userid(), String.t()) :: non_neg_integer()
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

    cond do
      has_any_role?(userid, ~w(Core Contributor)) -> 6
      ingame_hours > 1000 -> 5
      ingame_hours > 250 -> 4
      ingame_hours > 100 -> 3
      ingame_hours > 15 -> 2
      ingame_hours > 5 -> 1
      true -> 0
    end
  end

  @spec calculate_rank(T.userid()) :: non_neg_integer()
  def calculate_rank(userid) do
    method = Config.get_site_config_cache("profile.Rank method")
    calculate_rank(userid, method)
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

  @spec allow?(T.userid() | T.user() | nil, String.t() | atom | [String.t()]) :: boolean()
  def allow?(nil, _), do: false

  def allow?(userid, required) when is_integer(userid),
    do: allow?(get_user_by_id(userid), required)

  def allow?(user, required) do
    case required do
      :moderator ->
        is_moderator?(user)

      :bot ->
        is_moderator?(user) or is_bot?(user)

      required ->
        Enum.member?(user.permissions, required)
    end
  end

  @doc """
  If a user possesses any of these roles it returns true
  """
  @spec has_any_role?(T.userid() | T.user() | nil, String.t() | [String.t()]) :: boolean()
  def has_any_role?(nil, _), do: false

  def has_any_role?(userid, roles) when is_integer(userid),
    do: has_any_role?(get_user_by_id(userid), roles)

  def has_any_role?(user, roles) when is_list(roles) do
    roles
    |> Enum.map(fn role -> Enum.member?(user.roles, role) end)
    |> Enum.any?()
  end

  def has_any_role?(user, role), do: has_any_role?(user, [role])

  @doc """
  If a user possesses all of these roles it returns true, if any are lacking it returns false
  """
  @spec has_all_roles?(T.userid() | T.user() | nil, String.t() | [String.t()]) :: boolean()
  def has_all_roles?(nil, _), do: false

  def has_all_roles?(userid, roles) when is_integer(userid),
    do: has_all_roles?(get_user_by_id(userid), roles)

  def has_all_roles?(user, roles) when is_list(roles) do
    roles
    |> Enum.map(fn role -> Enum.member?(user.roles, role) end)
    |> Enum.all?()
  end

  def has_all_roles?(user, role), do: has_all_roles?(user, [role])

  @spec valid_email?(String.t()) :: boolean
  def valid_email?(email) do
    cond do
      Application.get_env(:teiserver, Teiserver)[:accept_all_emails] -> true
      not String.contains?(email, "@") -> false
      not String.contains?(email, ".") -> false
      true -> true
    end
  end

  @spec valid_password?(String.t()) :: boolean
  def valid_password?(password) do
    cond do
      # Add additional password requirmenets here
      String.length(password) > 0 -> true
      true -> false
    end
  end
end
