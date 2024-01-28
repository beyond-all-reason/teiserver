defmodule Barserver.Telemetry.SimpleMatchEvent do
  @moduledoc false
  use BarserverWeb, :schema

  schema "telemetry_simple_match_events" do
    belongs_to :user, Barserver.Account.User
    belongs_to :match, Barserver.Battle.Match
    belongs_to :event_type, Barserver.Telemetry.SimpleMatchEventType

    field :game_time, :integer
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(user_id match_id event_type_id game_time)a)
    |> validate_required(~w(match_id event_type_id game_time)a)
  end

  @spec authorize(atom, Plug.Conn.t(), Map.t()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
