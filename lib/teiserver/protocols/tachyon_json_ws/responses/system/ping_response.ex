defmodule Teiserver.Tachyon.Responses.System.PingResponse do
  @moduledoc """

  """

  alias Teiserver.Data.Types, as: T

  @spec generate(T.tachyon_conn()) ::
          {T.tachyon_command(), T.tachyon_status(), T.tachyon_object()}
  def generate(_conn) do
    object = %{

    }

    {"system/ping/response", :success, object}
  end
end
