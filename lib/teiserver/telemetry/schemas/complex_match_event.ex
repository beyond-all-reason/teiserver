defmodule Teiserver.Telemetry.ComplexMatchEvent do
  @moduledoc false
  use TeiserverWeb, :schema

  schema "telemetry_complex_match_events" do
    belongs_to :user, Teiserver.Account.User
    belongs_to :match, Teiserver.Battle.Match
    belongs_to :event_type, Teiserver.Telemetry.ComplexMatchEventType

    field :value, :map
    field :game_time, :integer
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(user_id match_id event_type_id value game_time)a)
    |> validate_required(~w(match_id event_type_id value game_time)a)
  end

  @spec authorize(atom, Plug.Conn.t(), map()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
