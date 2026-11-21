defmodule Teiserver.Messaging do
  @moduledoc false
  alias Teiserver.Account.User
  alias Teiserver.Battle.Match
  alias Teiserver.Chat
  alias Teiserver.Messaging.Message
  alias Teiserver.Party
  alias Teiserver.Player.Session
  alias Teiserver.TachyonLobby

  require Logger

  @type message :: Message.t()
  @type entity :: Message.entity()

  @spec new(String.t(), entity(), non_neg_integer()) :: message()
  defdelegate new(message, source, marker), to: Message

  @spec send(message(), entity()) :: :ok | {:error, :invalid_recipient}
  def send(message, {:player, to_id}),
    do: Session.send_dm(to_id, message)

  def send(message, {:party, party_id, from_id}),
    do: Party.send_message(party_id, from_id, message)

  def send(message, {:lobby, lobby_id, from_id}),
    do: TachyonLobby.send_message(lobby_id, from_id, message)

  def send(_message, _entity), do: {:error, :invalid_recipient}

  @spec persist_lobby_message(message(), non_neg_integer() | nil) :: :ok | {:error, String.t()}
  def persist_lobby_message(%Message{source: {:lobby, lobby_id, user_id}} = message, match_id) do
    case Chat.create_lobby_message(%{
           content: message.content,
           lobby_id: lobby_id,
           match_id: match_id,
           user_id: user_id,
           inserted_at: DateTime.utc_now()
         }) do
      {:ok, _msg} ->
        :ok

      {:error, error} ->
        Logger.error(
          "Failed to persist lobby message - Error: #{Kernel.inspect(error)} Lobby: #{lobby_id} User: #{user_id} Content: #{message.content}"
        )

        {:error, error}
    end
  end

  @spec persist_party_message(message()) :: :ok | {:error, String.t()}
  def persist_party_message(%Message{source: {:party, party_id, user_id}} = message) do
    case Chat.create_party_message(%{
           content: message.content,
           party_id: party_id,
           user_id: user_id,
           inserted_at: DateTime.utc_now()
         }) do
      {:ok, _msg} ->
        :ok

      {:error, error} ->
        Logger.error(
          "Failed to persist party message - Error: #{Kernel.inspect(error)} Party: #{party_id} User: #{user_id} Content: #{message.content}"
        )

        {:error, error}
    end
  end

  @spec persist_direct_message(message(), User.id()) :: :ok | {:error, String.t()}
  def persist_direct_message(%Message{source: {:player, from_id}} = message, to_id) do
    case Chat.create_direct_message(%{
           content: message.content,
           from_id: from_id,
           to_id: to_id,
           inserted_at: DateTime.utc_now()
         }) do
      {:ok, _msg} ->
        :ok

      {:error, error} ->
        Logger.error(
          "Failed to persist direct message - Error: #{Kernel.inspect(error)} From: #{from_id} To: #{to_id} Content: #{message.content}"
        )

        {:error, error}
    end
  end

  @spec persist_battle_message(binary(), atom(), Match.id(), User.id(), User.id() | nil) ::
          :ok | {:error, String.t()}
  def persist_battle_message(content, destination, match_id, from_id, to_id \\ nil) do
    case Chat.create_battle_message(%{
           content: content,
           destination: Atom.to_string(destination),
           match_id: match_id,
           from_id: from_id,
           to_id: to_id,
           inserted_at: DateTime.utc_now()
         }) do
      {:ok, _msg} ->
        :ok

      {:error, error} ->
        Logger.error(
          "Failed to persist battle message - Error: #{Kernel.inspect(error)} Match: #{match_id} User: #{from_id} Content: #{content}"
        )

        {:error, error}
    end
  end
end
