defmodule Teiserver.Moderation.LobbyLog do
  @moduledoc false

  use TeiserverWeb, :schema

  typed_schema "lobby_logs" do
    field :lobby_id, Ecto.UUID

    field :event_type, Ecto.Enum,
      values: [
        # Lobby
        :create_lobby,
        :close_lobby,
        :join_lobby,
        :leave_lobby,
        :cast_vote,
        :battle_start,
        :battle_end,
        # Teams
        :join_spectators,
        :join_team,
        # Moderation
        :kickban,
        # Bots
        :add_bot,
        :remove_bot,
        # Boss
        :appoint_boss,
        :unboss
      ]

    field :details, :map

    belongs_to :user, Teiserver.Account.User
    belongs_to :target, Teiserver.Account.User

    timestamps(updated_at: false, type: :utc_datetime_usec)
  end

  def event_types, do: Ecto.Enum.values(__MODULE__, :event_type)

  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:lobby_id, :event_type, :details, :user_id, :target_id, :inserted_at])
    |> validate_required([:lobby_id, :event_type])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:target_id)
  end
end
