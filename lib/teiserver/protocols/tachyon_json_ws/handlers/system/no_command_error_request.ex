defmodule Teiserver.Tachyon.Handlers.System.NoCommandErrorRequest do
  @moduledoc """

  """

  alias Teiserver.Data.Types, as: T
  alias Teiserver.Tachyon.Responses.System.ErrorResponse

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "no_command" => &execute/3
    }
  end

  @spec execute(T.tachyon_conn(), T.tachyon_object(), map) :: {T.tachyon_response(), T.tachyon_conn()}
  def execute(conn, _object, %{"command" => command} = _meta) do
    response = ErrorResponse.generate("No command of '#{command}'")

    {response, conn}
  end

  def execute(conn, _object, _meta) do
    response = ErrorResponse.generate("No command supplied")

    {response, conn}
  end
end
