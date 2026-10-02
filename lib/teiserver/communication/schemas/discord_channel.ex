defmodule Teiserver.Communication.DiscordChannel do
  @moduledoc false
  use TeiserverWeb, :schema

  @type id :: pos_integer()

  typed_schema "communication_discord_channels" do
    field :name, :string
    field :channel_id, :integer

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(name channel_id)a)
    |> validate_required(~w(name channel_id)a)
    |> unique_constraint(:name)
  end
end
