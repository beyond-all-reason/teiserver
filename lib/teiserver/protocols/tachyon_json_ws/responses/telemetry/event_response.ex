defmodule Barserver.Tachyon.Responses.Telemetry.EventResponse do
  @moduledoc """

  """

  alias Barserver.Data.Types, as: T

  @spec generate(atom) :: {T.tachyon_command(), T.tachyon_status(), T.tachyon_object()}
  def generate(:ok) do
    {"telemetry/event/response", :success, %{}}
  end
end
