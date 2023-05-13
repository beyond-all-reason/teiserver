defmodule Teiserver.Moderation.Response do
  @moduledoc false
  use CentralWeb, :schema

  @primary_key false
  schema "moderation_responses" do
    belongs_to :report, Teiserver.Moderation.Report, primary_key: true
    belongs_to :user, Central.Account.User, primary_key: true

    field :action, :string, default: "Ignore"
    field :accurate, :boolean, default: false

    timestamps()
  end

  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(
      params,
      ~w(report_id user_id action accurate)a
    )
    |> validate_required(~w(report_id user_id action accurate)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(:index, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:search, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:show, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:user, conn, _), do: allow?(conn, "Overwatch")
  def authorize(_, conn, _), do: allow?(conn, "Moderator")
end
