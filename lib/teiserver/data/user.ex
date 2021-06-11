defmodule Teiserver.User do
  @moduledoc """
  Users here are a combination of Central.Account.User and the data within. They are merged like this into a map as their expected use case is very different.
  """
  alias Central.Communication
  alias Teiserver.Client
  alias Teiserver.EmailHelper
  alias Teiserver.Account
  alias Central.Helpers.StylingHelper
  alias Argon2
  alias Central.Account.Guardian
  alias Teiserver.Data.Types

  @wordlist ~w(abacus rhombus square shape oblong rotund bag dice flatulence cats dogs mice eagle oranges apples pears neon lights electricity calculator harddrive cpu memory graphics monitor screen television radio microwave sulphur tree tangerine melon watermelon obstreperous chlorine argon mercury jupiter saturn neptune ceres firefly slug sloth madness happiness ferrous oblique advantageous inefficient starling clouds rivers sunglasses)

  @timer_sleep 500

  @keys [:id, :name, :email, :inserted_at, :clan_id]
  @data_keys [
    :rank,
    :country,
    :country_override,
    :lobbyid,
    :ip,
    :moderator,
    :bot,
    :friends,
    :friend_requests,
    :ignored,
    :verification_code,
    :verified,
    :password_reset_code,
    :email_change_code,
    :password_hash,
    :ingame_minutes,
    :mmr,
    :banned,
    :muted,
    :rename_in_progress,
    :springid
  ]

  @default_data %{
    rank: 1,
    country: "??",
    country_override: nil,
    lobbyid: "LuaLobby Chobby",
    ip: "default_ip",
    moderator: false,
    bot: false,
    friends: [],
    friend_requests: [],
    ignored: [],
    password_hash: nil,
    verification_code: nil,
    verified: false,
    password_reset_code: nil,
    email_change_code: nil,
    last_login: nil,
    ingame_minutes: 0,
    mmr: %{},
    banned: [false, nil],
    muted: [false, nil],
    rename_in_progress: false,
    springid: nil
  }

  @rank_levels [
    5,
    15,
    30,
    100,
    300,
    1000,
    3000
  ]

  require Logger
  alias Phoenix.PubSub
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  alias Teiserver.EmailHelper
  alias Teiserver.Account

  def next_springid() do
    ConCache.isolated(:id_counters, :springid, fn ->
      new_value = ConCache.get(:id_counters, :springid) + 1
      ConCache.put(:id_counters, :springid, new_value)
      new_value
    end)
  end

  @spec generate_random_password :: String.t()
  def generate_random_password() do
    @wordlist
    |> Enum.take_random(3)
    |> Enum.join(" ")
  end

  @spec clean_name(String.t()) :: String.t()
  def clean_name(name) do
    ~r/([^a-zA-Z0-9_\[\]\{\}]|\s)/
    |> Regex.replace(name, "")
  end

  def encrypt_password(password) do
    Argon2.hash_pwd_salt(password)
  end

  def spring_md5_password(password) do
    :crypto.hash(:md5, password) |> Base.encode64()
  end

  def user_register_params(name, email, md5_password, extra_data \\ %{}) do
    name = clean_name(name)
    verification_code = :random.uniform(899_999) + 100_000
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
        :success
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

        EmailHelper.new_user(user)
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
            "password_hash" => host.password_hash
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

  def get_username(userid) do
    ConCache.get(:users_lookup_name_with_id, int_parse(userid))
  end

  def get_userid(username) do
    ConCache.get(:users_lookup_id_with_name, username)
  end

  def get_user_by_name(username) do
    id = ConCache.get(:users_lookup_id_with_name, username)
    ConCache.get(:users, id)
  end

  def get_user_by_email(email) do
    id = ConCache.get(:users_lookup_id_with_email, email)
    ConCache.get(:users, id)
  end

  def get_user_by_token(token) do
    case Guardian.resource_from_token(token) do
      {:error, _bad_token} ->
        nil

      {:ok, db_user, _claims} ->
        get_user_by_id(db_user.id)
    end
  end

  def get_user_by_id(id) do
    ConCache.get(:users, int_parse(id))
  end

  @spec rename_user(Types.userid(), String.t()) :: :success | {:error, String.t()}
  def rename_user(userid, new_name) do
    cond do
      clean_name(new_name) != new_name ->
        {:error, "Invalid characters in name (only a-z, A-Z, 0-9, [, ] allowed)"}

      get_user_by_name(new_name) ->
        {:error, "Username already taken"}

      true ->
        do_rename_user(userid, new_name)
        :success
    end
  end

  @spec do_rename_user(Types.userid(), String.t()) :: :ok
  def do_rename_user(userid, new_name) do
    user = get_user_by_id(userid)
    update_user(%{user | rename_in_progress: true}, persist: true)

    # We need to re-get the user to ensure we don't overwrite our rename_in_progress by mistake
    user = get_user_by_id(userid)
    delete_user(user.id)

    db_user = Account.get_user!(userid)
    Account.update_user(db_user, %{"name" => new_name})

    :timer.sleep(5000)
    recache_user(userid)
    user = get_user_by_id(userid)
    update_user(%{user | rename_in_progress: false})
    :ok
  end

  def add_user(user) do
    update_user(user)
    ConCache.put(:users_lookup_name_with_id, user.id, user.name)
    ConCache.put(:users_lookup_id_with_name, user.name, user.id)
    ConCache.put(:users_lookup_id_with_email, user.email, user.id)

    ConCache.update(:lists, :users, fn value ->
      new_value =
        ([user.id | value])
        |> Enum.uniq()

      {:ok, new_value}
    end)

    user
  end

  # Persists the changes into the database so they will
  # be pulled out next time the user is accessed/recached
  # The special case here is to prevent the benchmark and test users causing issues
  defp persist_user(%{name: "TEST_" <> _}), do: nil

  defp persist_user(user) do
    db_user = Account.get_user!(user.id)

    data =
      @data_keys
      |> Map.new(fn k -> {to_string(k), Map.get(user, k, @default_data[k])} end)

    Account.update_user(db_user, %{"data" => data})
  end

  def update_user(user, persist \\ false) do
    ConCache.put(:users, user.id, user)
    if persist, do: persist_user(user)
    user
  end

  def request_password_reset(user) do
    code = :random.uniform(899_999) + 100_000
    update_user(%{user | password_reset_code: "#{code}"})
  end

  def request_email_change(nil, _), do: nil

  def request_email_change(user, new_email) do
    code = :random.uniform(899_999) + 100_000
    update_user(%{user | email_change_code: ["#{code}", new_email]})
  end

  def change_email(user, new_email) do
    ConCache.delete(:users_lookup_id_with_email, user.email)
    ConCache.put(:users_lookup_id_with_email, new_email, user.id)
    update_user(%{user | email: new_email, email_change_code: [nil, nil]})
  end

  def accept_friend_request(nil, _), do: nil
  def accept_friend_request(_, nil), do: nil
  def accept_friend_request(requester_id, accepter_id) do
    accepter = get_user_by_id(accepter_id)

    if requester_id in accepter.friend_requests do
      requester = get_user_by_id(requester_id)

      # Add to friends, remove from requests
      new_accepter =
        Map.merge(accepter, %{
          friends: [requester_id | accepter.friends],
          friend_requests: Enum.filter(accepter.friend_requests, fn f -> f != requester_id end)
        })

      new_requester =
        Map.merge(requester, %{
          friends: [accepter_id | requester.friends]
        })

      update_user(new_accepter, persist: true)
      update_user(new_requester, persist: true)

      Communication.notify(
        new_requester.id,
        %{
          title: "#{new_accepter.name} accepted your friend request",
          body: "#{new_accepter.name} accepted your friend request",
          icon: Teiserver.icon(:friend),
          colour: StylingHelper.get_fg(:success),
          redirect: "/teiserver/account/relationships#friends"
        },
        1,
        prevent_duplicates: true
      )

      # Now push out the updates
      PubSub.broadcast(
        Central.PubSub,
        "user_updates:#{requester_id}",
        {:this_user_updated, [:friends]}
      )

      PubSub.broadcast(
        Central.PubSub,
        "user_updates:#{accepter_id}",
        {:this_user_updated, [:friends, :friend_requests]}
      )

      new_accepter
    else
      accepter
    end
  end

  def decline_friend_request(nil, _), do: nil
  def decline_friend_request(_, nil), do: nil
  def decline_friend_request(requester_id, decliner_id) do
    decliner = get_user_by_id(decliner_id)

    if requester_id in decliner.friend_requests do
      # Remove from requests
      new_decliner =
        Map.merge(decliner, %{
          friend_requests: Enum.filter(decliner.friend_requests, fn f -> f != requester_id end)
        })

      update_user(new_decliner, persist: true)

      # Now push out the updates
      PubSub.broadcast(
        Central.PubSub,
        "user_updates:#{decliner_id}",
        {:this_user_updated, [:friend_requests]}
      )

      new_decliner
    else
      decliner
    end
  end

  def create_friend_request(nil, _), do: nil
  def create_friend_request(_, nil), do: nil
  def create_friend_request(requester_id, potential_id) do
    potential = get_user_by_id(potential_id)

    if requester_id not in potential.friend_requests and requester_id not in potential.friends do
      # Add to requests
      new_potential =
        Map.merge(potential, %{
          friend_requests: [requester_id | potential.friend_requests]
        })

      requester = get_user_by_id(requester_id)
      update_user(new_potential, persist: true)

      Communication.notify(
        new_potential.id,
        %{
          title: "New friend request from #{requester.name}",
          body: "New friend request from #{requester.name}",
          icon: Teiserver.icon(:friend),
          colour: StylingHelper.get_fg(:info),
          redirect: "/teiserver/account/relationships#requests"
        },
        1,
        prevent_duplicates: true
      )

      # Now push out the updates
      PubSub.broadcast(
        Central.PubSub,
        "user_updates:#{potential_id}",
        {:this_user_updated, [:friend_requests]}
      )

      new_potential
    else
      potential
    end
  end

  def ignore_user(nil, _), do: nil
  def ignore_user(_, nil), do: nil
  def ignore_user(ignorer_id, ignored_id) do
    ignorer = get_user_by_id(ignorer_id)

    if ignored_id not in ignorer.ignored do
      # Add to requests
      new_ignorer =
        Map.merge(ignorer, %{
          ignored: [ignored_id | ignorer.ignored]
        })

      update_user(new_ignorer, persist: true)

      # Now push out the updates
      PubSub.broadcast(
        Central.PubSub,
        "user_updates:#{ignorer_id}",
        {:this_user_updated, [:ignored]}
      )

      new_ignorer
    else
      ignorer
    end
  end

  def unignore_user(nil, _), do: nil
  def unignore_user(_, nil), do: nil
  def unignore_user(unignorer_id, unignored_id) do
    unignorer = get_user_by_id(unignorer_id)

    if unignored_id in unignorer.ignored do
      # Add to requests
      new_unignorer =
        Map.merge(unignorer, %{
          ignored: Enum.filter(unignorer.ignored, fn f -> f != unignored_id end)
        })

      update_user(new_unignorer, persist: true)

      # Now push out the updates
      PubSub.broadcast(
        Central.PubSub,
        "user_updates:#{unignorer_id}",
        {:this_user_updated, [:ignored]}
      )

      new_unignorer
    else
      unignorer
    end
  end

  def remove_friend(nil, _), do: nil
  def remove_friend(_, nil), do: nil
  def remove_friend(remover_id, removed_id) do
    remover = get_user_by_id(remover_id)

    if removed_id in remover.friends do
      # Add to requests
      new_remover =
        Map.merge(remover, %{
          friends: Enum.filter(remover.friends, fn f -> f != removed_id end)
        })

      removed = get_user_by_id(removed_id)

      new_removed =
        Map.merge(removed, %{
          friends: Enum.filter(removed.friends, fn f -> f != remover_id end)
        })

      update_user(new_remover, persist: true)
      update_user(new_removed, persist: true)

      # Now push out the updates
      PubSub.broadcast(
        Central.PubSub,
        "user_updates:#{remover_id}",
        {:this_user_updated, [:friends]}
      )

      PubSub.broadcast(
        Central.PubSub,
        "user_updates:#{removed_id}",
        {:this_user_updated, [:friends]}
      )

      new_remover
    else
      remover
    end
  end

  def send_direct_message(from_id, to_id, msg) do
    sender = get_user_by_id(from_id)
    if not is_muted?(sender) do
      PubSub.broadcast(
        Central.PubSub,
        "user_updates:#{to_id}",
        {:direct_message, from_id, msg}
      )
    end
  end

  @spec list_users :: list
  def list_users() do
    ConCache.get(:lists, :users)
    |> Enum.map(fn userid -> ConCache.get(:users, userid) end)
  end

  @spec list_users(list) :: list
  def list_users(id_list) do
    id_list
    |> Enum.map(fn userid ->
      ConCache.get(:users, userid)
    end)
  end

  def ring(ringee_id, ringer_id) do
    PubSub.broadcast(Central.PubSub, "user_updates:#{ringee_id}", {:action, {:ring, ringer_id}})
  end

  @spec test_password(String.t(), String.t()) :: boolean
  def test_password(plain_password, encrypted_password) do
    Argon2.verify_pass(plain_password, encrypted_password)
  end

  def verify_user(user) do
    %{user | verification_code: nil, verified: true}
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

  @spec internal_client_login(Map.t()) :: {:ok, Map.t()} | :error
  def internal_client_login(userid) do
    case get_user_by_id(userid) do
      nil -> :error
      user ->
        do_login(user, "127.0.0.1", "Teiserver Internal Client")
        Client.login(user, self())
        {:ok, user}
    end
  end

  @spec try_login(String.t(), String.t(), String.t()) :: {:ok, Map.t()} | {:error, String.t()} | {:error, String.t(), Integer.t()}
  def try_login(token, ip, lobby) do
    wait_for_precache()

    case Guardian.resource_from_token(token) do
      {:error, _bad_token} ->
        {:error, "token_login_failed"}

      {:ok, db_user, _claims} ->
        user = get_user_by_id(db_user.id)

        cond do
          user.rename_in_progress ->
            {:error, "Rename in progress, wait 5 seconds"}

          # Used for testing, this should never be enabled in production
          Application.get_env(:central, Teiserver)[:autologin] ->
            do_login(user, ip, lobby)

          is_banned?(user) ->
            {:error, "Banned"}

          user.verified == false ->
            {:error, "Unverified", user.id}

          Client.get_client_by_id(user.id) != nil ->
            Client.disconnect(user.id, "Already logged in")
            do_login(user, ip, lobby)

          true ->
            do_login(user, ip, lobby)
        end
    end
  end

  @spec try_md5_login(String.t(), String.t(), String.t(), String.t()) :: {:ok, Map.t()} | {:error, String.t()} | {:error, String.t(), Integer.t()}
  def try_md5_login(username, md5_password, ip, lobby) do
    wait_for_precache()

    case get_user_by_name(username) do
      nil ->
        {:error, "No user found for '#{username}'"}

      user ->
        cond do
          user.rename_in_progress ->
            {:error, "Rename in progress, wait 5 seconds"}

          # Used for testing, this should never be enabled in production
          Application.get_env(:central, Teiserver)[:autologin] ->
            do_login(user, ip, lobby)

          test_password(md5_password, user.password_hash) == false ->
            {:error, "Invalid password"}

          is_banned?(user) ->
            {:error, "Banned"}

          user.verified == false ->
            {:error, "Unverified", user.id}

          Client.get_client_by_id(user.id) != nil ->
            Client.disconnect(user.id, "Already logged in")
            do_login(user, ip, lobby)

          true ->
            do_login(user, ip, lobby)
        end
    end
  end

  @spec do_login(Map.t(), String.t(), String.t()) :: {:ok, Map.t()}
  defp do_login(user, ip, lobbyid) do
    # If they don't want a flag shown, don't show it, otherwise check for an override before trying geoip
    country =
      cond do
        Central.Config.get_user_config_cache(user.id, "teiserver.Show flag") == false ->
          "??"

        user.country_override != nil ->
          user.country_override

        true ->
          Teiserver.Geoip.get_flag(ip)
      end

    last_login = round(:erlang.system_time(:seconds) / 60)
    ingame_hours = user.ingame_minutes / 60

    rank =
      @rank_levels
      |> Enum.filter(fn r -> r < ingame_hours end)
      |> Enum.count()

    springid = if Map.get(user, :springid) != nil, do: user.springid, else: next_springid()
    |> Central.Helpers.NumberHelper.int_parse

    user =
      %{
        user
        | ip: ip,
          lobbyid: lobbyid,
          country: country,
          last_login: last_login,
          rank: rank,
          springid: springid
      }

    update_user(user, persist: true)

    {:ok, user}
  end

  def logout(nil), do: nil

  def logout(user_id) do
    user = get_user_by_id(user_id)
    # TODO In some tests it's possible for last_login to be nil, this is a temporary workaround
    system_minutes = round(:erlang.system_time(:seconds) / 60)

    new_ingame_minutes =
      user.ingame_minutes +
        (system_minutes - (user.last_login || system_minutes))

    user = %{user | ingame_minutes: new_ingame_minutes}
    update_user(user, persist: true)
  end

  def convert_user(user) do
    data =
      @data_keys
      |> Map.new(fn k -> {k, Map.get(user.data || %{}, to_string(k), @default_data[k])} end)

    user
    |> Map.take(@keys)
    |> Map.merge(@default_data)
    |> Map.merge(data)
  end

  @spec new_report(Integer.t()) :: :ok
  def new_report(report_id) do
    report = Account.get_report!(report_id)
    user = get_user_by_id(report.target_id)

    changes =
      case {report.response_action, report.expires} do
        {"Mute", nil} ->
          %{muted: [true, nil]}

        {"Mute", expires} ->
          %{muted: [true, expires]}

        {"Ban", nil} ->
          %{banned: [true, nil]}

        {"Ban", expires} ->
          %{banned: [true, expires]}

        {"Ignore report", nil} ->
          %{}

        {action, _} ->
          throw("No handler for action type '#{action}' in #{__MODULE__}")
      end

    user = Map.merge(user, changes)
    |> update_user(persist: true)

    if is_banned?(user) do
      Client.disconnect(user.id, "Banned")
    end

    :ok
  end

  @spec is_banned?(Integer.t() | Map.t()) :: boolean()
  def is_banned?(nil), do: true
  def is_banned?(userid) when is_integer(userid), do: is_banned?(get_user_by_id(userid))
  def is_banned?(%{banned: banned}) do
    case banned do
      [false, _] -> false
      [true, nil] -> true
      [true, until] -> Timex.compare(Timex.now(), until) != 1
    end
  end

  @spec is_muted?(Integer.t() | Map.t()) :: boolean()
  def is_muted?(nil), do: true
  def is_muted?(userid) when is_integer(userid), do: is_muted?(get_user_by_id(userid))
  def is_muted?(%{muted: muted}) do
    case muted do
      [false, _] -> false
      [true, nil] -> true
      [true, until] -> Timex.compare(Timex.now(), until) != 1
    end
  end

  # Tied to spring's PASSWORDRESET which requires the password to be
  # created and emailed to the user
  def generate_new_password() do
    new_plain_password = generate_random_password()
    new_hash = spring_md5_password(new_plain_password)
    {new_plain_password, new_hash}
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

        update_user(%{user | password_reset_code: nil, password_hash: encrypted_password},
          persist: true
        )
    end
  end

  def spring_reset_password(user, code) do
    case code == user.password_reset_code do
      true ->
        {plain_password, md5_password} = generate_new_password()
        encrypted_password = encrypt_password(md5_password)

        EmailHelper.spring_password_reset(user, plain_password)

        update_user(%{user | password_reset_code: nil, password_hash: encrypted_password},
          persist: true
        )

        # Now update the DB user too
        db_user = Account.get_user!(user.id)
        Account.script_update_user(db_user, %{"password" => encrypted_password})

        :ok

      false ->
        :error
    end
  end

  @spec recache_user(Integer.t()) :: :ok
  def recache_user(id) do
    if get_user_by_id(id) do
      Account.get_user!(id)
      |> convert_user
      |> update_user
    else
      Account.get_user!(id)
      |> convert_user
      |> add_user
    end

    :ok
  end

  def delete_user(userid) do
    user = get_user_by_id(userid)

    if user do
      Client.disconnect(userid, "User deletion")
      :timer.sleep(100)

      ConCache.delete(:users, userid)
      ConCache.delete(:users_lookup_name_with_id, user.id)
      ConCache.delete(:users_lookup_id_with_name, user.name)
      ConCache.delete(:users_lookup_id_with_email, user.email)

      ConCache.update(:lists, :users, fn value ->
        new_value =
          value
          |> Enum.filter(fn v -> v != userid end)

        {:ok, new_value}
      end)
    end
  end

  def allow?(userid, permission) do
    user = get_user_by_id(userid)

    case permission do
      :moderator ->
        user.moderator

      _ ->
        false
    end
  end

  def pre_cache_users() do
    ConCache.insert_new(:lists, :users, [])

    user_count =
      Account.list_users(limit: :infinity)
      |> Parallel.map(fn user ->
        user
        |> convert_user
        |> add_user
      end)
      |> Enum.count()

    Logger.info("pre_cache_users, got #{user_count} users")
  end
end
