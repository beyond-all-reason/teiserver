defmodule Teiserver.Messaging do
  alias Teiserver.Messaging.Message

  @type message :: Message.t()
  @type entity :: Message.entity()

  @spec new(String.t(), entity(), non_neg_integer()) :: message()
  defdelegate new(message, source, marker), to: Message

  @spec send(message(), entity()) :: :ok | {:error, :invalid_recipient}
  def send(message, {:player, player_id}) do
    Teiserver.Player.Session.send_dm(player_id, message)
  end

  def send(_, _), do: {:error, :invalid_recipient}
end
