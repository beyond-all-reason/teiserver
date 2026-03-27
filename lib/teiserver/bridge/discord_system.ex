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

    start()

    {:ok, sup_flags}
  end

  @spec start :: Task.t()
  def start do
    Task.async(fn ->
      if Communication.use_discord?() do
        DynamicSupervisor.start_child(
          __MODULE__,
          Supervisor.child_spec(Teiserver.Bridge.DiscordSupervisor, restart: :temporary)
        )
      else
        :disabled_by_configuration
      end
    end)
  end

  @spec restart :: Task.t()
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
