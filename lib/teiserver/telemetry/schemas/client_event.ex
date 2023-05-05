defmodule Teiserver.Telemetry.ClientEvent do
  use CentralWeb, :schema

  schema "teiserver_telemetry_client_events" do
    belongs_to :user, Central.Account.User
    belongs_to :event_type, Teiserver.Telemetry.EventType

    field :timestamp, :utc_datetime
    field :value, :map
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(user_id event_type_id timestamp value)a)
    |> validate_required(~w(user_id event_type_id timestamp value)a)
  end

  @spec authorize(atom, Plug.Conn.t(), Map.t()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "teiserver.admin.telemetry")
end
