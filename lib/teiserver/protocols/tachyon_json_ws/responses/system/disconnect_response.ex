defmodule Teiserver.Tachyon.Responses.System.DisconnectResponse do
  @moduledoc """
  Error response - https://github.com/beyond-all-reason/tachyon/blob/master/src/schema/system.ts
  """

  alias Teiserver.Data.Types, as: T

  @spec execute(String.t()) :: {T.tachyon_command(), T.tachyon_object()}
  def execute(reason) do
    {"disconnect", :success, nil}
  end
end
