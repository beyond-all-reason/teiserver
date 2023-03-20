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

  # TODO: Create a handler that always errors and gives a dispatch error
  defp get_handler(m), do: Handlers.System.ErrorRequest
end
