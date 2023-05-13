defmodule Teiserver.Telemetry.UnauthProperty do
  use CentralWeb, :schema

  @primary_key false
  schema "teiserver_telemetry_unauth_properties" do
    field :hash, :string, primary_key: true
    belongs_to :property_type, Teiserver.Telemetry.PropertyType, primary_key: true

    field :last_updated, :utc_datetime
    field :value, :string
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:property_type_id, :last_updated, :value, :hash])
    |> validate_required([:property_type_id, :last_updated, :value, :hash])
  end

  @spec authorize(atom, Plug.Conn.t(), Map.t()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
