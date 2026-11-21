defmodule Teiserver.Chat.BattleMessage do
  @moduledoc false
  use TeiserverWeb, :schema

  @destinations ~w(allies all spectators player)

  @primary_key {:id, Ecto.UUID, autogenerate: [version: 7, precision: :monotonic]}
  typed_schema "battle_messages" do
    field :content, :string
    field :destination, :string
    field :inserted_at, :utc_datetime
    belongs_to :match, Teiserver.Battle.Match
    belongs_to :from, Teiserver.Account.User
    belongs_to :to, Teiserver.Account.User
  end

  @spec destinations() :: [String.t()]
  def destinations, do: @destinations

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings([:content])

    struct
    |> cast(params, ~w(content destination inserted_at match_id from_id to_id)a)
    |> validate_required(~w(content destination inserted_at match_id from_id)a)
    |> validate_inclusion(:destination, @destinations)
    |> foreign_key_constraint(:match_id)
    |> foreign_key_constraint(:to_id)
    |> foreign_key_constraint(:from_id)
  end
end
