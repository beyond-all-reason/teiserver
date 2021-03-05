defmodule Teiserver.User do
  @moduledoc """
  Users here are a combination of Central.Account.User and the data within. They are merged like this into a map as their exepected use case is very different.
  """
  alias Teiserver.Client

  @wordlist ~w(abacus rhombus square shape oblong rotund bag dice flatulance cats dogs mice oranges apples pears neon lights electricity calculator harddrive cpu memory graphics monitor screen television radio microwave)

  @keys [:id, :name, :email, :inserted_at]
  @data_keys [
    :rank,
    :country,
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
    :ingame_seconds,
    :mmr
  ]

  @default_data %{
    rank: 1,
    country: "??",
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
    ingame_seconds: 0,
    mmr: %{}
  }

  require Logger
  alias Phoenix.PubSub
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  alias Teiserver.EmailHelper
  alias Teiserver.Account

  def generate_random_password() do
    @wordlist
    |> Enum.take_random(3)
    |> Enum.join(" ")
  end

  def clean_name(name) do
    ~r/([^a-zA-Z0-9_\-\[\]]|\s)/
    |> Regex.replace(name, "")
  end

  def bar_user_group_id() do
    ConCache.get(:application_metadata_cache, "bar_user_group")
  end

  def user_register_params(name, email, password_hash, extra_data \\ %{}) do
    name = clean_name(name)
    verification_code = :random.uniform(899_999) + 100_000

    data =
      @default_data
      |> Map.new(fn {k, v} -> {to_string(k), v} end)

    %{
      name: name,
      email: email,
      password: "#{:random.uniform(999_999_999_999_999_999)}",
      colour: "#AA0000",
      icon: "fas fa-user",
      admin_group_id: bar_user_group_id(),
      permissions: ["teiserver", "teiserver.player", "teiserver.player.account"],
      data:
        data
        |> Map.merge(%{
          "password_hash" => password_hash,
          "verification_code" => verification_code
        })
        |> Map.merge(extra_data)
    }
  end

  def register_user(name, email, password_hash) do
    params = user_register_params(name, email, password_hash)

    case Account.create_user(params) do
      {:ok, user} ->
        Account.create_group_membership(%{
          user_id: user.id,
          group_id: bar_user_group_id()
        })

        # Now add them to the cache
        user
        |> convert_user
        |> add_user

        # EmailHelper.send_email(to, subject, body)
        Logger.debug(
          "TODO: Verification email should be sent here with code #{
            user.data["verification_code"]
          }"
        )

        user

      {:error, changeset} ->
        Logger.error(
          "Unable to create user with params #{Kernel.inspect(params)}\n#{
            Kernel.inspect(changeset)
          }"
        )
    end
  end

  def register_bot(bot_name, bot_host_id) do
    existing_bot = get_user_by_name(bot_name)

    if existing_bot do
      existing_bot
    else
      host = get_user_by_id(bot_host_id)

      params =
        user_register_params(bot_name, host.email, host.password_hash, %{
          "bot" => true,
          "verified" => true
        })
        |> Map.merge(%{
          email: String.replace(host.email, "@", ".bot#{bot_name}@")
        })

      case Account.create_user(params) do
        {:ok, user} ->
          Account.create_group_membership(%{
            user_id: user.id,
            group_id: bar_user_group_id()
          })

          # Now add them to the cache
          user
          |> convert_user
          |> add_user

        {:error, changeset} ->
          Logger.error(
            "Unable to create user with params #{Kernel.inspect(params)}\n#{
              Kernel.inspect(changeset)
            }"
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

  def get_user_by_id(id) do
    ConCache.get(:users, int_parse(id))
  end

  def get_users(id_list) do
    id_list
    |> Enum.map(fn userid -> ConCache.get(:users, userid) end)
  end

  def rename_user(user, new_name) do
    old_name = user.name
    new_name = clean_name(new_name)
    new_user = %{user | name: new_name}

    ConCache.delete(:users_lookup_id_with_name, old_name)
    ConCache.put(:users_lookup_name_with_id, user.id, new_name)
    ConCache.put(:users_lookup_id_with_name, new_name, user.id)
    ConCache.put(:users, user.id, new_user)
    new_user
  end

  def add_user(user) do
    update_user(user)
    ConCache.put(:users_lookup_name_with_id, user.id, user.name)
    ConCache.put(:users_lookup_id_with_name, user.name, user.id)
    ConCache.put(:users_lookup_id_with_email, user.email, user.id)

    ConCache.update(:lists, :users, fn value ->
      new_value =
        (value ++ [user.id])
        |> Enum.uniq()

      {:ok, new_value}
    end)

    user
  end

  # Persists the changes into the database so they will
  # be pulled out next time the user is accessed/recached
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

  def generate_new_password() do
    new_plain_password = generate_random_password()
    new_encrypted_password = encrypt_password(new_plain_password)
    {new_plain_password, new_encrypted_password}
  end

  def reset_password(user, code) do
    case code == user.password_reset_code do
      true ->
        {plain_password, encrypted_password} = generate_new_password()
        EmailHelper.send_new_password(user, plain_password)
        update_user(%{user | password_reset_code: nil, password_hash: encrypted_password})
        :ok

      false ->
        :error
    end
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

  def accept_friend_request(requester_id, accepter_id) do
    accepter = get_user_by_id(accepter_id)

    if requester_id in accepter.friend_requests do
      requester = get_user_by_id(requester_id)

      # Add to friends, remove from requests
      new_accepter =
        Map.merge(accepter, %{
          friends: accepter.friends ++ [requester_id],
          friend_requests: Enum.filter(accepter.friend_requests, fn f -> f != requester_id end)
        })

      new_requester =
        Map.merge(requester, %{
          friends: requester.friends ++ [accepter_id]
        })

      update_user(new_accepter)
      update_user(new_requester)

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

  def decline_friend_request(requester_id, decliner_id) do
    decliner = get_user_by_id(decliner_id)

    if requester_id in decliner.friend_requests do
      # Remove from requests
      new_decliner =
        Map.merge(decliner, %{
          friend_requests: Enum.filter(decliner.friend_requests, fn f -> f != requester_id end)
        })

      update_user(new_decliner)

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

  def create_friend_request(requester_id, potential_id) do
    potential = get_user_by_id(potential_id)

    if requester_id not in potential.friend_requests and requester_id not in potential.friends do
      # Add to requests
      new_potential =
        Map.merge(potential, %{
          friend_requests: potential.friend_requests ++ [requester_id]
        })

      update_user(new_potential)

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

  def ignore_user(ignorer_id, ignored_id) do
    ignorer = get_user_by_id(ignorer_id)

    if ignored_id not in ignorer.ignored do
      # Add to requests
      new_ignorer =
        Map.merge(ignorer, %{
          ignored: ignorer.ignored ++ [ignored_id]
        })

      update_user(new_ignorer)

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

  def unignore_user(unignorer_id, unignored_id) do
    unignorer = get_user_by_id(unignorer_id)

    if unignored_id in unignorer.ignored do
      # Add to requests
      new_unignorer =
        Map.merge(unignorer, %{
          ignored: Enum.filter(unignorer.ignored, fn f -> f != unignored_id end)
        })

      update_user(new_unignorer)

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

      update_user(new_remover)
      update_user(new_removed)

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
    PubSub.broadcast(
      Central.PubSub,
      "user_updates:#{to_id}",
      {:direct_message, from_id, msg}
    )
  end

  def list_users() do
    ConCache.get(:lists, :users)
    |> Enum.map(fn userid -> ConCache.get(:users, userid) end)
  end

  def ring(ringee_id, ringer_id) do
    PubSub.broadcast(Central.PubSub, "user_updates:#{ringee_id}", {:ring, ringer_id})
  end

  def encrypt_password(password) do
    :crypto.hash(:md5, password) |> Base.encode64()
  end

  @spec test_password(String.t(), String.t() | Map.t()) :: boolean
  def test_password(password, user) when is_map(user) do
    test_password(password, user.password_hash)
  end

  def test_password(password, existing_password) do
    password == existing_password
  end

  def try_login(username, password, state, ip, lobby) do
    case get_user_by_name(username) do
      nil ->
        {:error, "No user found for '#{username}'"}

      user ->
        case test_password(password, user) do
          true ->
            do_login(user, state, ip, lobby)

          false ->
            {:error, "Invalid password"}
        end
    end
  end

  defp do_login(user, state, ip, lobbyid) do
    country = Teiserver.Geoip.get_flag(ip)
    last_login = :erlang.system_time(:seconds)
    user = %{user | ip: ip, lobbyid: lobbyid, country: country, last_login: last_login}
    update_user(user, persist: true)

    proto = state.protocol

    proto.reply(:login_accepted, user.name, state)
    proto.reply(:motd, nil, state)

    {:ok, user}
  end

  def logout(nil), do: nil

  def logout(user_id) do
    user = get_user_by_id(user_id)
    # TODO In some tests it's possible for last_login to be nil, this is a temoparay workaround
    new_ingame_seconds =
      user.ingame_seconds +
        (:erlang.system_time(:seconds) - (user.last_login || :erlang.system_time(:seconds)))

    user = %{user | ingame_seconds: new_ingame_seconds}
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
  end

  def delete_user(userid) do
    user = get_user_by_id(userid)

    if user do
      Client.disconnect(userid)
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

  def pre_cache_users() do
    group_id = bar_user_group_id()
    ConCache.insert_new(:lists, :users, [])

    user_count =
      Account.list_users(
        search: [
          # Get from the bar group or the admins
          admin_group: [group_id, 1]
        ]
      )
      |> Parallel.map(fn user ->
        user
        |> convert_user
        |> add_user
      end)
      |> Enum.count()

    # This is mostly so I can see exactly when the restart happened and get logs from this point on
    Logger.info("----------------------------------------")
    Logger.info("pre_cache_users, got #{user_count} users")
    Logger.info("----------------------------------------")
  end
end
