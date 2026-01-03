defmodule Teiserver.Moderation.ReportGroup do
  @moduledoc false
  use TeiserverWeb, :schema

  typed_schema "moderation_report_groups" do
    belongs_to :target, Teiserver.Account.User
    belongs_to :match, Teiserver.Battle.Match

    field :closed, :boolean, default: false
    field :report_count, :integer, default: 0
    field :vote_count, :integer, default: 0
    field :action_count, :integer, default: 0

    has_many :actions, Teiserver.Moderation.Action
    has_many :reports, Teiserver.Moderation.Report
    has_many :report_group_votes, Teiserver.Moderation.ReportGroupVote
    has_many :report_group_messages, Teiserver.Moderation.ReportGroupMessage

    timestamps()
  end

  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(
      params,
      ~w(target_id match_id report_count vote_count action_count closed)a
    )
    |> validate_required(~w(target_id)a)
  end

  @spec authorize(atom(), Plug.Conn.t(), map()) :: bool()
  def authorize(:index, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:search, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:show, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:user, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:respond, conn, _), do: allow?(conn, "Overwatch")
  def authorize(_, conn, _), do: allow?(conn, "Moderator")
end
