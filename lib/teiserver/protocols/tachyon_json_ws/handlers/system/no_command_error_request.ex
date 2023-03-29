defmodule Teiserver.Tachyon.Handlers.System.NoCommandErrorRequest do
  @moduledoc """

  """

  # @command_id "system/error"

  @spec dispatch_handlers :: map()
  def dispatch_handlers() do
    %{
      "no_command" => &execute/3
    }
  end

  def execute(conn, _object, %{"command" => command} = _meta) do
    response = %{
      "reason" => "No command of '#{command}'"
    }

    {"error", response, conn}
  end

  def execute(conn, _object, _meta) do
    response = %{
      "reason" => "No command supplied"
    }

    {"error", response, conn}
  end
end
