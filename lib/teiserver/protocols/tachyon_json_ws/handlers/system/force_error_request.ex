defmodule Teiserver.Tachyon.Handlers.System.ForceErrorRequest do
  @moduledoc """

  """

  # @command_id "system/error"

  def execute(conn, _object, _meta) do
    raise "Forced error"

    response = %{
      "reason" => "An error was forced here"
    }

    {"error", response, conn}
  end
end
