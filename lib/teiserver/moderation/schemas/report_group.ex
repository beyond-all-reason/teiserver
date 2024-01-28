defmodule Barserver.Moderation.ReportGroup do
  @moduledoc false
  use BarserverWeb, :schema

  schema "moderation_report_groups" do
    belongs_to :target, Barserver.Account.User
    belongs_to :match, Barserver.Battle.Match

    field :closed, :boolean, default: false
    field :report_count, :integer, default: 0
    field :vote_count, :integer, default: 0
    field :action_count, :integer, default: 0

    has_many :actions, Barserver.Moderation.Action
    has_many :reports, Barserver.Moderation.Report
    has_many :report_group_votes, Barserver.Moderation.ReportGroupVote
    has_many :report_group_messages, Barserver.Moderation.ReportGroupMessage

    timestamps()
  end

  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(
      params,
      ~w(target_id match_id report_count vote_count action_count closed)a
    )
    |> validate_required(~w(target_id)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(:index, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:search, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:show, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:user, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:respond, conn, _), do: allow?(conn, "Overwatch")
  def authorize(_, conn, _), do: allow?(conn, "Moderator")
end
