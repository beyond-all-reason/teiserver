defmodule Teiserver.Telemetry.ClientProperty do
  @moduledoc false
  use CentralWeb, :schema

  @primary_key false
  schema "telemetry_simple_user_properties" do
    belongs_to :user, Central.Account.User, primary_key: true
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
    |> cast(params, ~w(user_id property_type_id last_updated value)a)
    |> validate_required(~w(user_id property_type_id last_updated value)a)
  end

  @spec authorize(atom, Plug.Conn.t(), Map.t()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
