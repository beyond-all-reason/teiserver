defmodule Teiserver.Telemetry.Infolog do
  @moduledoc false
  use TeiserverWeb, :schema

  schema "telemetry_infologs" do
    field :user_hash, :string
    belongs_to :user, Teiserver.Account.User
    field :log_type, :string

    field :timestamp, :utc_datetime
    field :metadata, :map
    field :contents, :string
    field :size, :integer
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(user_hash user_id log_type timestamp metadata contents size)a)
    |> validate_required(~w(user_hash log_type timestamp metadata contents size)a)
  end

  @spec authorize(atom, Plug.Conn.t(), map()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Engine")
end
