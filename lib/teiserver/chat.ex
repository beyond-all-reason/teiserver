defmodule Teiserver.Chat do
  @moduledoc false

  alias Phoenix.PubSub
  alias Teiserver.Account
  alias Teiserver.Account.Auth
  alias Teiserver.Battle
  alias Teiserver.Chat.DirectMessage
  alias Teiserver.Chat.DirectMessageLib
  alias Teiserver.Chat.LobbyMessage
  alias Teiserver.Chat.LobbyMessageLib
  alias Teiserver.Chat.PartyMessage
  alias Teiserver.Chat.PartyMessageLib
  alias Teiserver.Chat.RoomMessage
  alias Teiserver.Chat.RoomMessageLib
  alias Teiserver.Chat.WordLib
  alias Teiserver.Client
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Repo
  import Ecto.Query, warn: false

  @spec room_message_query(List.t()) :: Ecto.Query.t()
  def room_message_query(args) do
    room_message_query(nil, args)
  end

  @spec room_message_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def room_message_query(id, args) do
    RoomMessageLib.query_room_messages()
    |> RoomMessageLib.search(%{id: id})
    |> RoomMessageLib.search(args[:search])
    |> RoomMessageLib.preload(args[:preload])
    |> RoomMessageLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> QueryHelpers.offset_query(args[:offset] || 0)
  end

  @doc """
  Returns the list of room_messages.

  ## Examples

      iex> list_room_messages()
      [%RoomMessage{}, ...]

  """
  @spec list_room_messages(List.t()) :: List.t()
  def list_room_messages(args \\ []) do
    room_message_query(args)
    |> Repo.all()
  end

  @doc """
  Gets a single room_message.

  Raises `Ecto.NoResultsError` if the RoomMessage does not exist.

  ## Examples

      iex> get_room_message!(123)
      %RoomMessage{}

      iex> get_room_message!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_room_message!(Integer.t() | List.t()) :: RoomMessage.t()
  @spec get_room_message!(Integer.t(), List.t()) :: RoomMessage.t()
  def get_room_message!(id) when not is_list(id) do
    room_message_query(id, [])
    |> Repo.one!()
  end

  def get_room_message!(args) do
    room_message_query(nil, args)
    |> Repo.one!()
  end

  def get_room_message!(id, args) do
    room_message_query(id, args)
    |> Repo.one!()
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single room_message.

  # Returns `nil` if the RoomMessage does not exist.

  # ## Examples

  #     iex> get_room_message(123)
  #     %RoomMessage{}

  #     iex> get_room_message(456)
  #     nil

  # """
  # def get_room_message(id, args \\ []) when not is_list(id) do
  #   room_message_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a room_message.

  ## Examples

      iex> create_room_message(%{field: value})
      {:ok, %RoomMessage{}}

      iex> create_room_message(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_room_message(map()) :: {:ok, RoomMessage.t()} | {:error, Ecto.Changeset.t()}
  def create_room_message(attrs \\ %{}) do
    %RoomMessage{}
    |> RoomMessage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a room_message.

  ## Examples

      iex> update_room_message(room_message, %{field: new_value})
      {:ok, %RoomMessage{}}

      iex> update_room_message(room_message, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_room_message(RoomMessage.t(), map()) ::
          {:ok, RoomMessage.t()} | {:error, Ecto.Changeset.t()}
  def update_room_message(%RoomMessage{} = room_message, attrs) do
    room_message
    |> RoomMessage.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a RoomMessage.

  ## Examples

      iex> delete_room_message(room_message)
      {:ok, %RoomMessage{}}

      iex> delete_room_message(room_message)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_room_message(RoomMessage.t()) ::
          {:ok, RoomMessage.t()} | {:error, Ecto.Changeset.t()}
  def delete_room_message(%RoomMessage{} = room_message) do
    Repo.delete(room_message)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking room_message changes.

  ## Examples

      iex> change_room_message(room_message)
      %Ecto.Changeset{source: %RoomMessage{}}

  """
  @spec change_room_message(RoomMessage.t()) :: Ecto.Changeset.t()
  def change_room_message(%RoomMessage{} = room_message) do
    RoomMessage.changeset(room_message, %{})
  end

  @spec lobby_message_query(List.t()) :: Ecto.Query.t()
  def lobby_message_query(args) do
    lobby_message_query(nil, args)
  end

  @spec lobby_message_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def lobby_message_query(id, args) do
    LobbyMessageLib.query_lobby_messages()
    |> LobbyMessageLib.search(%{id: id})
    |> LobbyMessageLib.search(args[:search])
    |> LobbyMessageLib.preload(args[:preload])
    |> LobbyMessageLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> QueryHelpers.offset_query(args[:offset] || 0)
  end

  @doc """
  Returns the list of lobby_messages.

  ## Examples

      iex> list_lobby_messages()
      [%LobbyMessage{}, ...]

  """
  @spec list_lobby_messages(List.t()) :: List.t()
  def list_lobby_messages(args \\ []) do
    lobby_message_query(args)
    |> Repo.all()
  end

  @doc """
  Gets a single lobby_message.

  Raises `Ecto.NoResultsError` if the LobbyMessage does not exist.

  ## Examples

      iex> get_lobby_message!(123)
      %LobbyMessage{}

      iex> get_lobby_message!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_lobby_message!(Integer.t() | List.t()) :: LobbyMessage.t()
  @spec get_lobby_message!(Integer.t(), List.t()) :: LobbyMessage.t()
  def get_lobby_message!(id) when not is_list(id) do
    lobby_message_query(id, [])
    |> Repo.one!()
  end

  def get_lobby_message!(args) do
    lobby_message_query(nil, args)
    |> Repo.one!()
  end

  def get_lobby_message!(id, args) do
    lobby_message_query(id, args)
    |> Repo.one!()
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single lobby_message.

  # Returns `nil` if the LobbyMessage does not exist.

  # ## Examples

  #     iex> get_lobby_message(123)
  #     %LobbyMessage{}

  #     iex> get_lobby_message(456)
  #     nil

  # """
  # def get_lobby_message(id, args \\ []) when not is_list(id) do
  #   lobby_message_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a lobby_message.

  ## Examples

      iex> create_lobby_message(%{field: value})
      {:ok, %LobbyMessage{}}

      iex> create_lobby_message(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_lobby_message(map()) :: {:ok, LobbyMessage.t()} | {:error, Ecto.Changeset.t()}
  def create_lobby_message(attrs \\ %{}) do
    %LobbyMessage{}
    |> LobbyMessage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a lobby_message.

  ## Examples

      iex> update_lobby_message(lobby_message, %{field: new_value})
      {:ok, %LobbyMessage{}}

      iex> update_lobby_message(lobby_message, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_lobby_message(LobbyMessage.t(), map()) ::
          {:ok, LobbyMessage.t()} | {:error, Ecto.Changeset.t()}
  def update_lobby_message(%LobbyMessage{} = lobby_message, attrs) do
    lobby_message
    |> LobbyMessage.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a LobbyMessage.

  ## Examples

      iex> delete_lobby_message(lobby_message)
      {:ok, %LobbyMessage{}}

      iex> delete_lobby_message(lobby_message)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_lobby_message(LobbyMessage.t()) ::
          {:ok, LobbyMessage.t()} | {:error, Ecto.Changeset.t()}
  def delete_lobby_message(%LobbyMessage{} = lobby_message) do
    Repo.delete(lobby_message)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking lobby_message changes.

  ## Examples

      iex> change_lobby_message(lobby_message)
      %Ecto.Changeset{source: %LobbyMessage{}}

  """
  @spec change_lobby_message(LobbyMessage.t()) :: Ecto.Changeset.t()
  def change_lobby_message(%LobbyMessage{} = lobby_message) do
    LobbyMessage.changeset(lobby_message, %{})
  end

  @spec party_message_query(List.t()) :: Ecto.Query.t()
  def party_message_query(args) do
    party_message_query(nil, args)
  end

  @spec party_message_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def party_message_query(id, args) do
    PartyMessageLib.query_party_messages()
    |> PartyMessageLib.search(%{id: id})
    |> PartyMessageLib.search(args[:search])
    |> PartyMessageLib.preload(args[:preload])
    |> PartyMessageLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> QueryHelpers.offset_query(args[:offset] || 0)
  end

  @doc """
  Returns the list of party_messages.

  ## Examples

      iex> list_party_messages()
      [%PartyMessage{}, ...]

  """
  @spec list_party_messages(List.t()) :: List.t()
  def list_party_messages(args \\ []) do
    party_message_query(args)
    |> Repo.all()
  end

  @doc """
  Gets a single party_message.

  Raises `Ecto.NoResultsError` if the PartyMessage does not exist.

  ## Examples

      iex> get_party_message!(123)
      %PartyMessage{}

      iex> get_party_message!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_party_message!(Integer.t() | List.t()) :: PartyMessage.t()
  @spec get_party_message!(Integer.t(), List.t()) :: PartyMessage.t()
  def get_party_message!(id) when not is_list(id) do
    party_message_query(id, [])
    |> Repo.one!()
  end

  def get_party_message!(args) do
    party_message_query(nil, args)
    |> Repo.one!()
  end

  def get_party_message!(id, args) do
    party_message_query(id, args)
    |> Repo.one!()
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single party_message.

  # Returns `nil` if the PartyMessage does not exist.

  # ## Examples

  #     iex> get_party_message(123)
  #     %PartyMessage{}

  #     iex> get_party_message(456)
  #     nil

  # """
  # def get_party_message(id, args \\ []) when not is_list(id) do
  #   party_message_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a party_message.

  ## Examples

      iex> create_party_message(%{field: value})
      {:ok, %PartyMessage{}}

      iex> create_party_message(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_party_message(map()) :: {:ok, PartyMessage.t()} | {:error, Ecto.Changeset.t()}
  def create_party_message(attrs \\ %{}) do
    %PartyMessage{}
    |> PartyMessage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a party_message.

  ## Examples

      iex> update_party_message(party_message, %{field: new_value})
      {:ok, %PartyMessage{}}

      iex> update_party_message(party_message, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_party_message(PartyMessage.t(), map()) ::
          {:ok, PartyMessage.t()} | {:error, Ecto.Changeset.t()}
  def update_party_message(%PartyMessage{} = party_message, attrs) do
    party_message
    |> PartyMessage.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a PartyMessage.

  ## Examples

      iex> delete_party_message(party_message)
      {:ok, %PartyMessage{}}

      iex> delete_party_message(party_message)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_party_message(PartyMessage.t()) ::
          {:ok, PartyMessage.t()} | {:error, Ecto.Changeset.t()}
  def delete_party_message(%PartyMessage{} = party_message) do
    Repo.delete(party_message)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking party_message changes.

  ## Examples

      iex> change_party_message(party_message)
      %Ecto.Changeset{source: %PartyMessage{}}

  """
  @spec change_party_message(PartyMessage.t()) :: Ecto.Changeset.t()
  def change_party_message(%PartyMessage{} = party_message) do
    PartyMessage.changeset(party_message, %{})
  end

  def direct_message_query(args) do
    DirectMessageLib.query_direct_messages()
    |> DirectMessageLib.search(args[:search])
    |> DirectMessageLib.preload(args[:preload])
    |> DirectMessageLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> QueryHelpers.offset_query(args[:offset] || 0)
  end

  @doc """
  Returns the list of direct_messages.

  ## Examples

      iex> list_direct_messages()
      [%DirectMessage{}, ...]

  """
  @spec list_direct_messages(list) :: list
  def list_direct_messages(args \\ []) do
    args
    |> direct_message_query()
    |> Repo.all()
  end

  @doc """
  Gets a single direct_message.

  Raises `Ecto.NoResultsError` if the DirectMessage does not exist.

  ## Examples

      iex> get_direct_message!(123)
      %DirectMessage{}

      iex> get_direct_message!(456)
      ** (Ecto.NoResultsError)

  """
  def get_direct_message!(id), do: Repo.get!(DirectMessage, id)

  def get_direct_message!(id, args) do
    args = args ++ [id: id]

    args
    |> direct_message_query()
    |> Repo.one!()
  end

  @doc """
  Creates a direct_message.

  ## Examples

      iex> create_direct_message(%{field: value})
      {:ok, %DirectMessage{}}

      iex> create_direct_message(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_direct_message(attrs \\ %{}) do
    %DirectMessage{}
    |> DirectMessage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a direct_message.

  ## Examples

      iex> update_direct_message(direct_message, %{field: new_value})
      {:ok, %DirectMessage{}}

      iex> update_direct_message(direct_message, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_direct_message(%DirectMessage{} = direct_message, attrs) do
    direct_message
    |> DirectMessage.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a direct_message.

  ## Examples

      iex> delete_direct_message(direct_message)
      {:ok, %DirectMessage{}}

      iex> delete_direct_message(direct_message)
      {:error, %Ecto.Changeset{}}

  """
  def delete_direct_message(%DirectMessage{} = direct_message) do
    Repo.delete(direct_message)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking direct_message changes.

  ## Examples

      iex> change_direct_message(direct_message)
      %Ecto.Changeset{data: %DirectMessage{}}

  """
  def change_direct_message(%DirectMessage{} = direct_message, attrs \\ %{}) do
    DirectMessage.changeset(direct_message, attrs)
  end

  @spec send_direct_message(User.id(), User.id(), String.t()) :: :ok
  def send_direct_message(from_id, to_id, "!joinas" <> s),
    do: send_direct_message(from_id, to_id, "!cv joinas" <> s)

  @spec send_direct_message(User.id(), User.id(), list) :: :ok
  def send_direct_message(sender_id, to_id, message_parts) when is_list(message_parts) do
    msg_str = Enum.join(message_parts, "\n")

    sender_bot? = Auth.is_bot?(sender_id)
    recipient_bot? = Auth.is_bot?(to_id)

    allowed =
      cond do
        sender_bot? == false and WordLib.blacklisted_phrase?(msg_str) -> false
        Account.restricted?(sender_id, ["All chat", "Direct chat"]) -> false
        true -> true
      end

    if allowed do
      save_message =
        cond do
          sender_bot? -> false
          recipient_bot? and not persist_bot_dm?(msg_str) -> false
          true -> true
        end

      # Persist message but not if a JSONRPC being sent to a bot or
      # if the message was from a bot
      if save_message do
        create_direct_message(%{
          to_id: to_id,
          from_id: sender_id,
          content: msg_str,
          inserted_at: DateTime.utc_now(),
          delivered: true
        })
      end

      PubSub.broadcast(
        Teiserver.PubSub,
        "legacy_user_updates:#{to_id}",
        {:direct_message, sender_id, message_parts}
      )

      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_client_messages:#{to_id}",
        %{
          channel: "teiserver_client_messages:#{to_id}",
          event: :received_direct_message,
          sender_id: sender_id,
          message_content: message_parts
        }
      )
    end

    :ok
  end

  def send_direct_message(_from_id, _to_id, nil), do: :ok

  def send_direct_message(from_id, to_id, message) do
    # Replace SPADS command (starting with !) with lowercase
    # version to prevent bypassing with capitalised command names
    # Ignore !# bot commands like !#JSONRPC
    # Allow voting for joinas if there are AIs in the
    # recipient's lobby, otherwise alias to spec
    message =
      if String.starts_with?(message, "!") and !String.starts_with?(message, "!#") do
        command_parts =
          message
          |> String.trim()
          |> String.downcase()
          |> String.split()

        case command_parts do
          ["!cv", "joinas" | _rest] ->
            has_ai =
              case Client.get_client_by_id(to_id) do
                %{lobby_id: lobby_id} when not is_nil(lobby_id) ->
                  Battle.get_bots(lobby_id) |> Enum.any?()

                _client ->
                  false
              end

            if has_ai, do: message, else: "!cv joinas spec"

          ["!callvote", "joinas" | _rest] ->
            has_ai =
              case Client.get_client_by_id(to_id) do
                %{lobby_id: lobby_id} when not is_nil(lobby_id) ->
                  Battle.get_bots(lobby_id) |> Enum.any?()

                _client ->
                  false
              end

            if has_ai, do: message, else: "!callvote joinas spec"

          ["!joinas" | _rest] ->
            "!joinas spec"

          _other ->
            message
        end
      else
        message
      end

    send_direct_message(from_id, to_id, [message])
  end

  defp persist_bot_dm?(message) do
    not String.starts_with?(message, "!#")
  end
end
