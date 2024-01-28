defmodule Barserver.Throttles do
  @spec start_throttle(integer(), module(), String.t()) :: pid()
  def start_throttle(id, module, name) do
    {:ok, throttle_pid} =
      DynamicSupervisor.start_child(Barserver.Throttles.Supervisor, {
        module,
        name: name, data: %{id: id}
      })

    throttle_pid
  end

  @spec get_throttle_pid({atom(), integer()}) :: pid() | nil
  def get_throttle_pid(key) do
    case Horde.Registry.lookup(Barserver.ThrottleRegistry, key) do
      [{pid, _}] ->
        pid

      _ ->
        nil
    end
  end

  @spec stop_throttle({atom(), integer()}) :: nil | :ok
  def stop_throttle(key) do
    case get_throttle_pid(key) do
      nil ->
        nil

      pid ->
        DynamicSupervisor.terminate_child(Barserver.Throttles.Supervisor, pid)
        :ok
    end
  end
end
