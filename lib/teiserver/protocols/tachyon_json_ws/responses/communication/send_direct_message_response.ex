defmodule Teiserver.Tachyon.Responses.Communication.SendDirectMessageResponse do
  @moduledoc """

  """

  alias Teiserver.Data.Types, as: T

  @spec generate(atom) :: {T.tachyon_command(), T.tachyon_status(), T.tachyon_object()}
  def generate(:ok) do
    {"communication/sendDirectMessage/response", :success, %{}}
  end
end
