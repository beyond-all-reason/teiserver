defmodule Teiserver.Telemetry.SimpleServerEvent do
  @moduledoc false
  use TeiserverWeb, :schema

  schema "telemetry_simple_server_events" do
    belongs_to :user, Teiserver.Account.User
    belongs_to :event_type, Teiserver.Telemetry.SimpleServerEventType
    field :timestamp, :utc_datetime
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(user_id event_type_id timestamp)a)
    |> validate_required(~w(event_type_id timestamp)a)
  end

  @spec authorize(atom, Plug.Conn.t(), map()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
