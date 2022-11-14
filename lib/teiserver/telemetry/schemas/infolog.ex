defmodule Teiserver.Telemetry.Infolog do
  use CentralWeb, :schema

  schema "teiserver_telemetry_infologs" do
    field :user_hash, :string
    belongs_to :user, Central.Account.User
    field :log_type, :string

    field :timestamp, :utc_datetime
    field :metadata, :map
    field :contents, :string
    field :size, :integer
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(user_hash user_id log_type timestamp metadata contents size)a)
    |> validate_required(~w(user_hash log_type timestamp metadata contents size)a)
  end

  @spec authorize(atom, Plug.Conn.t(), Map.t()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "teiserver.moderator.telemetry")
end
