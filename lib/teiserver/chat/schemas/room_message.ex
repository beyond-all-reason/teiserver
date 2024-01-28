defmodule Barserver.Chat.RoomMessage do
  use BarserverWeb, :schema

  schema "teiserver_room_messages" do
    field :content, :string
    field :chat_room, :string
    field :inserted_at, :utc_datetime
    belongs_to :user, Barserver.Account.User
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings([:content, :chat_room])

    struct
    |> cast(params, [:content, :chat_room, :inserted_at, :user_id])
    |> validate_required([:content, :chat_room, :inserted_at, :user_id])
  end

  defdelegate authorize(action, conn, params), to: Barserver.Chat.LobbyMessage
end
