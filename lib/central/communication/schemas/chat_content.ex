defmodule Central.Communication.ChatContent do
  use CentralWeb, :schema

  schema "communication_chat_contents" do
    field :metadata, :map
    field :content, :string

    belongs_to :user, Central.Account.User
    belongs_to :chat_room, Central.Communication.ChatRoom

    timestamps()
  end

  @doc false
  def changeset(chat, attrs) do
    chat
    |> cast(attrs, [:content, :user_id, :chat_room_id, :metadata])
    |> validate_required([:content, :user_id, :chat_room_id, :metadata])
  end
end
