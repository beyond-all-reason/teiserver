defmodule Teiserver.Coordinator.AutomodServer do
  use GenServer
  alias Central.Config
  import Central.Logging.Helpers, only: [add_audit_log: 4]
  alias Teiserver.{Account, User, Coordinator}
  alias Phoenix.PubSub
  require Logger
  alias Teiserver.Data.Types, as: T

  @tick_interval 60_000

  @spec check_user(T.userid()) :: nil
  def check_user(userid) do
    case Horde.Registry.lookup(Teiserver.ServerRegistry, "AutomodServer") do
      [{pid, _}] ->
        GenServer.call(pid, {:check_user, userid})
      _ ->
        nil
    end
  end

  @spec start_automod_server() :: :ok | {:failure, String.t()}
  def start_automod_server() do
    case Horde.Registry.lookup(Teiserver.ServerRegistry, "AutomodServer") do
      [{_pid, _}] ->
        {:failure, "Already started"}
      _ ->
        do_start()
    end
  end

  @spec do_start() :: :ok
  defp do_start() do
    {:ok, _coordinator_pid} =
      DynamicSupervisor.start_child(Teiserver.Coordinator.DynamicSupervisor, {
        Teiserver.Coordinator.AutomodServer,
        name: Teiserver.Coordinator.AutomodServer,
        data: %{}
      })
    :ok
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  def handle_info(:begin, state) do
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_client_inout")
    coordinator_id = Coordinator.get_coordinator_userid()

    if coordinator_id != nil do
      :timer.send_interval(@tick_interval, :tick)

      {:noreply, %{
        coordinator_id: Coordinator.get_coordinator_userid()
      }}
    else
      :timer.send_after(5_000, :begin)
      {:noreply, state}
    end
  end

  def handle_info(:tick, state) do
    {:noreply, state}
  end

  def handle_info({:check_user, userid}, state) do
    check_wrapper(userid)
    {:noreply, state}
  end

  def handle_info({:client_inout, :login, userid}, state) do
    delay = Config.get_site_config_cache("teiserver.Automod action delay") * 1000
    :timer.send_after(delay, {:check_user, userid})
    {:noreply, state}
  end
  def handle_info({:client_inout, :disconnect, _userid, _reason}, state), do: {:noreply, state}

  # Catchall handle_info
  def handle_info(msg, state) do
    Logger.error("AutoMod handle_info error. No handler for msg of #{Kernel.inspect msg}")
    {:noreply, state}
  end

  # Calls
  def handle_call({:check_user, userid}, _from, state) do
    {:reply, check_wrapper(userid), state}
  end

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(_opts) do
    Horde.Registry.register(
      Teiserver.ServerRegistry,
      "AutomodServer",
      :automod
    )

    :timer.send_after(500, :begin)
    {:ok, %{}}
  end

  # Internal functions
  @spec check_wrapper(T.userid()) :: String.t()
  defp check_wrapper(userid) do
    case User.get_user_by_id(userid) do
      nil -> "No user"
      %{bot: true} -> "Bot account"
      %{moderator: true} -> "Moderator account"
      user ->
        cond do
          Enum.member?(user.roles, "Developer") -> "Developer account"
          Enum.member?(user.roles, "Trusted") -> "Trusted account"
          true ->
            # do_check(userid)
            do_old_check(userid)
        end
    end
  end

  @spec do_check(T.userid()) :: String.t()
  def do_check(userid) do
    if User.is_restricted?(userid, ["Login"]) do
      "Already banned"
    else
      smurf_keys = Account.list_smurf_keys(search: [user_id: userid], select: [:type_id, :value])

      value_list = smurf_keys
        |> Enum.map(fn %{value: value} -> value end)

      _automods = Account.list_automod_actions(search: [
        enabled: true,
        type: "hardware",
        value_in: value_list
      ])
      |> Kernel.inspect
    end
  end

  @spec do_old_check(T.userid()) :: String.t()
  defp do_old_check(userid) do
    stats = Account.get_user_stat_data(userid)

    if User.is_restricted?(userid, ["Login"]) do
      "Already banned"
    else
      with nil <- do_hw1_check(userid, stats),
        nil <- do_lobby_hash_check(userid, stats)
      do
        "No action"
      else
        reason -> reason
      end
    end
  end

  @spec do_hw1_check(T.userid(), map()) :: String.t() | nil
  defp do_hw1_check(userid, stats) do
    hw1_fingerprint = Teiserver.Account.CalculateSmurfKeyTask.calculate_hw1_fingerprint(stats)

    if hw1_fingerprint != "" do
      Account.update_user_stat(userid, %{
        hw1_fingerprint: hw1_fingerprint
      })

      user = User.get_user_by_id(userid)
      User.update_user(%{user | hw_hash: hw1_fingerprint}, persist: true)

      hashes = Account.list_automod_actions(search: [
        enabled: true,
        type: "hardware",
        value: hw1_fingerprint
      ], limit: 1)

      if not Enum.empty?(hashes) do
        automod_action = hd(hashes)
        do_ban(userid, automod_action)
      else
        nil
      end
    else
      nil
    end
  end

  @spec do_lobby_hash_check(T.userid(), map()) :: String.t() | nil
  defp do_lobby_hash_check(userid, stats) do
    case stats["lobby_hash"] || nil do
      nil ->
        nil
      hash ->
        hashes = Account.list_automod_actions(search: [
          enabled: true,
          type: "lobby_hash",
          value: hash
        ], limit: 1)

        if not Enum.empty?(hashes) do
          automod_action = hd(hashes)
          do_ban(userid, automod_action)
        else
          nil
        end
    end
  end

  def do_ban(userid, automod_action) do
    Account.update_user_stat(userid, %{"autoban_type" => automod_action.type, "autoban_id" => automod_action.id})

    coordinator_user_id = Coordinator.get_coordinator_userid()

    {:ok, report} = Central.Account.create_report(%{
      "location" => "Automod",
      "location_id" => nil,
      "reason" => "Automod",
      "reporter_id" => coordinator_user_id,
      "target_id" => userid,
      "response_text" => "Automod",
      "response_action" => "Restrict",
      "responded_at" => Timex.now(),
      "followup" => nil,
      "code_references" => [],
      "expires" => nil,
      "responder_id" => coordinator_user_id,
      "action_data" => %{
        "restriction_list" => ["Login", "Site"]
      }
    })

    add_audit_log(
      coordinator_user_id,
      "127.0.0.0",
      "Teiserver:Automod action enacted",
      %{
        "report_id" => report.id,
        "target_user_id" => userid,
        "automod_action_id" => automod_action.id,
      }
    )

    "Banned user"
  end
end
