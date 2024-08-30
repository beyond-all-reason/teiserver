defmodule Teiserver.Logging.UserActivityDayLog do
  @moduledoc false
  use TeiserverWeb, :schema

  @primary_key false
  schema "telemetry_user_activity_day_logs" do
    field :date, :date, primary_key: true
    field :data, :map
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:date, :data])
    |> validate_required([:date, :data])
  end

  @spec authorize(atom, Plug.Conn.t(), map()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
