defmodule Teiserver.Chat.LobbyMessage do
  @moduledoc """
  Messages sent in a Tachyon lobby. A lobby can live through several matches,
  so messages always belong to a lobby and are only linked to a match when
  one is running.
  """
  use TeiserverWeb, :schema

  @primary_key {:id, Ecto.UUID, autogenerate: [version: 7, precision: :monotonic]}
  typed_schema "lobby_messages" do
    field :content, :string
    field :inserted_at, :utc_datetime
    field :lobby_id, Ecto.UUID
    belongs_to :user, Teiserver.Account.User
    belongs_to :match, Teiserver.Battle.Match
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings([:content])

    struct
    |> cast(params, ~w(content inserted_at match_id lobby_id user_id)a)
    |> validate_required(~w(content inserted_at user_id lobby_id)a)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:match_id)
  end
end
