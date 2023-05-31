defmodule Teiserver.Tachyon.Responses.Communication.SendDirectMessageResponse do
  @moduledoc """

  """

  alias Teiserver.Data.Types, as: T

  @spec execute(atom) :: {T.tachyon_command(), T.tachyon_status(), T.tachyon_object()}
  def execute(:ok) do
    {"communication/sendDirectMessage/response", :success, %{}}
  end
end
