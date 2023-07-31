defmodule Teiserver.Moderation.ReportGroup do
  @moduledoc false
  use CentralWeb, :schema

  schema "moderation_report_groups" do
    belongs_to :target, Central.Account.User
    belongs_to :match, Teiserver.Battle.Match
    belongs_to :action_id, Teiserver.Moderation.Action

    has_many :reports, Teiserver.Moderation.Report
    has_many :report_group_votes, Teiserver.Moderation.ReportGroupVote
    has_many :report_group_messages, Teiserver.Moderation.ReportGroupMessage

    timestamps()
  end

  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(name)a)

    struct
    |> cast(
      params,
      ~w(reporter_id target_id type sub_type extra_text match_id relationship result_id closed)a
    )
    |> validate_required(~w(reporter_id target_id type sub_type closed)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(:index, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:search, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:show, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:user, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:respond, conn, _), do: allow?(conn, "Overwatch")
  def authorize(_, conn, _), do: allow?(conn, "Moderator")
end
