defmodule Teiserver.Telemetry.AnonProperty do
  @moduledoc false
  use TeiserverWeb, :schema

  @primary_key false
  typed_schema "telemetry_anon_properties" do
    field :hash, :string, primary_key: true
    belongs_to :property_type, Teiserver.Telemetry.PropertyType, primary_key: true

    field :last_updated, :utc_datetime
    field :value, :string
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(property_type_id last_updated value hash)a)
    |> validate_required(~w(property_type_id last_updated value hash)a)
  end

  @spec authorize(atom, Plug.Conn.t(), map()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
