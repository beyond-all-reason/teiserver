defmodule Teiserver.Protocols.TachyonOut do
  require Logger
  alias Teiserver.Protocols.Tachyon
  alias Teiserver.Protocols.Tachyon.{MiscOut}

  @spec reply(atom(), atom(), Map.t(), Map.t()) :: Map.t()
  def reply(namespace, reply_cmd, data, state) do
    msg =
      case namespace do
        :misc -> MiscOut.do_reply(reply_cmd, data)
      end
      |> add_msg_id(data)

    if state.extra_logging do
      Logger.info(
        "--> #{state.username}: #{
          Tachyon.format_log(msg)
        }"
      )
    end

    _send(msg, state)
    state
  end

  @spec add_msg_id(Map.t(), Map.t()) :: Map.t()
  defp add_msg_id(resp, original_data) do
    if original_data["msg_id"] do
      Map.put(resp, :msg_id, original_data["msg_id"])
    else
      resp
    end
  end

  # This sends a message to the self to send out a message
  @spec _send(Map.t(), Map.t()) :: any()
  defp _send(msg, state) do
    _send(msg, state.socket, state.transport)
  end

  defp _send(msg, socket, transport) do
    encoded_msg = Tachyon.encode(msg)
    transport.send(socket, encoded_msg)
  end
end
