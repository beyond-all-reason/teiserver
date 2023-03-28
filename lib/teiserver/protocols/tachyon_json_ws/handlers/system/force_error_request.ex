defmodule Teiserver.Tachyon.Handlers.System.ForceErrorRequest do
  @moduledoc """

  """

  # @command_id "system/error"

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "force_error" => &execute/3
    }
  end

  def execute(conn, _object, _meta) do
    raise "Forced error"

    response = %{
      "reason" => "An error was forced here"
    }

    {"error", response, conn}
  end
end
