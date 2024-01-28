defmodule Barserver.Tachyon.Responses.Communication.ReceivedDirectMessageResponse do
  @moduledoc """

  """

  alias Barserver.Data.Types, as: T

  @spec generate(atom) :: {T.tachyon_command(), T.tachyon_status(), T.tachyon_object()}
  def generate(%{message_content: content, sender_id: sender_id}) do
    content =
      if is_list(content) do
        Enum.join(content, "\n")
      else
        content
      end

    resp = %{
      content: content,
      sender_id: sender_id
    }

    {"communication/receivedDirectMessage/response", :success, resp}
  end
end
