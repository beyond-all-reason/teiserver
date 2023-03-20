defmodule Teiserver.Tachyon.Handlers.System.ErrorRequest do
  @moduledoc """

  """

  # @command_id "system/error"

  def execute(conn, _object, _meta) do
    resp = %{
      "error" => "Error goes here"
    }

    {resp, conn}
  end
end
