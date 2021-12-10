defmodule Central.Communication.ChatMembership do
  @moduledoc false
  use CentralWeb, :schema

  @primary_key false
  schema "communication_chat_memberships" do
    field :role, :string
    field :last_seen, :utc_datetime

    belongs_to :user, Central.Account.User, primary_key: true
    belongs_to :chat_room, Central.Communication.ChatRoom, primary_key: true

    timestamps()
  end

  @doc false
  def changeset(chat, attrs) do
    chat
    |> cast(attrs, [:role, :user_id, :chat_room_id, :last_seen])
    |> validate_required([:user_id, :chat_room_id, :last_seen])
  end
end
