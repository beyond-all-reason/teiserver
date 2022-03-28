defmodule Teiserver.Coordinator.AutomodServer do
  @moduledoc """
  The coordinator server is the interface point for the Coordinator system. Consuls are invisible (to the players) processes
  performing their actions in the name of the coordinator
  """
  use GenServer
  alias Central.Config
  import Central.Logging.Helpers, only: [add_audit_log: 4]
  alias Teiserver.{Account, User, Client, Coordinator}
  alias Phoenix.PubSub
  require Logger
  alias Teiserver.Data.Types, as: T

  @tick_interval 60_000

  @spec check_user(T.userid()) :: nil
  def check_user(userid) do
    case ConCache.get(:teiserver_consul_pids, :automod) do
      nil -> nil
      pid ->
        GenServer.call(pid, {:check_user, userid})
    end
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  def handle_info(:begin, state) do
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

  # Client inout
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
    send(self(), :begin)
    ConCache.put(:teiserver_consul_pids, :automod, self())
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_client_inout")
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
          true -> do_check(userid)
        end
    end
  end

  @spec do_check(T.userid()) :: String.t()
  defp do_check(userid) do
    stats = Account.get_user_stat_data(userid)

    if User.is_restricted?(userid, ["Login"]) do
      "Already banned"
    else
      with nil <- do_hw_check(userid, stats),
        nil <- do_lobby_hash_check(userid, stats)
      do
        "No action"
      else
        reason -> reason
      end
    end
  end

  @spec do_hw_check(T.userid(), map()) :: String.t() | nil
  defp do_hw_check(userid, stats) do
    hw_fingerprint = Teiserver.Account.RecalculateUserHWTask.calculate_hw_fingerprint(stats)

    if hw_fingerprint != "" do
      Account.update_user_stat(userid, %{
        hw_fingerprint: hw_fingerprint
      })

      user = User.get_user_by_id(userid)
      User.update_user(%{user | hw_hash: hw_fingerprint}, persist: true)

      hashes = Account.list_automod_actions(search: [
        enabled: true,
        type: "hardware",
        value: hw_fingerprint
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
    user = User.get_user_by_id(userid)
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
