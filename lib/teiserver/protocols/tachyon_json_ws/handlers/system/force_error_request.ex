defmodule Teiserver.Tachyon.Handlers.System.ForceErrorRequest do
  @moduledoc """

  """

  alias Teiserver.Data.Types, as: T

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "force_error" => &execute/3
    }
  end

  @spec execute(T.tachyon_conn(), map, map) ::
          {{T.tachyon_command(), T.tachyon_object()}, T.tachyon_conn()}
  def execute(conn, %{"command" => command}, _meta) do
    {{command, %{}}, conn}
  end

  def execute(_conn, _object, _meta) do
    raise "Forced error"

    {{"force_error", %{}}, %{}}
  end
end
