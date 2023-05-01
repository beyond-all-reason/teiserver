defmodule Teiserver.Moderation.Response do
  @moduledoc false
  use CentralWeb, :schema

  schema "moderation_responses" do
    belongs_to :report, Teiserver.Moderation.Report
    belongs_to :user, Central.Account.User

    field :warn, :boolean, default: false
    field :mute, :boolean, default: false
    field :suspend, :boolean, default: false
    field :accurate, :boolean, default: false

    timestamps()
  end

  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(
      params,
      ~w(report_id user_id warn mute suspend accurate)a
    )
    |> validate_required(~w(report_id user_id warn mute suspend accurate)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(:index, conn, _), do: allow?(conn, "teiserver.staff.overwatch")
  def authorize(:search, conn, _), do: allow?(conn, "teiserver.staff.overwatch")
  def authorize(:show, conn, _), do: allow?(conn, "teiserver.staff.overwatch")
  def authorize(:user, conn, _), do: allow?(conn, "teiserver.staff.overwatch")
  def authorize(_, conn, _), do: allow?(conn, "teiserver.staff.moderator")
end
