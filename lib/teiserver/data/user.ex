defmodule Teiserver.User do
  @moduledoc """
  Users here are a combination of Central.Account.User and the data within. They are merged like this into a map as their expected use case is very different.
  """
  alias Central.Config
  alias Teiserver.{Account, Client, Coordinator, Telemetry}
  alias Teiserver.EmailHelper
  alias Teiserver.Battle.LobbyChat
  alias Teiserver.Account.{UserCache, RelationsLib}
  alias Teiserver.Chat.WordLib
  alias Teiserver.SpringIdServer
  alias Argon2
  alias Central.Account.Guardian
  alias Teiserver.Data.Types, as: T
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  require Logger
  alias Phoenix.PubSub

  @timer_sleep 500

  @default_colour "#666666"
  @default_icon "fa-solid fa-user"

  @spec role_list :: [String.t()]
  def role_list(),
    do: ~w(Tester Streamer Donor Caster Contributor GDT Dev Moderator Admin Verified Bot)

  @spec keys() :: [atom]
  def keys(),
    do: [
      :id,
      :name,
      :email,
      :inserted_at,
      :clan_id,
      :permissions,
      :colour,
      :icon,
      :behaviour_score,
      :trust_score
    ]

  @data_keys [
    :rank,
    :country,
    :moderator,
    :bot,
    :friends,
    :friend_requests,
    :ignored,
    :avoided,
    :password_hash,
    :verified,
    :email_change_code,
    :last_login,
    :restrictions,
    :restricted_until,
    :shadowbanned,
    :springid,
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
    :steam_id
  ]
  def data_keys(), do: @data_keys

  @default_data %{
    rank: 0,
    country: "??",
    moderator: false,
    bot: false,
    friends: [],
    friend_requests: [],
    ignored: [],
    avoided: [],
    password_hash: nil,
    verified: false,
    email_change_code: nil,
    last_login: nil,
    restrictions: [],
    restricted_until: nil,
    shadowbanned: false,
    springid: nil,
    lobby_hash: [],
    hw_hash: nil,
    chobby_hash: nil,
    roles: [],
    print_client_messages: false,
    print_server_messages: false,
    spring_password: true,
    discord_id: nil,
    discord_dm_channel: nil,
    steam_id: nil
  }

  def default_data(), do: @default_data

  # Time played ranks
  # @rank_levels [
  #   5,
  #   15,
  #   30,
  #   100,
  #   300,
  #   1000,
  #   3000
  # ]

  # Leaderboard rating ranks
  @rank_levels [3, 7, 12, 21, 26, 35, 1000]

  def get_rank_levels(), do: @rank_levels

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
      admin_group_id: Teiserver.user_group_id(),
      permissions: ["teiserver", "teiserver.player", "teiserver.player.account"],
      springid: SpringIdServer.get_next_id(),
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
      admin_group_id: Teiserver.user_group_id(),
      permissions: ["teiserver", "teiserver.player", "teiserver.player.account"],
      springid: SpringIdServer.get_next_id(),
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
        Account.create_group_membership(%{
          user_id: user.id,
          group_id: Teiserver.user_group_id()
        })

        Account.update_user_stat(user.id, %{
          "verification_code" => (:rand.uniform(899_999) + 100_000) |> to_string
        })

        # Now add them to the cache
        user
        |> convert_user
        |> Map.put(:springid, SpringIdServer.get_next_id())
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

              {:ok, _} ->
                :ok
                # Logger.error("Email sent, response of #{Kernel.inspect response}")
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
        Account.create_group_membership(%{
          user_id: user.id,
          group_id: Teiserver.user_group_id()
        })

        Account.update_user_stat(user.id, %{
          "country" => Teiserver.Geoip.get_flag(ip),
          "verification_code" => (:rand.uniform(899_999) + 100_000) |> to_string
        })

        # Now add them to the cache
        user
        |> convert_user
        |> Map.put(:springid, SpringIdServer.get_next_id())
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

            {:ok, _} ->
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
      "previous_names" => Enum.uniq([user.name | previous_names])
    })

    # We need to re-get the user to ensure we don't overwrite our banned flag
    user = get_user_by_id(userid)
    decache_user(user.id)

    db_user = Account.get_user!(userid)
    Account.update_user(db_user, %{"name" => new_name})

    :timer.sleep(5000)
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

  def request_password_reset(user) do
    db_user = Account.get_user!(user.id)

    Central.Account.Emails.password_reset(db_user)
    |> Central.Mailer.deliver_now()
  end

  def request_email_change(nil, _), do: nil

  def request_email_change(user, new_email) do
    code = :rand.uniform(899_999) + 100_000
    update_user(%{user | email_change_code: ["#{code}", new_email]})
  end

  @spec change_email(T.user(), String.t()) :: T.user()
  def change_email(user, new_email) do
    decache_user(user.id)
    update_user(%{user | email: new_email, email_change_code: [nil, nil]}, persist: true)
  end

  # Cache functions
  @spec get_username(T.userid()) :: String.t() | nil
  defdelegate get_username(userid), to: UserCache

  @spec get_userid(String.t()) :: integer() | nil
  defdelegate get_userid(username), to: UserCache

  @spec get_user_by_name(String.t()) :: T.user() | nil
  defdelegate get_user_by_name(username), to: UserCache

  @spec get_user_by_email(String.t()) :: T.user() | nil
  defdelegate get_user_by_email(email), to: UserCache

  @spec get_user_by_discord_id(String.t()) :: T.user() | nil
  defdelegate get_user_by_discord_id(discord_id), to: UserCache

  @spec get_userid_by_discord_id(String.t()) :: T.userid() | nil
  defdelegate get_userid_by_discord_id(discord_id), to: UserCache

  @spec get_user_by_token(String.t()) :: T.user() | nil
  defdelegate get_user_by_token(token), to: UserCache

  @spec get_user_by_id(T.userid()) :: T.user() | nil
  defdelegate get_user_by_id(id), to: UserCache

  @spec list_users(list) :: list
  defdelegate list_users(id_list), to: UserCache

  @spec recache_user(Integer.t()) :: :ok
  defdelegate recache_user(id), to: UserCache

  @spec convert_user(T.user()) :: T.user()
  defdelegate convert_user(user), to: UserCache

  @spec add_user(T.user()) :: T.user()
  defdelegate add_user(user), to: UserCache

  @spec update_user(T.user(), boolean) :: T.user()
  defdelegate update_user(user, persist \\ false), to: UserCache

  @spec decache_user(T.userid()) :: :ok | :no_user
  defdelegate decache_user(userid), to: UserCache

  # Friend related
  @spec create_friendship(T.userid(), T.userid()) :: nil
  defdelegate create_friendship(userid1, userid2), to: RelationsLib

  @spec accept_friend_request(T.userid() | nil, T.userid() | nil) :: T.user() | nil
  defdelegate accept_friend_request(requester, accepter), to: RelationsLib

  @spec decline_friend_request(T.userid() | nil, T.userid() | nil) :: T.user() | nil
  defdelegate decline_friend_request(requester, accepter), to: RelationsLib

  @spec create_friend_request(T.userid() | nil, T.userid() | nil) :: T.user() | nil
  defdelegate create_friend_request(requester, accepter), to: RelationsLib

  @spec rescind_friend_request(T.userid() | nil, T.userid() | nil) :: T.user() | nil
  defdelegate rescind_friend_request(rescinder_id, requester_id), to: RelationsLib

  @spec ignore_user(T.userid() | nil, T.userid() | nil) :: T.user() | nil
  defdelegate ignore_user(ignorer_id, ignored_id), to: RelationsLib

  @spec unignore_user(T.userid() | nil, T.userid() | nil) :: T.user() | nil
  defdelegate unignore_user(unignorer_id, unignored_id), to: RelationsLib

  @spec remove_friend(T.userid() | nil, T.userid() | nil) :: T.user() | nil
  defdelegate remove_friend(remover_id, removed_id), to: RelationsLib

  @spec list_combined_friendslist([T.userid()]) :: [T.user()]
  defdelegate list_combined_friendslist(userids), to: RelationsLib

  @spec send_direct_message(T.userid(), T.userid(), String.t()) :: :ok
  def send_direct_message(from_id, to_id, "!start" <> s),
    do: send_direct_message(from_id, to_id, "!cv start" <> s)

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

      PubSub.broadcast(
        Central.PubSub,
        "legacy_user_updates:#{to_id}",
        {:direct_message, sender_id, message_parts}
      )

      PubSub.broadcast(
        Central.PubSub,
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
      host = Application.get_env(:central, CentralWeb.Endpoint)[:url][:host]
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
      Central.PubSub,
      "legacy_user_updates:#{ringee_id}",
      {:action, {:ring, ringer_id}}
    )

    PubSub.broadcast(
      Central.PubSub,
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

  def add_roles(userid, roles) when is_integer(userid),
    do: add_roles(get_user_by_id(userid), roles)

  def add_roles(user, roles) do
    new_roles = Enum.uniq(roles ++ user.roles)
    update_user(%{user | roles: new_roles}, persist: true)
  end

  @spec create_token(Central.Account.User.t()) :: String.t()
  def create_token(user) do
    {:ok, jwt, _} = Guardian.encode_and_sign(user)
    jwt
  end

  @spec wait_for_startup() :: :ok
  defp wait_for_startup() do
    if Central.cache_get(:application_metadata_cache, "teiserver_partial_startup_completed") !=
         true do
      :timer.sleep(@timer_sleep)
      wait_for_startup()
    else
      :ok
    end
  end

  @spec set_flood_level(T.userid(), Integer) :: :ok
  def set_flood_level(userid, value \\ 10) do
    Central.cache_put(:teiserver_login_count, userid, value)
    :ok
  end

  @spec login_flood_check(T.userid()) :: :allow | :block
  def login_flood_check(userid) do
    login_count = Central.cache_get(:teiserver_login_count, userid) || 0

    if login_count > 3 do
      :block
    else
      Central.cache_put(:teiserver_login_count, userid, login_count + 1)
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

  @spec remaining_capacity() :: non_neg_integer()
  defp remaining_capacity() do
    client_count =
      (Central.cache_get(:application_temp_cache, :telemetry_data) || %{})
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
    client_hash = ws_state.params["client_hash"]
    client_name = ws_state.params["client_name"]

    wait_for_startup()

    user = get_user_by_id(token.user.id)

    cond do
      token.expires != nil and Timex.compare(token.expires, Timex.now()) == -1 ->
        {:error, "Token expired"}

      not is_bot?(user) and login_flood_check(user.id) == :block ->
        {:error, "Flood protection - Please wait 20 seconds and try again"}

      Enum.member?(["", "0", nil], client_hash) == true ->
        {:error, "Client hash missing in login"}

      is_restricted?(user, ["Login"]) ->
        {:error, "Banned, please see Discord for details"}

      not is_bot?(user) and not is_moderator?(user) and
        not has_any_role?(user, ["VIP", "Contributor"]) and remaining_capacity() <= 0 ->
        {:error, "The server is currently full, please try again in a minute or two."}

      # not remaining_capacity() <= 100 and user.behaviour_score < 5000 ->
      #   {:error, "The server is currently full, please try later."}

      not is_verified?(user) ->
        Account.update_user_stat(user.id, %{
          client_name: client_name,
          client_hash: client_hash,
          last_ip: ip
        })

        {:error, "Unverified", user.id}

      Client.get_client_by_id(user.id) != nil ->
        Client.disconnect(user.id, "Already logged in")

        if is_bot?(user) do
          :timer.sleep(1000)
          do_login(user, ip, client_name, client_hash)
        else
          Central.cache_put(:teiserver_login_count, user.id, 10)
          {:error, "Existing session, please retry in 20 seconds to clear the cache"}
        end

      true ->
        {:ok, user} = do_login(user, ip, client_name, client_hash)

        _client = Client.login(user, :tachyon, ip)
        Logger.metadata(request_id: "TachyonWSServer##{user.id}")

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

        cond do
          not is_bot?(user) and login_flood_check(user.id) == :block ->
            {:error, "Flood protection - Please wait 20 seconds and try again"}

          Enum.member?(["", "0", nil], lobby_hash) == true and not is_bot?(user) ->
            {:error, "LobbyHash/UserID missing in login"}

          is_restricted?(user, ["Login"]) ->
            {:error, "Banned, please see Discord for details"}

          not is_bot?(user) and not is_moderator?(user) and
            not has_any_role?(user, ["VIP", "Contributor"]) and remaining_capacity() <= 0 ->
            {:error, "The server is currently full, please try again in a minute or two."}

          # not remaining_capacity() <= 100 and user.behaviour_score < 5000 ->
          #   {:error, "The server is currently full, please try later."}

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
              Central.cache_put(:teiserver_login_count, user.id, 10)
              {:error, "Existing session, please retry in 20 seconds to clear the cache"}
            end

          true ->
            do_login(user, ip, lobby, lobby_hash)
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
        cond do
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

          is_restricted?(user, ["Login"]) ->
            {:error, "Banned, please see Discord for details"}

          not is_bot?(user) and not is_moderator?(user) and
            not has_any_role?(user, ["VIP", "Contributor"]) and remaining_capacity() <= 0 ->
            {:error, "The server is currently full, please try again in a minute or two."}

          # not remaining_capacity() <= 100 and user.behaviour_score < 5000 ->
          #   {:error, "The server is currently full, please try later."}

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
              Central.cache_put(:teiserver_login_count, user.id, 10)
              {:error, "Existing session, please retry in 20 seconds to clear the cache"}
            end

          true ->
            do_login(user, ip, lobby, lobby_hash)
        end
    end
  end

  @spec do_login(T.user(), String.t(), String.t(), String.t()) :: {:ok, T.user()}
  defp do_login(user, ip, lobby_client, lobby_hash) do
    stats = Account.get_user_stat_data(user.id)
    ip = Map.get(stats, "ip_override", ip)

    # If they don't want a flag shown, don't show it, otherwise check for an override before trying geoip
    country =
      cond do
        Central.Config.get_user_config_cache(user.id, "teiserver.Show flag") == false ->
          "??"

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

    # Rank
    rank =
      cond do
        stats["rank_override"] != nil ->
          stats["rank_override"] |> int_parse

        true ->
          calculate_rank(user.id)
      end

    # springid = (if Map.get(user, :springid) != nil, do: user.springid, else: SpringIdServer.get_next_id()) |> int_parse

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
        country: country,
        rank: rank,
        springid: user.id,
        lobby_client: lobby_client,
        lobby_hash: lobby_hash
    }

    update_user(user, persist: true)

    # User stats
    Account.update_user_stat(user.id, %{
      bot: user.bot,
      country: country,
      last_login: System.system_time(:second),
      rank: rank,
      lobby_client: lobby_client,
      lobby_hash: lobby_hash,
      last_ip: ip
    })

    Telemetry.log_server_event(user.id, "account.user_login", %{lobby_client: lobby_client})

    # TODO: Replace lobby_hash name with client_app_hash
    if not is_bot?(user) do
      Account.create_smurf_key(user.id, "client_app_hash", lobby_hash)
    end

    {:ok, user}
  end

  @spec new_moderation_action(Teiserver.Moderation.Action.t()) :: :ok
  def new_moderation_action(_action) do
    :ok
  end

  @spec updated_moderation_action(Teiserver.Moderation.Action.t()) :: :ok
  def updated_moderation_action(_action) do
    :ok
  end

  @spec create_report(T.report(), atom) :: :ok
  def create_report(report, reason) do
    if report.response_text != nil do
      update_report(report, reason)
    end

    :ok
  end

  @spec update_report(T.report(), atom) :: :ok
  def update_report(report, _reason) do
    user = get_user_by_id(report.target_id)

    # If the report is being updated we'll need to update their restrictions
    # and that won't take place correctly in some cases
    # by making the expiry now we make it so the next check will mark them as clear
    expires_as_string =
      Timex.now()
      |> Jason.encode!()
      |> Jason.decode!()

    # Get the new restrictions
    new_restrictions =
      (user.restrictions ++ Map.get(report.action_data || %{}, "restriction_list", []))
      |> Enum.uniq()

    changes = %{
      restrictions: new_restrictions,
      restricted_until: expires_as_string
    }

    # Save changes
    Map.merge(user, changes)
    |> update_user(persist: true)

    # We recache because the json conversion process converts the date
    # from a date to a string of the date
    recache_user(user.id)

    # Sleep to enable the ETS cache to update and they don't insta-login
    :timer.sleep(50)

    # Re-get the user, do we need to affect their currently-connected client?
    user = get_user_by_id(user.id)
    client = Client.get_client_by_id(user.id)

    if client do
      if is_restricted?(user, ["Login"]) do
        # If they're in a battle we need to deal with that before disconnecting them
        Logger.info("Kicking #{client.name} from battle as now banned")
        Coordinator.send_to_host(client.lobby_id, "!gkick #{client.name}")

        LobbyChat.say(
          Coordinator.get_coordinator_userid(),
          "#{client.name} kicked due to moderator action. See discord #moderation-bot for details",
          client.lobby_id
        )

        Logger.info("Disconnecting #{user.name} from server as now banned")
        Client.disconnect(user.id, "Banned")
      else
        # Kick?
        if is_restricted?(user, ["All lobbies"]) do
          Logger.info("Kicking #{client.name} from battle due to moderation action")
          Coordinator.send_to_host(client.lobby_id, "!gkick #{client.name}")

          LobbyChat.say(
            Coordinator.get_coordinator_userid(),
            "#{client.name} kicked due to moderator action. See discord #moderation-bot for details",
            client.lobby_id
          )
        end

        # Mute?
        if is_restricted?(user, ["All chat", "Battle chat"]) do
          Coordinator.send_to_host(client.lobby_id, "!mute #{client.name}")

          LobbyChat.say(
            Coordinator.get_coordinator_userid(),
            "#{client.name} muted due to moderator action. See discord #moderation-bot for details",
            client.lobby_id
          )
        end
      end
    end

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_user_updates:#{user.id}",
      %{
        channel: "teiserver_user_updates:#{user.id}",
        event: :update_report,
        user_id: user.id,
        report_id: report.id
      }
    )

    :ok
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
  # TODO: Remove this once the transition is complete
  def is_bot?(%{bot: true}), do: true
  def is_bot?(%{roles: roles}), do: Enum.member?(roles, "Bot")
  def is_bot?(_), do: false

  @spec is_moderator?(T.userid() | T.user()) :: boolean()
  def is_moderator?(nil), do: true
  def is_moderator?(userid) when is_integer(userid), do: is_moderator?(get_user_by_id(userid))
  # TODO: Remove this once the transition is complete
  def is_moderator?(%{moderator: true}), do: true
  def is_moderator?(%{roles: roles}), do: Enum.member?(roles, "Moderator")
  def is_moderator?(_), do: false

  @spec is_verified?(T.userid() | T.user()) :: boolean()
  def is_verified?(nil), do: true
  def is_verified?(userid) when is_integer(userid), do: is_verified?(get_user_by_id(userid))
  # TODO: Remove this once the transition is complete
  def is_verified?(%{verified: true}), do: true
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
  @spec calculate_rank(T.userid()) :: non_neg_integer()
  # Old method using ingame hours
  # def calculate_rank(userid) do
  #   ingame_hours = rank_time(userid)

  #   @rank_levels
  #     |> Enum.filter(fn r -> r <= ingame_hours end)
  #     |> Enum.count()
  # end

  # New method using leaderboard rating
  def calculate_rank(userid) do
    rating = Account.get_player_highest_leaderboard_rating(userid)

    @rank_levels
    |> Enum.filter(fn r -> r <= rating end)
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
        Enum.member?(user.roles, required)
    end
  end

  @doc """
  If a user possesses any of these roles it returns true
  """
  @spec has_any_role?(T.userid() | T.user() | nil, String.t()[String.t()]) :: boolean()
  def has_any_role?(nil, _), do: false

  def has_any_role?(userid, roles) when is_integer(userid),
    do: has_any_role?(get_user_by_id(userid), roles)

  def has_any_role?(user, roles) do
    roles
    |> Enum.map(fn role -> Enum.member?(user.roles, role) end)
    |> Enum.any?()
  end

  @doc """
  If a user possesses all of these roles it returns true, if any are lacking it returns false
  """
  @spec has_all_roles?(T.userid() | T.user() | nil, String.t()[String.t()]) :: boolean()
  def has_all_roles?(nil, _), do: false

  def has_all_roles?(userid, roles) when is_integer(userid),
    do: has_all_roles?(get_user_by_id(userid), roles)

  def has_all_roles?(user, roles) do
    roles
    |> Enum.map(fn role -> Enum.member?(user.roles, role) end)
    |> Enum.all?()
  end

  @spec valid_email?(String.t()) :: boolean
  def valid_email?(email) do
    cond do
      Application.get_env(:central, Teiserver)[:accept_all_emails] -> true
      not String.contains?(email, "@") -> false
      not String.contains?(email, ".") -> false
      true -> true
    end
  end
end
