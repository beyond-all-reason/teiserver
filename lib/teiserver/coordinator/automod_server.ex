defmodule Teiserver.Coordinator.AutomodServer do
  use GenServer
  alias Central.Config
  import Teiserver.Logging.Helpers, only: [add_audit_log: 4]
  alias Teiserver.{Account, User, Moderation, Coordinator, Client}
  alias Phoenix.PubSub
  require Logger
  alias Teiserver.Data.Types, as: T

  @tick_interval 60_000

  @spec check_user(T.userid()) :: nil
  def check_user(userid) do
    check_wrapper(userid)
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
        name: Teiserver.Coordinator.AutomodServer, data: %{}
      })

    :ok
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  def handle_info(:begin, state) do
    :ok = PubSub.subscribe(Central.PubSub, "client_inout")
    coordinator_id = Coordinator.get_coordinator_userid()

    if coordinator_id != nil do
      :timer.send_interval(@tick_interval, :tick)

      {:noreply,
       %{
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

  def handle_info(%{channel: "client_inout", event: :login, userid: userid}, state) do
    delay = Config.get_site_config_cache("teiserver.Automod action delay") * 1000
    :timer.send_after(delay, {:check_user, userid})
    {:noreply, state}
  end

  def handle_info(%{channel: "client_inout"}, state), do: {:noreply, state}

  # Catchall handle_info
  def handle_info(msg, state) do
    Logger.error("AutoMod handle_info error. No handler for msg of #{Kernel.inspect(msg)}")
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
      nil ->
        "No user"

      %{bot: true} ->
        "Bot account"

      %{moderator: true} ->
        "Moderator account"

      user ->
        cond do
          Enum.member?(user.roles, "Developer") ->
            "Developer account"

          Enum.member?(user.roles, "Trusted") ->
            "Trusted account"

          true ->
            do_check(user)
        end
    end
  end

  @spec do_check(T.user() | T.userid()) :: String.t()
  def do_check(userid) when is_integer(userid) do
    do_check(Account.get_user_by_id(userid))
  end

  def do_check(user) do
    if User.is_restricted?(user, ["Login"]) do
      "Already banned"
    else
      smurf_keys =
        Account.list_smurf_keys(
          search: [
            user_id: user.id
          ],
          preload: [:type]
        )

      value_list = smurf_keys |> Enum.map(fn %{value: value} -> value end)

      Moderation.list_bans(
        search: [
          enabled: true,
          any_key: value_list,
          added_before: user.inserted_at
        ],
        limit: 1
      )
      |> enact_ban(user.id)
    end
  end

  def enact_ban([], _), do: "No action"

  def enact_ban([ban | _], userid) do
    Account.update_user_stat(userid, %{"autoban_id" => ban.id})

    coordinator_user_id = Coordinator.get_coordinator_userid()

    {:ok, action} =
      Moderation.create_action(%{
        target_id: userid,
        reason: "Banned (Automod)",
        restrictions: ["Login", "Site", "Permanently banned"],
        score_modifier: 0,
        expires: Timex.now() |> Timex.shift(years: 1300)
      })

    Teiserver.Moderation.RefreshUserRestrictionsTask.refresh_user(action.target_id)

    add_audit_log(
      coordinator_user_id,
      "127.0.0.0",
      "Moderation:Ban enacted",
      %{
        "action_id" => action.id,
        "target_user_id" => userid,
        "ban_id" => ban.id
      }
    )

    Client.disconnect(userid, "Banned")

    "Banned user"
  end
end
