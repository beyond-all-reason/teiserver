defmodule Teiserver.Messaging do
  @moduledoc false
  alias Teiserver.Messaging.Message
  alias Teiserver.Party
  alias Teiserver.Player.Session
  alias Teiserver.TachyonLobby

  @type message :: Message.t()
  @type entity :: Message.entity()

  @spec new(String.t(), entity(), non_neg_integer()) :: message()
  defdelegate new(message, source, marker), to: Message

  @spec send(message(), entity()) :: :ok | {:error, :invalid_recipient}
  def send(message, {:player, player_id}),
    do: Session.send_dm(player_id, message)

  def send(message, {:party, party_id, player_id}),
    do: Party.send_message(party_id, player_id, message)

  def send(message, {:lobby, lobby_id, player_id}),
    do: TachyonLobby.send_message(lobby_id, player_id, message)

  def send(_message, _entity), do: {:error, :invalid_recipient}
end
