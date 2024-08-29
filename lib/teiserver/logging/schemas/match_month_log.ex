defmodule Teiserver.Logging.MatchMonthLog do
  use TeiserverWeb, :schema

  @primary_key false
  schema "teiserver_match_month_logs" do
    field :year, :integer, primary_key: true
    field :month, :integer, primary_key: true
    field :data, :map
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:year, :month, :data])
    |> validate_required([:year, :month, :data])
  end

  @spec authorize(atom, Plug.Conn.t(), map()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
