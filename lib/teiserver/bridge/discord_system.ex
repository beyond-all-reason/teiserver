defmodule Teiserver.Bridge.DiscordSystem do
  @moduledoc false
  alias Teiserver.Communication

  use DynamicSupervisor
  use Task

  def start_link(_init_arg) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl DynamicSupervisor
  def init(_init_arg) do
    {:ok, sup_flags} = DynamicSupervisor.init(strategy: :one_for_one)

    Task.Supervisor.start_child(Teiserver.TaskSupervisor, &start/0)

    {:ok, sup_flags}
  end

  @spec start :: Supervisor.on_start_child() | :disabled
  def start do
    if Communication.use_discord?() do
      DynamicSupervisor.start_child(
        __MODULE__,
        Supervisor.child_spec(Teiserver.Bridge.DiscordSupervisor, restart: :temporary)
      )
    else
      :disabled
    end
  end

  @spec restart :: Supervisor.on_start_child() | :disabled
  def restart do
    case Process.whereis(Teiserver.Bridge.DiscordSupervisor) do
      x when is_pid(x) ->
        DynamicSupervisor.terminate_child(
          __MODULE__,
          x
        )

      _other ->
        :ok
    end

    start()
  end
end
