defmodule Teiserver.Tachyon.CommandDispatch do
  @moduledoc """

  """

  alias Teiserver.Tachyon.Handlers

  @modules [
    Handlers.Account.WhoamiRequest,
    Handlers.Communication.SendDirectMessageRequest,
    Handlers.Lobby.ListLobbiesRequest,
    Handlers.Lobby.JoinRequest,
    Handlers.Lobby.LeaveRequest,
    Handlers.LobbyHost.CreateRequest,
    Handlers.System.DisconnectRequest,
    Handlers.System.ForceErrorRequest
  ]

  def dispatch(conn, object, meta) do
    handler = get_dispatch_handler(meta["command"])

    handler.(conn, object, meta)
  end

  defp get_dispatch_handler(command) do
    # Get the relevant handler, if none found the no_command fallback will handle it
    Central.store_get(:tachyon_dispatches, command) ||
      Central.store_get(:tachyon_dispatches, "no_command")
  end

  @spec build_dispatch_cache :: :ok
  def build_dispatch_cache do
    lookup =
      @modules
      |> Enum.reduce(%{}, fn module, acc ->
        Map.merge(acc, module.dispatch_handlers())
      end)

    old = Central.store_get(:tachyon_dispatches, "all") || []

    # Store all keys, we'll use it later for removing old ones
    Central.store_put(:tachyon_dispatches, "all", Map.keys(lookup))

    # Now store our lookups
    lookup
    |> Enum.each(fn {key, func} ->
      Central.store_put(:tachyon_dispatches, key, func)
    end)

    no_command_func = &Handlers.System.NoCommandErrorRequest.execute/3
    Central.store_put(:tachyon_dispatches, "no_command", no_command_func)

    # Delete out-dated keys
    old
    |> Enum.reject(fn old_key ->
      Map.has_key?(lookup, old_key)
    end)
    |> Enum.each(fn old_key ->
      Central.store_delete(:tachyon_dispatches, old_key)
    end)

    :ok
  end
end
