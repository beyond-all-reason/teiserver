defmodule Teiserver.Tachyon.Responses.System.ErrorResponse do
  @moduledoc """
  Error response - https://github.com/beyond-all-reason/tachyon/blob/master/src/schema/system.ts
  """

  alias Teiserver.Data.Types, as: T

  @spec execute(String.t()) :: {T.tachyon_command(), T.tachyon_object()}
  def execute(reason) do
    object = %{
      "reason" => reason
    }

    {"system/error/response", object}
  end
end
