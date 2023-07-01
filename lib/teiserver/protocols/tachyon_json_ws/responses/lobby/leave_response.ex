defmodule Teiserver.Tachyon.Responses.Lobby.LeaveResponse do
  @moduledoc """

  """

  alias Teiserver.Data.Types, as: T

  @spec generate(:ok) :: {T.tachyon_command, :success, T.tachyon_object} | {T.tachyon_command, T.error_pair}
  def generate(:ok) do
    {"lobby/leave/response", :success, %{

    }}
  end
end
