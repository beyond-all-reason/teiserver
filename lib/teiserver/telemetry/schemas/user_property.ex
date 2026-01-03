defmodule Teiserver.Telemetry.UserProperty do
  @moduledoc false
  use TeiserverWeb, :schema

  @primary_key false
  typed_schema "telemetry_user_properties" do
    belongs_to :user, Teiserver.Account.User, primary_key: true
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
    |> cast(params, ~w(user_id property_type_id last_updated value)a)
    |> validate_required(~w(user_id property_type_id last_updated value)a)
  end

  @spec authorize(atom, Plug.Conn.t(), map()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
