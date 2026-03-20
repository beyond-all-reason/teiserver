defmodule Teiserver.Bot.Bot do
  @moduledoc false

  alias Ecto.Changeset

  use TeiserverWeb, :schema

  @type id :: integer()

  typed_schema "teiserver_bots" do
    field :name, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(bot, attrs) do
    bot
    |> cast(attrs, [:name])
    |> Changeset.validate_required([:name])
    |> Changeset.validate_length(:name, min: 3, max: 30)
  end
end
