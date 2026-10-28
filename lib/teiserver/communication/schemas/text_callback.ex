defmodule Teiserver.Communication.TextCallback do
  @moduledoc false
  use TeiserverWeb, :schema

  @type id :: pos_integer()

  typed_schema "communication_text_callbacks" do
    field :name, :string

    field :enabled, :boolean, default: true

    field :response, :string
    field :last_triggered, :map, default: %{}

    field :category, :string, default: "default"

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(name)a)

    struct
    |> cast(params, ~w(name response enabled last_triggered category)a)
    |> validate_required(~w(name response category)a)
  end
end
