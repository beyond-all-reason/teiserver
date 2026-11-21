defmodule Teiserver.Chat do
  @moduledoc false

  alias Phoenix.PubSub
  alias Teiserver.Account
  alias Teiserver.Account.Auth
  alias Teiserver.Battle
  alias Teiserver.Chat.BattleMessage
  alias Teiserver.Chat.DirectMessage
  alias Teiserver.Chat.LobbyMessage
  alias Teiserver.Chat.PartyMessage
  alias Teiserver.Chat.SpringDirectMessage
  alias Teiserver.Chat.SpringDirectMessageLib
  alias Teiserver.Chat.SpringLobbyMessage
  alias Teiserver.Chat.SpringLobbyMessageLib
  alias Teiserver.Chat.SpringRoomMessage
  alias Teiserver.Chat.SpringRoomMessageLib
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
    SpringRoomMessageLib.query_spring_room_messages()
    |> SpringRoomMessageLib.search(%{id: id})
    |> SpringRoomMessageLib.search(args[:search])
    |> SpringRoomMessageLib.preload(args[:preload])
    |> SpringRoomMessageLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> QueryHelpers.offset_query(args[:offset] || 0)
  end

  @doc """
  Returns the list of room_messages.

  ## Examples

      iex> list_room_messages()
      [%SpringRoomMessage{}, ...]

  """
  @spec list_room_messages(List.t()) :: List.t()
  def list_room_messages(args \\ []) do
    room_message_query(args)
    |> Repo.all()
  end

  @doc """
  Gets a single room_message.

  Raises `Ecto.NoResultsError` if the SpringRoomMessage does not exist.

  ## Examples

      iex> get_room_message!(123)
      %SpringRoomMessage{}

      iex> get_room_message!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_room_message!(Integer.t() | List.t()) :: SpringRoomMessage.t()
  @spec get_room_message!(Integer.t(), List.t()) :: SpringRoomMessage.t()
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

  # Returns `nil` if the SpringRoomMessage does not exist.

  # ## Examples

  #     iex> get_room_message(123)
  #     %SpringRoomMessage{}

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
      {:ok, %SpringRoomMessage{}}

      iex> create_room_message(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_room_message(map()) :: {:ok, SpringRoomMessage.t()} | {:error, Ecto.Changeset.t()}
  def create_room_message(attrs \\ %{}) do
    %SpringRoomMessage{}
    |> SpringRoomMessage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a room_message.

  ## Examples

      iex> update_room_message(room_message, %{field: new_value})
      {:ok, %SpringRoomMessage{}}

      iex> update_room_message(room_message, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_room_message(SpringRoomMessage.t(), map()) ::
          {:ok, SpringRoomMessage.t()} | {:error, Ecto.Changeset.t()}
  def update_room_message(%SpringRoomMessage{} = room_message, attrs) do
    room_message
    |> SpringRoomMessage.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a SpringRoomMessage.

  ## Examples

      iex> delete_room_message(room_message)
      {:ok, %SpringRoomMessage{}}

      iex> delete_room_message(room_message)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_room_message(SpringRoomMessage.t()) ::
          {:ok, SpringRoomMessage.t()} | {:error, Ecto.Changeset.t()}
  def delete_room_message(%SpringRoomMessage{} = room_message) do
    Repo.delete(room_message)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking room_message changes.

  ## Examples

      iex> change_room_message(room_message)
      %Ecto.Changeset{source: %SpringRoomMessage{}}

  """
  @spec change_room_message(SpringRoomMessage.t()) :: Ecto.Changeset.t()
  def change_room_message(%SpringRoomMessage{} = room_message) do
    SpringRoomMessage.changeset(room_message, %{})
  end

  @spec spring_lobby_message_query(List.t()) :: Ecto.Query.t()
  def spring_lobby_message_query(args) do
    spring_lobby_message_query(nil, args)
  end

  @spec spring_lobby_message_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def spring_lobby_message_query(id, args) do
    SpringLobbyMessageLib.query_spring_lobby_messages()
    |> SpringLobbyMessageLib.search(%{id: id})
    |> SpringLobbyMessageLib.search(args[:search])
    |> SpringLobbyMessageLib.preload(args[:preload])
    |> SpringLobbyMessageLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> QueryHelpers.offset_query(args[:offset] || 0)
  end

  @doc """
  Returns the list of lobby_messages.

  ## Examples

      iex> list_spring_lobby_messages()
      [%SpringLobbyMessage{}, ...]

  """
  @spec list_spring_lobby_messages(List.t()) :: List.t()
  def list_spring_lobby_messages(args \\ []) do
    spring_lobby_message_query(args)
    |> Repo.all()
  end

  @doc """
  Gets a single lobby_message.

  Raises `Ecto.NoResultsError` if the SpringLobbyMessage does not exist.

  ## Examples

      iex> get_spring_lobby_message!(123)
      %SpringLobbyMessage{}

      iex> get_spring_lobby_message!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_spring_lobby_message!(Integer.t() | List.t()) :: SpringLobbyMessage.t()
  @spec get_spring_lobby_message!(Integer.t(), List.t()) :: SpringLobbyMessage.t()
  def get_spring_lobby_message!(id) when not is_list(id) do
    spring_lobby_message_query(id, [])
    |> Repo.one!()
  end

  def get_spring_lobby_message!(args) do
    spring_lobby_message_query(nil, args)
    |> Repo.one!()
  end

  def get_spring_lobby_message!(id, args) do
    spring_lobby_message_query(id, args)
    |> Repo.one!()
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single lobby_message.

  # Returns `nil` if the SpringLobbyMessage does not exist.

  # ## Examples

  #     iex> get_spring_lobby_message(123)
  #     %SpringLobbyMessage{}

  #     iex> get_spring_lobby_message(456)
  #     nil

  # """
  # def get_spring_lobby_message(id, args \\ []) when not is_list(id) do
  #   spring_lobby_message_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a lobby_message.

  ## Examples

      iex> create_spring_lobby_message(%{field: value})
      {:ok, %SpringLobbyMessage{}}

      iex> create_spring_lobby_message(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_spring_lobby_message(map()) ::
          {:ok, SpringLobbyMessage.t()} | {:error, Ecto.Changeset.t()}
  def create_spring_lobby_message(attrs \\ %{}) do
    %SpringLobbyMessage{}
    |> SpringLobbyMessage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a lobby_message.

  ## Examples

      iex> update_spring_lobby_message(lobby_message, %{field: new_value})
      {:ok, %SpringLobbyMessage{}}

      iex> update_spring_lobby_message(lobby_message, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_spring_lobby_message(SpringLobbyMessage.t(), map()) ::
          {:ok, SpringLobbyMessage.t()} | {:error, Ecto.Changeset.t()}
  def update_spring_lobby_message(%SpringLobbyMessage{} = lobby_message, attrs) do
    lobby_message
    |> SpringLobbyMessage.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a SpringLobbyMessage.

  ## Examples

      iex> delete_spring_lobby_message(lobby_message)
      {:ok, %SpringLobbyMessage{}}

      iex> delete_spring_lobby_message(lobby_message)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_spring_lobby_message(SpringLobbyMessage.t()) ::
          {:ok, SpringLobbyMessage.t()} | {:error, Ecto.Changeset.t()}
  def delete_spring_lobby_message(%SpringLobbyMessage{} = lobby_message) do
    Repo.delete(lobby_message)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking lobby_message changes.

  ## Examples

      iex> change_spring_lobby_message(lobby_message)
      %Ecto.Changeset{source: %SpringLobbyMessage{}}

  """
  @spec change_spring_lobby_message(SpringLobbyMessage.t()) :: Ecto.Changeset.t()
  def change_spring_lobby_message(%SpringLobbyMessage{} = lobby_message) do
    SpringLobbyMessage.changeset(lobby_message, %{})
  end

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
  Creates a battle_message.

  ## Examples

      iex> create_battle_message(%{field: value})
      {:ok, %BattleMessage{}}

      iex> create_battle_message(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_battle_message(map()) :: {:ok, BattleMessage.t()} | {:error, Ecto.Changeset.t()}
  def create_battle_message(attrs \\ %{}) do
    %BattleMessage{}
    |> BattleMessage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a lobby message sent through Tachyon.
  """
  @spec create_lobby_message(map()) ::
          {:ok, LobbyMessage.t()} | {:error, Ecto.Changeset.t()}
  def create_lobby_message(attrs) do
    %LobbyMessage{}
    |> LobbyMessage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a direct message sent through Tachyon.
  """
  @spec create_direct_message(map()) ::
          {:ok, DirectMessage.t()} | {:error, Ecto.Changeset.t()}
  def create_direct_message(attrs) do
    %DirectMessage{}
    |> DirectMessage.changeset(attrs)
    |> Repo.insert()
  end

  def spring_direct_message_query(args) do
    SpringDirectMessageLib.query_spring_direct_messages()
    |> SpringDirectMessageLib.search(args[:search])
    |> SpringDirectMessageLib.preload(args[:preload])
    |> SpringDirectMessageLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> QueryHelpers.offset_query(args[:offset] || 0)
  end

  @doc """
  Returns the list of direct_messages.

  ## Examples

      iex> list_spring_direct_messages()
      [%SpringDirectMessage{}, ...]

  """
  @spec list_spring_direct_messages(list) :: list
  def list_spring_direct_messages(args \\ []) do
    args
    |> spring_direct_message_query()
    |> Repo.all()
  end

  @doc """
  Gets a single direct_message.

  Raises `Ecto.NoResultsError` if the SpringDirectMessage does not exist.

  ## Examples

      iex> get_spring_direct_message!(123)
      %SpringDirectMessage{}

      iex> get_spring_direct_message!(456)
      ** (Ecto.NoResultsError)

  """
  def get_spring_direct_message!(id), do: Repo.get!(SpringDirectMessage, id)

  def get_spring_direct_message!(id, args) do
    args = args ++ [id: id]

    args
    |> spring_direct_message_query()
    |> Repo.one!()
  end

  @doc """
  Creates a direct_message.

  ## Examples

      iex> create_spring_direct_message(%{field: value})
      {:ok, %SpringDirectMessage{}}

      iex> create_spring_direct_message(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_spring_direct_message(attrs \\ %{}) do
    %SpringDirectMessage{}
    |> SpringDirectMessage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a direct_message.

  ## Examples

      iex> update_spring_direct_message(direct_message, %{field: new_value})
      {:ok, %SpringDirectMessage{}}

      iex> update_spring_direct_message(direct_message, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_spring_direct_message(%SpringDirectMessage{} = direct_message, attrs) do
    direct_message
    |> SpringDirectMessage.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a direct_message.

  ## Examples

      iex> delete_spring_direct_message(direct_message)
      {:ok, %SpringDirectMessage{}}

      iex> delete_spring_direct_message(direct_message)
      {:error, %Ecto.Changeset{}}

  """
  def delete_spring_direct_message(%SpringDirectMessage{} = direct_message) do
    Repo.delete(direct_message)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking direct_message changes.

  ## Examples

      iex> change_spring_direct_message(direct_message)
      %Ecto.Changeset{data: %SpringDirectMessage{}}

  """
  def change_spring_direct_message(%SpringDirectMessage{} = direct_message, attrs \\ %{}) do
    SpringDirectMessage.changeset(direct_message, attrs)
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
        create_spring_direct_message(%{
          to_id: to_id,
          from_id: sender_id,
          content: msg_str,
          inserted_at: DateTime.utc_now()
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
