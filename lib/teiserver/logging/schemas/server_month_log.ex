defmodule Teiserver.Logging.ServerMonthLog do
  use TeiserverWeb, :schema

  @primary_key false
  schema "teiserver_server_month_logs" do
    field :year, :integer, primary_key: true
    field :month, :integer, primary_key: true
    field :date, :date
    field :data, :map
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(year month date data)a)
    |> validate_required(~w(year month date data)a)
  end

  @spec authorize(atom, Plug.Conn.t(), map()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
