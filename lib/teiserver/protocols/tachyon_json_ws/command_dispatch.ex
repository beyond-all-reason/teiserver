defmodule Teiserver.Tachyon.CommandDispatch do
  @moduledoc """

  """

  alias Teiserver.Tachyon.Handlers

  def dispatch(conn, object, meta) do
    handler_module = get_handler(meta["command"])

    handler_module.execute(conn, object, meta)
  end

  @spec get_handler(String.t()) :: module
  defp get_handler("account/who_am_i/request"), do: Handlers.Account.WhoamiRequest

  defp get_handler("disconnect"), do: Handlers.System.DisconnectRequest
  defp get_handler("force_error"), do: Handlers.System.ForceErrorRequest
  defp get_handler(_), do: Handlers.System.NoCommandErrorRequest
end
