defmodule Barserver.Telemetry.ComplexLobbyEvent do
  @moduledoc false
  use BarserverWeb, :schema

  schema "telemetry_complex_lobby_events" do
    belongs_to :user, Barserver.Account.User
    belongs_to :match, Barserver.Battle.Match
    belongs_to :event_type, Barserver.Telemetry.ComplexLobbyEventType
    field :timestamp, :utc_datetime
    field :value, :map
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(user_id event_type_id match_id timestamp value)a)
    |> validate_required(~w(event_type_id timestamp)a)
  end

  @spec authorize(atom, Plug.Conn.t(), Map.t()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
