defmodule Teiserver.Tachyon.Responses.Lobby.UpdateStatusResponse do
  @moduledoc """

  """

  alias Teiserver.Data.Types, as: T

  @spec generate({:error, String.t()} | T.lobby()) :: {T.tachyon_command(), T.tachyon_object()}
  def generate(:ok) do
    {"lobby/updateStatus/response", :success, %{}}
  end
end
