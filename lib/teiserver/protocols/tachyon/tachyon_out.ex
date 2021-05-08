defmodule Teiserver.Protocols.TachyonOut do
  require Logger
  alias Teiserver.Protocols.Tachyon
  alias Teiserver.Protocols.Tachyon.{AuthOut, BattleOut, SystemOut}

  @spec reply(atom(), atom(), Map.t(), Map.t()) :: Map.t()

  # Stuff we have to use because spring used it
  # TODO: Remove these with Spring
  def reply(:login_end, nil, nil, state), do: state


  def reply(namespace, reply_cmd, data, state) do
    msg =
      case namespace do
        :auth -> AuthOut.do_reply(reply_cmd, data)
        :battle -> BattleOut.do_reply(reply_cmd, data)
        :system -> SystemOut.do_reply(reply_cmd, data)
      end
      |> add_msg_id(state)

    if state.extra_logging do
      Logger.info("--> #{state.username}: #{Tachyon.format_log(msg)}")
    end

    _send(msg, state)
    state
  end

  @spec add_msg_id(Map.t(), Map.t()) :: Map.t()
  defp add_msg_id(resp, state) do
    if state.msg_id do
      Map.put(resp, :msg_id, state.msg_id)
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
