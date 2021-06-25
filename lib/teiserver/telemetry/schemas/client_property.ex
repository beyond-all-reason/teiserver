defmodule Teiserver.Telemetry.ClientProperty do
  use CentralWeb, :schema

  @primary_key false
  schema "teiserver_telemetry_client_properties" do
    belongs_to :user, Central.Account.User, primary_key: true
    belongs_to :event, Teiserver.Telemetry.Event, primary_key: true

    field :last_updated, :utc_datetime
    field :value, :string
    field :hash, :string
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:user_id, :event_id, :last_updated, :value, :hash])
    |> validate_required([:user_id, :event_id, :last_updated, :value, :hash])
  end

  @spec authorize(atom, Plug.Conn.t(), Map.t()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "teiserver.admin.telemetry")
end
