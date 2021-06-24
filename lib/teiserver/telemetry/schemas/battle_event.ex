defmodule Teiserver.Telemetry.BattleEvent do
  use CentralWeb, :schema

  schema "teiserver_telemetry_battle_events" do
    belongs_to :user, Central.Account.User
    field :battle_id, :integer

    belongs_to :event, Teiserver.Telemetry.Event

    field :timestamp, :utc_datetime
    field :value, :string
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:battle_id, :user_id, :event_id, :timestamp, :value])
    |> validate_required([:battle_id, :user_id, :event_id, :timestamp, :value])
  end

  @spec authorize(atom, Plug.Conn.t(), Map.t()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "teiserver.admin.telemetry")
end
