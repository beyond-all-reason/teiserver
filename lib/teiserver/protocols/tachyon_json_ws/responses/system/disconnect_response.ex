defmodule Barserver.Tachyon.Responses.System.DisconnectResponse do
  @moduledoc """
  Error response - https://github.com/beyond-all-reason/tachyon/blob/master/src/schema/system.ts
  """

  alias Barserver.Data.Types, as: T

  @spec generate(String.t()) :: {T.tachyon_command(), T.tachyon_object()}
  def generate(_reason) do
    {"disconnect", :success, nil}
  end
end
