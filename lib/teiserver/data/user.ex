defmodule Teiserver.User do
  @moduledoc """
  Users here are a combination of Central.Account.User and the data within. They are merged like this into a map as their expected use case is very different.
  """
  alias Teiserver.{Client, Coordinator}
  alias Teiserver.EmailHelper
  alias Teiserver.{Account, User}
  alias Teiserver.Battle.LobbyChat
  alias Teiserver.Account.{UserCache, RelationsLib}
  alias Teiserver.Chat.WordLib
  alias Teiserver.SpringIdServer
  alias Argon2
  alias Central.Account.Guardian
  alias Teiserver.Data.Types, as: T
  import Central.Logging.Helpers, only: [add_audit_log: 4]

  require Logger
  alias Phoenix.PubSub

  @timer_sleep 500
  @max_username_length 20

  @default_colour "#666666"
  @default_icon "fa-solid fa-user"

  @spec role_list :: [String.t()]
  def role_list(), do: ~w(Tester Streamer Donor Caster Contributor Dev Moderator Admin Verified Bot)

  @spec keys() :: [atom]
  def keys(), do: [:id, :name, :email, :inserted_at, :clan_id, :permissions]

  @data_keys [
    :rank,
    :moderator,
    :bot,
    :friends,
    :friend_requests,
    :ignored,
    :blocked,
    :password_hash,
    :verification_code,
    :verified,
    :email_change_code,
    :last_login,
    :restrictions,
    :restricted_until,
    :shadowbanned,
    :springid,
    :lobby_hash,
    :hw_hash,
    :lobby_client,
    :roles,
    :print_client_messages,
    :print_server_messages,
    :spring_password,
    :discord_id
  ]
  def data_keys(), do: @data_keys

  @default_data %{
    rank: 0,
    moderator: false,
    bot: false,
    friends: [],
    friend_requests: [],
    ignored: [],
    blocked: [],
    password_hash: nil,
    verification_code: nil,
    verified: false,
    email_change_code: nil,
    last_login: nil,
    restrictions: [],
    restricted_until: nil,
    shadowbanned: false,
    springid: nil,
    lobby_hash: [],
    hw_hash: nil,
    roles: [],
    print_client_messages: false,
    print_server_messages: false,
    spring_password: true,
    discord_id: nil
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

  def user_register_params(name, email, password, extra_data \\ %{}) do
    name = clean_name(name)
    verification_code = :rand.uniform(899_999) + 100_000
      |> to_string
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
          "verification_code" => verification_code,
          "verified" => false
        })
        |> Map.merge(extra_data)
    }
  end

  def user_register_params_with_md5(name, email, md5_password, extra_data \\ %{}) do
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
      colour: @default_colour,
      icon: @default_icon,
      admin_group_id: Teiserver.user_group_id(),
      permissions: ["teiserver", "teiserver.player", "teiserver.player.account"],
      springid: SpringIdServer.get_next_id(),
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

  @spec register_user(String.t(), String.t(), String.t()) :: :success | {:error, String.t()}
  def register_user(name, email, password) do
    name = String.trim(name)
    email = String.trim(email)

    cond do
      WordLib.acceptable_name?(name) == false ->
        {:error, "Not an acceptable name, please see section 1.4 of the code of conduct"}

      clean_name(name) |> String.length() > @max_username_length ->
        {:failure, "Max length #{@max_username_length} characters"}

      clean_name(name) != name ->
        {:failure, "Invalid characters in name (only a-z, A-Z, 0-9, [, ] allowed)"}

      get_user_by_name(name) ->
        {:failure, "Username already taken"}

      get_user_by_email(email) ->
        {:failure, "Email already in use"}

      true ->
        case do_register_user(name, email, password) do
          :ok ->
            :success
          :error ->
            {:error, "Server error, please inform admin"}
        end
    end
  end

  @spec register_user_with_md5(String.t(), String.t(), String.t(), String.t()) :: :success | {:error, String.t()}
  def register_user_with_md5(name, email, md5_password, ip) do
    name = String.trim(name)
    email = String.trim(email)

    cond do
      WordLib.acceptable_name?(name) == false ->
        {:error, "Not an acceptable name, please see section 1.4 of the code of conduct"}

      clean_name(name) |> String.length() > @max_username_length ->
        {:error, "Max length #{@max_username_length} characters"}

      clean_name(name) != name ->
        {:error, "Invalid characters in name (only a-z, A-Z, 0-9, [, ] allowed)"}

      get_user_by_name(name) ->
        {:error, "Username already taken"}

      get_user_by_email(email) ->
        {:error, "Email already attached to a user"}

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

    params =
      user_register_params(name, email, password)

    case Account.script_create_user(params) do
      {:ok, user} ->
        Account.create_group_membership(%{
          user_id: user.id,
          group_id: Teiserver.user_group_id()
        })

        # Now add them to the cache
        user
        |> convert_user
        |> Map.put(:springid, SpringIdServer.get_next_id())
        |> Map.put(:password_hash, spring_md5_password(password))
        |> Map.put(:spring_password, false)
        |> add_user

        if not String.ends_with?(user.email, "@agents") do
          case EmailHelper.new_user(user) do
            {:error, error} ->
              Logger.error("Error sending new user email - #{user.email} - #{error}")
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

    params =
      user_register_params_with_md5(name, email, md5_password, %{
      })

    case Account.script_create_user(params) do
      {:ok, user} ->
        Account.create_group_membership(%{
          user_id: user.id,
          group_id: Teiserver.user_group_id()
        })

        Account.update_user_stat(user.id, %{
          "country" => Teiserver.Geoip.get_flag(ip)
        })

        # Now add them to the cache
        user
        |> convert_user
        |> Map.put(:springid, SpringIdServer.get_next_id())
        |> add_user

        if not String.ends_with?(user.email, "@agents") do
          case EmailHelper.new_user(user) do
            {:error, error} ->
              Logger.error("Error sending new user email - #{user.email} - #{Kernel.inspect error}")
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
              "Unable to create bot with params #{Kernel.inspect(params)}\n#{
                Kernel.inspect(changeset)
              } in register_bot(#{bot_name}, #{bot_host_id})"
            )
        end
    end
  end

  @spec rename_user(T.userid(), String.t(), boolean) :: :success | {:error, String.t()}
  def rename_user(userid, new_name, admin_action \\ false) do
    rename_log = Account.get_user_stat_data(userid)
      |> Map.get("rename_log", [])

    new_name = String.trim(new_name)

    now = System.system_time(:second)
    # since_most_recent_rename = now - (Enum.slice(rename_log, 0..0) ++ [0] |> hd)
    since_rename_two = now - (Enum.slice(rename_log, 1..1) ++ [0, 0, 0] |> hd)
    since_rename_three = now - (Enum.slice(rename_log, 2..2) ++ [0, 0, 0] |> hd)

    cond do
      is_restricted?(userid, ["Community", "Renaming"]) ->
        {:error, "Your account is restricted from renaming"}

      admin_action == false and WordLib.acceptable_name?(new_name) == false ->
        {:error, "Not an acceptable name, please see section 1.4 of the code of conduct"}

      # Can't rename more than 2 times in 5 days
      admin_action == false and since_rename_two < 60 * 60 * 24 * 5 ->
        {:error, "If you keep changing your name people won't know who you are; give it a bit of time"}

      # Can't rename more than 3 times in 30 days
      admin_action == false and since_rename_three < 60 * 60 * 24 * 30 ->
        {:error, "If you keep changing your name people won't know who you are; give it a bit of time"}

      admin_action == false and is_restricted?(userid, ["All chat", "Renaming"]) ->
        {:error, "Muted"}

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
    set_flood_level(user.id, 10)
    Client.disconnect(userid, "Rename")

    # Log the current name in their history
    previous_names = Account.get_user_stat_data(userid)
      |> Map.get("previous_names", [])

    rename_log = Account.get_user_stat_data(userid)
      |> Map.get("rename_log", [])

    Account.update_user_stat(userid, %{
      "rename_log" => [System.system_time(:second) | rename_log],
      "previous_names" => [user.name | previous_names]
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

  # @spec get_user_by_discord_id(String.t()) :: T.user() | nil
  # defdelegate get_user_by_discord_id(discord_id), to: UserCache

  # @spec get_userid_by_discord_id(String.t()) :: T.userid() | nil
  # defdelegate get_userid_by_discord_id(discord_id), to: UserCache

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

  @spec delete_user(T.userid()) :: :ok | :no_user
  defdelegate delete_user(userid), to: UserCache

  @spec decache_user(T.userid()) :: :ok | :no_user
  defdelegate decache_user(userid), to: UserCache


  # Friend related
  @spec accept_friend_request(T.userid() | nil, T.userid() | nil) :: T.user() | nil
  defdelegate accept_friend_request(requester, accepter), to: RelationsLib

  @spec decline_friend_request(T.userid() | nil, T.userid() | nil) :: T.user() | nil
  defdelegate decline_friend_request(requester, accepter), to: RelationsLib

  @spec create_friend_request(T.userid() | nil, T.userid() | nil) :: T.user() | nil
  defdelegate create_friend_request(requester, accepter), to: RelationsLib

  @spec ignore_user(T.userid() | nil, T.userid() | nil) :: T.user() | nil
  defdelegate ignore_user(requester, accepter), to: RelationsLib

  @spec unignore_user(T.userid() | nil, T.userid() | nil) :: T.user() | nil
  defdelegate unignore_user(requester, accepter), to: RelationsLib

  @spec remove_friend(T.userid() | nil, T.userid() | nil) :: T.user() | nil
  defdelegate remove_friend(requester, accepter), to: RelationsLib

  @spec list_combined_friendslist([T.userid()]) :: [T.user()]
  defdelegate list_combined_friendslist(userids), to: RelationsLib

  @spec send_direct_message(T.userid(), T.userid(), String.t()) :: :ok
  def send_direct_message(from_id, to_id, "!start" <> s), do: send_direct_message(from_id, to_id, "!cv start" <> s)
  def send_direct_message(from_id, to_id, "!joinas" <> s), do: send_direct_message(from_id, to_id, "!cv joinas" <> s)

  def send_direct_message(from_id, to_id, message_content) do
    sender = get_user_by_id(from_id)
    if not is_restricted?(sender, ["All chat", "Direct chat"]) do
      PubSub.broadcast(
        Central.PubSub,
        "legacy_user_updates:#{to_id}",
        {:direct_message, from_id, message_content}
      )

      PubSub.broadcast(
        Central.PubSub,
        "teiserver_client_messages:#{to_id}",
        {:client_message, :received_direct_message, to_id, {from_id, message_content}}
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

  @spec verify_user(T.user()) :: T.user()
  def verify_user(user) do
    %{user | verification_code: nil, verified: true, roles: ["Verified" | user.roles]}
    |> update_user(persist: true)
  end

  @spec add_roles(T.user() | T.userid(), [String.t()]) :: nil | T.user()
  def add_roles(nil, _), do: nil
  def add_roles(_, []), do: nil
  def add_roles(userid, roles) when is_integer(userid), do: add_roles(get_user_by_id(userid), roles)
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
    if Central.cache_get(:application_metadata_cache, "teiserver_partial_startup_completed") != true do
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

  @spec internal_client_login(T.userid()) :: {:ok, T.user()} | :error
  def internal_client_login(userid) do
    case get_user_by_id(userid) do
      nil -> :error
      user ->
        do_login(user, "127.0.0.1", "Teiserver Internal Client", "IC")
        Client.login(user, self(), "127.0.0.1")
        {:ok, user}
    end
  end

  @spec try_login(String.t(), String.t(), String.t(), String.t()) :: {:ok, T.user()} | {:error, String.t()} | {:error, String.t(), T.userid()}
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

          not is_verified?(user) ->
            Account.update_user_stat(user.id, %{
              lobby_client: lobby,
              lobby_hash: lobby_hash,
              last_ip: ip
            })
            {:error, "Unverified", user.id}

          Client.get_client_by_id(user.id) != nil ->
            Client.disconnect(user.id, "Already logged in")
            if not is_bot?(user) do
              Central.cache_put(:teiserver_login_count, user.id, 10)
              {:error, "Existing session, please retry in 20 seconds to clear the cache"}
            else
              :timer.sleep(1000)
              do_login(user, ip, lobby, lobby_hash)
            end

          true ->
            do_login(user, ip, lobby, lobby_hash)
        end
    end
  end

  @spec try_md5_login(String.t(), String.t(), String.t(), String.t(), String.t()) :: {:ok, T.user()} | {:error, String.t()} | {:error, String.t(), Integer.t()}
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
            {:error, "Invalid password"}

          is_restricted?(user, ["Login"]) ->
            {:error, "Banned, please see Discord for details"}

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
            if not is_bot?(user) do
              Central.cache_put(:teiserver_login_count, user.id, 10)
              {:error, "Existing session, please retry in 20 seconds to clear the cache"}
            else
              :timer.sleep(1000)
              do_login(user, ip, lobby, lobby_hash)
            end

          true ->
            do_login(user, ip, lobby, lobby_hash)
        end
    end
  end

  @spec do_login(T.user(), String.t(), String.t(), String.t()) :: {:ok, T.user()}
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

    rank = calculate_rank(user.id)

    springid = if Map.get(user, :springid) != nil, do: user.springid, else: SpringIdServer.get_next_id()
    |> Central.Helpers.NumberHelper.int_parse

    # We don't care about the lobby version so much as we do about the lobby itself
    lobby_client = case Regex.run(~r/^[a-zA-Z\ ]+/, lobby_client) do
      [match | _] ->
        match
      _ ->
        lobby_client
    end

    user =
      %{
        user
        | last_login: round(System.system_time(:second) / 60),
          rank: rank,
          springid: springid,
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

    {:ok, user}
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
    expires_as_string = Timex.now() |> Jason.encode! |> Jason.decode!

    # Get the new restrictions
    new_restrictions = user.restrictions ++ Map.get(report.action_data || %{}, "restriction_list", [])
      |> Enum.uniq

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
        LobbyChat.say(Coordinator.get_coordinator_userid(), "#{client.name} kicked due to moderator action. See discord #moderation-bot for details", client.lobby_id)

        Logger.info("Disconnecting #{user.name} from server as now banned")
        Client.disconnect(user.id, "Banned")
      else

        # Kick?
        if is_restricted?(user, ["All lobbies"]) do
          Logger.info("Kicking #{client.name} from battle due to moderation action")
          Coordinator.send_to_host(client.lobby_id, "!gkick #{client.name}")
          LobbyChat.say(Coordinator.get_coordinator_userid(), "#{client.name} kicked due to moderator action. See discord #moderation-bot for details", client.lobby_id)
        end

        # Mute?
        if is_restricted?(user, ["All chat", "Battle chat"]) do
          Coordinator.send_to_host(client.lobby_id, "!mute #{client.name}")
          LobbyChat.say(Coordinator.get_coordinator_userid(), "#{client.name} muted due to moderator action. See discord #moderation-bot for details", client.lobby_id)
        end
      end
    end

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_user_updates:#{user.id}",
      {:user_update, :update_report, user.id, report.id}
    )

    :ok
  end

  @spec restrict_user(T.userid() | T.user(), String.t()) :: any
  def restrict_user(userid, restriction) when is_integer(userid), do: restrict_user(get_user_by_id(userid), restriction)
  def restrict_user(user, restrictions) when is_list(restrictions) do
    new_restrictions = Enum.uniq(restrictions ++ user.restrictions)
    update_user(%{user | restrictions: new_restrictions}, persist: true)
  end
  def restrict_user(user, restriction) do
    new_restrictions = Enum.uniq([restriction | user.restrictions])
    update_user(%{user | restrictions: new_restrictions}, persist: true)
  end

  @spec unbridge_user(T.user(), String.t(), non_neg_integer(), String.t()) :: any
  def unbridge_user(user, message, flagged_word_count, location) do
    if not is_restricted?(user, ["Bridging"]) do
      coordinator_user_id = Coordinator.get_coordinator_userid()

      {:ok, _report} = Central.Account.create_report(%{
        "location" => "Automod",
        "location_id" => nil,
        "reason" => "Automod detected flagged words",
        "reporter_id" => coordinator_user_id,
        "target_id" => user.id,
        "response_text" => "Unbridging because said: #{message}",
        "response_action" => "Restrict",
        "responded_at" => Timex.now(),
        "followup" => nil,
        "code_references" => [],
        "expires" => nil,
        "responder_id" => coordinator_user_id,
        "action_data" => %{
          "restriction_list" => ["Bridging"]
        }
      })

      restrict_user(user, "Bridging")

      client = Client.get_client_by_id(user.id) || %{ip: "no client"}
      add_audit_log(user.id, client.ip, "Teiserver:De-bridged user", %{
        message: message,
        flagged_word_count: flagged_word_count,
        location: location
      })
    end
  end

  @spec is_restricted?(T.userid() | T.user(), String.t()) :: boolean()
  def is_restricted?(nil, _), do: true
  def is_restricted?(userid, restriction) when is_integer(userid), do: is_restricted?(get_user_by_id(userid), restriction)
  def is_restricted?(%{restrictions: restrictions}, restriction_list) when is_list(restriction_list) do
    restriction_list
      |> Enum.map(fn r -> Enum.member?(restrictions, r) end)
      |> Enum.any?
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
      "Warning reminder",
    ])
  end

  @spec is_shadowbanned?(T.userid() | T.user()) :: boolean()
  def is_shadowbanned?(nil), do: true
  def is_shadowbanned?(userid) when is_integer(userid), do: is_shadowbanned?(get_user_by_id(userid))
  def is_shadowbanned?(%{shadowbanned: true}), do: true
  def is_shadowbanned?(_), do: false

  @spec shadowban_user(T.userid() | T.user()) :: :ok
  def shadowban_user(nil), do: :ok
  def shadowban_user(userid) when is_integer(userid), do: shadowban_user(get_user_by_id(userid))
  def shadowban_user(user) do
    update_user(%{user | shadowbanned: true, muted: [true, nil]}, persist: true)
    Client.shadowban_client(user.id)
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
      |> Enum.filter(fn r -> r <= ingame_hours end)
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
  def allow?(userid, required) when is_integer(userid), do: allow?(get_user_by_id(userid), required)
  def allow?(user, required) do
    case required do
      :moderator ->
        User.is_moderator?(user)

      :bot ->
        User.is_moderator?(user) or User.is_bot?(user)

      required ->
        Enum.member?(user.roles, required)
    end
  end
end
