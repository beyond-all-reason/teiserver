defmodule Teiserver.Moderation.Response do
  @moduledoc false
  use TeiserverWeb, :schema

  @primary_key false
  typed_schema "moderation_responses" do
    belongs_to :report, Teiserver.Moderation.Report, primary_key: true
    belongs_to :user, Teiserver.Account.User, primary_key: true

    field :action, :string, default: "Ignore"
    field :accurate, :boolean, default: false

    timestamps()
  end

  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(
      params,
      ~w(report_id user_id action accurate)a
    )
    |> validate_required(~w(report_id user_id action accurate)a)
  end

  @spec authorize(atom(), Plug.Conn.t(), map()) :: bool()
  def authorize(:index, conn, _params), do: allow?(conn, "Overwatch")
  def authorize(:search, conn, _params), do: allow?(conn, "Overwatch")
  def authorize(:show, conn, _params), do: allow?(conn, "Overwatch")
  def authorize(:user, conn, _params), do: allow?(conn, "Overwatch")
  def authorize(_action, conn, _params), do: allow?(conn, "Moderator")
end
