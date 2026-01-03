defmodule Teiserver.Logging.ServerMinuteLog do
  use TeiserverWeb, :schema

  @primary_key false
  typed_schema "teiserver_server_minute_logs" do
    field :timestamp, :utc_datetime, primary_key: true
    field :data, :map
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:timestamp, :data])
    |> validate_required([:timestamp, :data])
  end

  @spec authorize(atom, Plug.Conn.t(), map()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
