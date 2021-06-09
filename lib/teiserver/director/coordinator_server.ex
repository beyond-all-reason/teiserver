defmodule Teiserver.Director.CoordinatorServer do
  use GenServer
  alias Teiserver.Account
  alias Teiserver.User
  require Logger

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  def handle_info(:begin, _state) do
    Logger.debug("Starting up Director coordinator")
    account = get_coordinator_account()

    consuls = case list_consuls() do
      [] ->
        new_consul = create_consul(1)
        IO.puts ""
        IO.inspect new_consul
        IO.puts ""
        [new_consul]

      consul_list ->
        consul_list
    end

    {:noreply, %{
      account: account,
      consuls: consuls |> Map.new(fn c -> {c.id, {nil, :disconnected}} end)
    }}
  end

  def handle_info({:request_consul, battle_id}, state) do
    {consul_id, consul_state} = get_next_consul(state.consuls)

    case consul_state do
      :idle ->
        nil

      :disconnected ->
        connect_consul(consul_id)

      nil ->
        # consul_id = create_consul()
        # connect_consul(consul_id)
        nil
    end

    {:noreply, state}
  end

  def handle_info({:remove_consul, battle_id}, state) do
    {:noreply, state}
  end

  @spec get_next_consul(Map.t()) :: {integer(), :idle | :disconnected} | {nil, nil}
  defp get_next_consul(consuls) do
    available = consuls
    |> Enum.group_by(fn {_k, {_pid, c_state}} ->
      c_state
    end, fn {consul_id, _v} ->
      consul_id
    end)

    cond do
      Map.has_key?(available, :idle) ->
        {hd(available[:idle]), :idle}

      Map.has_key?(available, :disconnected) ->
        {hd(available[:disconnected]), :disconnected}

      true ->
        {nil, nil}
    end
  end

  defp connect_consul(id) do
    db_user = Account.get_user!(id)
    token = User.create_token(db_user)
    {:ok, user} = User.try_login(token, "127.0.0.1", "Teiserver Internal Process")

    :timer.sleep(1000)
  end

  @spec get_coordinator_account() :: Central.Account.User.t()
  def get_coordinator_account() do
    user = Account.get_user(nil, search: [
      exact_name: "Coordinator"
    ])

    case user do
      nil ->
        # Make account
        {:ok, account} = Account.create_user(%{
          name: "Coordinator",
          email: "coordinator@teiserver",
          icon: "fa-solid fa-sitemap",
          colour: "#AA00AA",
          admin_group_id: Teiserver.internal_group_id(),
          password: make_password(),
          data: %{
            bot: true,
            moderator: true,
            verified: true,
            country_override: "GB",# TODO: Make this configurable
            lobbyid: "Teiserver Internal Process"
          }
        })

        Account.create_group_membership(%{
          user_id: account.id,
          group_id: Teiserver.internal_group_id()
        })

        User.recache_user(account.id)
        account

      account ->
        account
    end
  end

  @spec create_consul(integer()) :: Central.Account.User.t()
  def create_consul(id) do
    {:ok, account} = Account.create_user(%{
      name: "Consul_#{id}",
      email: "consul_#{id}@teiserver",
      icon: "fa-solid fa-user-police",
      colour: "#660066",
      admin_group_id: Teiserver.internal_group_id(),
      password: make_password(),
      data: %{
        bot: true,
        moderator: false,
        verified: true,
        country_override: "GB",# TODO: Make this configurable
        lobbyid: "Teiserver Internal Process"
      }
    })

    Account.create_group_membership(%{
      user_id: account.id,
      group_id: Teiserver.internal_group_id()
    })

    User.recache_user(account.id)
    account
  end

  @spec list_consuls() :: [Central.Account.User.t()]
  defp list_consuls() do
    Account.list_users(search: [
      name_like: "Consul_",
      bot: "Robot"
    ], select: [:id])
  end

  defp login_consul(id) do

  end

  @spec make_password() :: String.t
  defp make_password() do
    :crypto.strong_rand_bytes(64) |> Base.encode64(padding: false) |> binary_part(0, 64)
  end

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    {:ok,
     %{
       battle_id: opts[:battle_id],
       game_mode: "team"
     }}
  end
end
