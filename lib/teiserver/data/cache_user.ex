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

  @type t :: T.user()

  @timer_sleep 500

  @default_colour "#666666"
  @default_icon "fa-solid fa-user"

  @suspended_string "This account is temporarily suspended. You can see the #moderation-bot on discord for more details; if you need to appeal anything please use the #open-ticket channel on the discord. Be aware, trying to evade moderation by creating new accounts will result in extending the suspension or even a permanent ban."

  @smurf_string "Alt account detected. We do not allow alt accounts. Please login as your main account. Repeatedly creating alts can result in suspension or bans. If you think this account was flagged incorrectly please open a ticket on our discord and explain why."

  # Keys kept from the raw user and merged into the memory user
  @spec keys() :: [atom]
  def keys(),
    do:
      ~w(id name password email inserted_at clan_id permissions colour icon smurf_of_id last_login_timex last_played last_logout roles discord_id)a

  # This is the version of keys with the extra fields we're going to be moving from data to the object itself
  # def keys(),
  #   do: ~w(id name email inserted_at clan_id permissions colour icon smurf_of_id roles restrictions restricted_until shadowbanned last_login last_played last_logout discord_id steam_id)a

  @data_keys [
    :rank,
    :country,
    :bot,
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
    :discord_id,
    :discord_dm_channel,
    :discord_dm_channel_id,
    :steam_id
  ]
  def data_keys(), do: @data_keys

  @spec clean_name(String.t()) :: String.t()
  def clean_name(name) do
    ~r/([^a-zA-Z0-9_\[\]\{\}]|\s)/
    |> Regex.replace(name, "")
  end

  @spec check_symbol_limit(String.t()) :: boolean()
  def check_symbol_limit(name) do
    name
    |> String.replace(~r/[[:alnum:]]/, "")
    |> String.graphemes()
    |> Enum.frequencies()
    |> Enum.filter(fn {_, val} -> val > 2 end)
    |> Enum.count()
    |> Kernel.>(0)
  end

  def user_register_params_with_md5(name, email, md5_password, extra_data \\ %{}) do
    data =
      Teiserver.Account.default_data()
      |> Map.new(fn {k, v} -> {to_string(k), v} end)

    %{
      name: name,
      email: email,
      password: md5_password,
      colour: @default_colour,
      icon: @default_icon,
      roles: ["Verified"],
      permissions: ["Verified"],
      data:
        data
        |> Map.merge(%{
          "verified" => false
        })
        |> Map.merge(extra_data)
    }
  end

  @spec register_user_with_md5(String.t(), String.t(), String.t(), String.t()) ::
          :success | {:error, String.t()}
  def register_user_with_md5(name, email, md5_password, ip) do
    name = String.trim(name)
    email = String.trim(email)

    with :ok <- valid_name?(name, false),
         :ok <- valid_email?(email),
         {:ok, _user} <-
           Account.register_user(
             %{
               "name" => String.trim(name),
               "email" => String.trim(email),
               "password" => md5_password,
               "icon" => @default_icon,
               "colour" => @default_colour,
               # hack so that we can use the same code for web and chobby registration
               # chobby does its own confirmation check
               "password_confirmation" => md5_password
             },
             :md5_password,
             ip
           ) do
      :success
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        case changeset.errors[:email] do
          nil -> {:error, "User creation failed"}
          _ -> {:error, "Email already attached to a user"}
        end

      {:error, reason} when is_binary(reason) ->
        {:error, reason}
    end
  end

  @doc """
  Augment the user objects with various attributes like ip or icon.
  Also handle the verification process.

  This isn't ideal as it swallows errors from verification. Adding data like ip
  after the fact is also backward and should be provided at user creation when
  available instead of patching things up after the fact.
  That however is a bigger refactor than I'm willing to make now
  """
  @spec post_user_creation_actions(user :: term(), String.t() | nil) :: T.user()
  def post_user_creation_actions(user, ip \\ nil) do
    Account.update_user_stat(user.id, %{
      "first_ip" => ip,
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
          Logger.error("Error sending new user email - #{user.email} - #{Kernel.inspect(error)}")

        :no_verify ->
          verify_user(get_user_by_id(user.id))
          :ok

        :ok ->
          :ok
      end
    end

    user
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
          user_register_params_with_md5(bot_name, host.email, host.password, %{
            "bot" => true,
            "verified" => true,
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
    new_name = String.trim(new_name)

    cond do
      is_restricted?(userid, ["Community", "Renaming"]) ->
        {:error, "Your account is restricted from renaming"}

      admin_action == false and renamed_recently(userid) ->
        {:error, "Rename limit reached (2 times in 5 days or 3 times in 30 days)"}

      admin_action == false and is_restricted?(userid, ["All chat", "Renaming"]) ->
        {:error, "Muted"}

      true ->
        case valid_name?(new_name, admin_action) do
          :ok ->
            do_rename_user(userid, new_name)
            :success

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @spec valid_name?(String.t(), boolean()) :: :ok | {:error, reason :: String.t()}
  def valid_name?(name, admin_action) do
    max_username_length = Config.get_site_config_cache("teiserver.Username max length")

    cond do
      admin_action == false and WordLib.reserved_name?(name) == true ->
        {:error, "That name is in restricted for use by the server, please choose another"}

      admin_action == false and WordLib.acceptable_name?(name) == false ->
        {:error, "Not an acceptable name, please see section 1.4 of the code of conduct"}

      clean_name(name) |> String.length() > max_username_length ->
        {:error, "Max length #{max_username_length} characters"}

      clean_name(name) != name ->
        {:error, "Invalid characters in name (only a-z, A-Z, 0-9, [, ] and _ allowed)"}

      check_symbol_limit(name) ->
        {:error, "Too many repeated symbols in name"}

      true ->
        # TODO: create a unique index on lower(name) so that this check is fast
        # (and also redundant)
        users = Teiserver.Account.query_users(search: [name_lower: name], select: [:name])

        case users do
          [] -> :ok
          _ -> {:error, "Username already taken"}
        end
    end
  end

  @spec renamed_recently(T.userid()) :: boolean()
  defp renamed_recently(user_id) do
    rename_log =
      Account.get_user_stat_data(user_id)
      |> Map.get("rename_log", [])

    now = System.system_time(:second)
    since_rename_two = now - ((Enum.slice(rename_log, 1..1) ++ [0, 0, 0]) |> hd)
    since_rename_three = now - ((Enum.slice(rename_log, 2..2) ++ [0, 0, 0]) |> hd)

    cond do
      # VIPs ignore time based rename restrictions
      is_vip?(user_id) -> false
      # Can't rename more than 2 times in 5 days
      since_rename_two < 60 * 60 * 24 * 5 -> true
      # Can't rename more than 3 times in 30 days
      since_rename_three < 60 * 60 * 24 * 30 -> true
      true -> false
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

  @spec update_user(T.user(), [persist: boolean()] | nil) :: T.user()
  defdelegate update_user(user, persist \\ []), to: UserCacheLib

  @spec decache_user(T.userid()) :: :ok | :no_user
  defdelegate decache_user(userid), to: UserCacheLib

  @spec send_direct_message(T.userid(), T.userid(), String.t()) :: :ok
  def send_direct_message(from_id, to_id, "!joinas" <> s),
    do: send_direct_message(from_id, to_id, "!cv joinas" <> s)

  @spec send_direct_message(T.userid(), T.userid(), list) :: :ok
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
    # Replace SPADS command (starting with !) with lowercase version to prevent bypassing with capitalised command names
    # Ignore !# bot commands like !#JSONRPC
    message =
      if String.starts_with?(message, "!") and !String.starts_with?(message, "!#") do
        message
        |> String.trim()
        |> String.downcase()
        |> case do
          ["!cv", "joinas" | _] ->
            "!cv joinas spec"

          ["!callvote", "joinas" | _] ->
            "!callvote joinas spec"

          ["!joinas" | _] ->
            "!joinas spec"

          ["!clan"] ->
            clan_command(from_id)
            "!clan"

          _ ->
            message
        end
      else
        message
      end

    send_direct_message(from_id, to_id, [message])
  end

  defp clan_command(from_id) do
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

    if login_count >= rate_limit do
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

          true ->
            if Client.get_client_by_id(user.id) != nil do
              Client.disconnect(user.id, "Already logged in")
              :timer.sleep(1000)
            end

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
          {:ok, T.user()} | {:error, String.t()} | {:error, String.t(), integer()}
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

          Account.verify_md5_password(md5_password, user.password) == false ->
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

          true ->
            if Client.get_client_by_id(user.id) != nil do
              Client.disconnect(user.id, "Already logged in")
              :timer.sleep(1000)
            end

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

  @spec tachyon_login(T.user(), String.t(), String.t()) ::
          {:ok, T.user()} | {:error, String.t()} | {:error, :rate_limited, String.t()}
  def tachyon_login(user, ip, lobby_client) do
    lobby_hash = "tachyon_lobby_hash(maybe_useless)"

    user = convert_user(user)

    cond do
      user.smurf_of_id != nil ->
        Telemetry.log_complex_server_event(user.id, "Banned login", %{
          error: "Smurf"
        })

        {:error, @smurf_string}

      login_flood_check(user.id) == :block ->
        {:error, :rate_limited, "Flood protection - Please wait 20 seconds and try again"}

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
        do_login(user, ip, lobby_client, lobby_hash)

        Account.update_user_stat(user.id, %{
          lobby_client: lobby_client,
          lobby_hash: lobby_hash,
          last_ip: ip
        })

        {:error, "Account is not verified"}

      true ->
        # TODO: copy/paste the capacity restriction and queuing from try_md5_login later
        do_login(user, ip, lobby_client, lobby_hash)
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

  @spec is_restricted?(T.userid() | T.user() | nil, String.t() | [String.t()]) :: boolean()
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
  def is_bot?(nil), do: false
  def is_bot?(userid) when is_integer(userid), do: is_bot?(get_user_by_id(userid))
  def is_bot?(%{roles: roles}), do: Enum.member?(roles, "Bot")
  def is_bot?(_), do: false

  @spec is_moderator?(T.userid() | T.user()) :: boolean()
  def is_moderator?(nil), do: false
  def is_moderator?(userid) when is_integer(userid), do: is_moderator?(get_user_by_id(userid))
  def is_moderator?(%{roles: roles}), do: Enum.member?(roles, "Moderator")
  def is_moderator?(_), do: false

  @spec is_contributor?(T.userid() | T.user()) :: boolean()
  def is_contributor?(nil), do: false
  def is_contributor?(userid) when is_integer(userid), do: is_contributor?(get_user_by_id(userid))
  def is_contributor?(%{roles: roles}), do: Enum.member?(roles, "Contributor")
  def is_contributor?(_), do: false

  @spec is_verified?(T.userid() | T.user()) :: boolean()
  def is_verified?(nil), do: false
  def is_verified?(userid) when is_integer(userid), do: is_verified?(get_user_by_id(userid))
  def is_verified?(%{roles: roles}), do: Enum.member?(roles, "Verified")
  def is_verified?(_), do: false

  @spec is_admin?(T.userid() | T.user()) :: boolean()
  def is_admin?(nil), do: false
  def is_admin?(userid) when is_integer(userid), do: is_admin?(get_user_by_id(userid))
  def is_admin?(%{roles: roles}), do: Enum.member?(roles, "Admin")
  def is_admin?(_), do: false

  @spec is_vip?(T.userid() | T.user()) :: boolean()
  def is_vip?(nil), do: false
  def is_vip?(userid) when is_integer(userid), do: is_vip?(get_user_by_id(userid))
  def is_vip?(%{roles: roles}), do: Enum.member?(roles, "VIP")
  def is_vip?(_), do: false

  @spec rank_time(T.userid()) :: non_neg_integer()
  def rank_time(userid) do
    stats = Account.get_user_stat(userid) || %{data: %{}}

    ingame_minutes =
      (stats.data["player_minutes"] || 0) + (stats.data["spectator_minutes"] || 0) * 0.5

    # Hours are rounded down which helps to determine if a user has hit a
    # chevron hours threshold. So a user with 4.9 hours is still chevron 1 or rank 0
    trunc(ingame_minutes / 60)
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

    # Thresholds should match what is on the website:
    # https://www.beyondallreason.info/guide/rating-and-lobby-balance#rank-icons
    cond do
      has_any_role?(userid, ["Tournament winner"]) -> 7
      has_any_role?(userid, ~w(Core Contributor)) and !Account.hide_contributor_rank?(userid) -> 6
      ingame_hours >= 1000 -> 5
      ingame_hours >= 250 -> 4
      ingame_hours >= 100 -> 3
      ingame_hours >= 15 -> 2
      ingame_hours >= 5 -> 1
      true -> 0
    end
  end

  @spec calculate_rank(T.userid()) :: non_neg_integer()
  def calculate_rank(userid) do
    method = Config.get_site_config_cache("profile.Rank method")
    calculate_rank(userid, method)
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

  @spec valid_email?(String.t()) :: :ok | {:error, reason :: String.t()}
  def valid_email?(email) do
    cond do
      Application.get_env(:teiserver, Teiserver)[:accept_all_emails] -> :ok
      not String.contains?(email, "@") -> {:error, "invalid email"}
      not String.contains?(email, ".") -> {:error, "invalid email"}
      true -> :ok
    end
  end
end
