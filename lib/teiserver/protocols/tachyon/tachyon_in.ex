defmodule Teiserver.Protocols.TachyonIn do
  require Logger
  alias Teiserver.Protocols.Tachyon
  import Teiserver.Protocols.TachyonOut, only: [reply: 4]

  @spec handle(String.t(), map) :: map
  def handle("", state), do: state
  def handle("\r\n", state), do: state

  def handle(raw_data, state) do
    new_state =
      case Tachyon.decode(raw_data) do
        {:ok, data} ->
          do_handle(data["cmd"], data, state)

        {:error, error_type} ->
          reply(:misc, :error, %{location: "decode", error: error_type}, state)
          state
      end

    %{new_state | last_msg: System.system_time(:second)}
  end

  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  defp do_handle("c.system.ping", cmd, state) do
    reply(:misc, :pong, cmd, state)
    state
  end
end
