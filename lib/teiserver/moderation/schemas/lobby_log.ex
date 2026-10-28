defmodule Teiserver.Moderation.LobbyLog do
  @moduledoc false

  use TeiserverWeb, :schema

  @event_types ~w(
    lobby_open lobby_close
    lobby_join lobby_leave
    vote_start vote_end vote_cast
    battle_start battle_end
    join_spectators join_team
    kickban
    bot_add bot_remove
    boss_add boss_remove
  )

  typed_schema "lobby_logs" do
    field :lobby_id, Ecto.UUID

    field :event_type, :string
    field :details, :map

    belongs_to :user, Teiserver.Account.User
    belongs_to :target, Teiserver.Account.User

    timestamps(updated_at: false, type: :utc_datetime_usec)
  end

  @spec event_types() :: [String.t()]
  def event_types, do: @event_types

  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:lobby_id, :event_type, :details, :user_id, :target_id, :inserted_at])
    |> validate_required([:lobby_id, :event_type])
    |> validate_inclusion(:event_type, @event_types)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:target_id)
  end
end
