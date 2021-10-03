defmodule Teiserver.Coordinator.AutomodServer do
  @moduledoc """
  The coordinator server is the interface point for the Coordinator system. Consuls are invisible (to the players) processes
  performing their actions in the name of the coordinator
  """
  use GenServer
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
    :timer.send_after(5_000, {:check_user, userid})
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
      %{name: "PtaQ"} -> "PICKAXE"
      %{name: "Damgam"} -> "It's all his fault"
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

  # TODO: Refactor into a with statement for multiple types of hash
  @spec do_check(T.userid()) :: String.t()
  defp do_check(userid) do
    stats = case Account.get_user_stat(userid) do
      nil -> %{}
      v -> v.data
    end

    hw_fingerprint = Teiserver.Account.RecalculateUserStatTask.calculate_hw_fingerprint(stats)

    if hw_fingerprint != "" do
      hashes = Account.list_ban_hashes(search: [
        type: "hardware",
        value: hw_fingerprint
      ], limit: 1)

      if not Enum.empty?(hashes) do
        hashid = hd(hashes).id
        Logger.error("Automod found a hash matching hash##{hashid} for user #{userid}")
        # coordinator_id = Coordinator.get_coordinator_userid()
        # Central.Account.create_report(%{
        #   "location" => "automod",
        #   "location_id" => nil,
        #   "reason" => "Ban evasion",
        #   "reporter_id" => coordinator_id,
        #   "target_id" => userid,
        #   "response_text" => "Hashmatch #{hashid}",
        #   "response_action" => "Ban",
        #   "expires" => nil,
        #   "responder_id" => coordinator_id
        # })
        user = User.get_user_by_id(userid)
        Account.update_user_stat(userid, %{"autoban" => "HW Hash ##{hashid}"})
        User.update_user(%{user | banned: [true, nil]})
        Client.disconnect(user.id, :banned)
        Logger.error("Automod added ban action for userid: #{userid}, name: #{user.name}")
        "Banned user"
      else
        "No action"
      end
    else
      "User has no hw fingerpint"
    end
  end
end
