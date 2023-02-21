defmodule Teiserver.Tachyon.ClientDispatcher do
  alias Teiserver.Tachyon.ClientAuthHandler
  alias Teiserver.Tachyon.TachyonPbLib

  def dispatch(type, object, state) do
    func = get_handler(type)
    result_object = func.(object, state)

    result_type = TachyonPbLib.get_atom(result_object.__struct__)

    {result_type, result_object}
  end

  @spec get_handler(atom) :: function
  defp get_handler(:token_request), do: &ClientAuthHandler.handle_token_request/2


end
