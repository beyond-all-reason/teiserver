defmodule Teiserver.Communication.TextCallback do
  @moduledoc false
  use CentralWeb, :schema

  schema "communication_text_callbacks" do
    field :name, :string

    field :icon, :string
    field :colour, :string
    field :enabled, :boolean, default: true

    field :triggers, {:array, :string}

    field :response, :string

    field :rules, :map, default: %{}

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
    |> cast(params, ~w(name icon colour triggers response enabled rules)a)
    |> validate_required(~w(name icon colour triggers response)a)
    |> validate_length(:triggers, min: 1)
  end

  @spec authorize(atom, Plug.Conn.t(), Map.t()) :: boolean
  def authorize(:index, conn, _params), do: allow_any?(conn, ["Overwatch", "Contributor"])
  def authorize(:show, conn, _params), do: allow_any?(conn, ["Overwatch", "Contributor"])
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
