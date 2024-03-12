defmodule Barserver.Tachyon.CommandDispatch do
  @moduledoc """

  """

  def dispatch(conn, object, meta) do
    handler = get_dispatch_handler(meta["command"])

    handler.(conn, object, meta)
  end

  defp get_dispatch_handler(command) do
    # Get the relevant handler, if none found the no_command fallback will handle it
    Barserver.store_get(:tachyon_dispatches, command) ||
      Barserver.store_get(:tachyon_dispatches, "no_command")
  end

  @spec build_dispatch_cache :: :ok
  def build_dispatch_cache do
    # Get every single module in that namespace
    # if it has a dispatch_handlers function we make use of it
    {:ok, module_list} = :application.get_key(:teiserver, :modules)

    lookup =
      module_list
      |> Enum.filter(fn m ->
        m |> Module.split() |> Enum.take(3) == ["Barserver", "Tachyon", "Handlers"]
      end)
      |> Enum.filter(fn m ->
        Code.ensure_loaded(m)
        function_exported?(m, :dispatch_handlers, 0)
      end)
      |> Enum.reduce(%{}, fn module, acc ->
        Map.merge(acc, module.dispatch_handlers())
      end)

    old = Barserver.store_get(:tachyon_dispatches, "all") || []

    # Store all keys, we'll use it later for removing old ones
    Barserver.store_put(:tachyon_dispatches, "all", Map.keys(lookup))

    # Now store our lookups
    lookup
    |> Enum.each(fn {key, func} ->
      Barserver.store_put(:tachyon_dispatches, key, func)
    end)

    # Special case
    no_command_func = &Barserver.Tachyon.Handlers.System.NoCommandErrorRequest.execute/3
    Barserver.store_put(:tachyon_dispatches, "no_command", no_command_func)

    # Delete out-dated keys
    old
    |> Enum.reject(fn old_key ->
      Map.has_key?(lookup, old_key)
    end)
    |> Enum.each(fn old_key ->
      Barserver.store_delete(:tachyon_dispatches, old_key)
    end)

    :ok
  end
end
