defmodule Barserver.Tachyon.Responses.Lobby.UpdateStatusResponse do
  @moduledoc """

  """

  alias Barserver.Data.Types, as: T

  @spec generate() ::
          {T.tachyon_command(), :success, T.tachyon_object()}
          | {T.tachyon_command(), T.error_pair()}
  def generate() do
    {"lobby/updateStatus/response", :success, %{}}
  end
end
