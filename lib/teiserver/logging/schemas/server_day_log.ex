defmodule Barserver.Logging.ServerDayLog do
  use BarserverWeb, :schema

  @primary_key false
  schema "teiserver_server_day_logs" do
    field :date, :date, primary_key: true
    field :data, :map
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:date, :data])
    |> validate_required([:date, :data])
  end

  @spec authorize(atom, Plug.Conn.t(), Map.t()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
