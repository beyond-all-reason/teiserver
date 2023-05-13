defmodule Teiserver.Telemetry.UnauthGameEvent do
  use CentralWeb, :schema

  schema "teiserver_telemetry_unauth_game_events" do
    field :hash, :string
    belongs_to :game_event_type, Teiserver.Telemetry.GameEventType

    field :timestamp, :utc_datetime
    field :value, :map
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:hash, :game_event_type_id, :timestamp, :value])
    |> validate_required([:hash, :game_event_type_id, :timestamp, :value])
  end

  @spec authorize(atom, Plug.Conn.t(), Map.t()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
