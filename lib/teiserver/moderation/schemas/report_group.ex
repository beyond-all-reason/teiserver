defmodule Teiserver.Moderation.ReportGroup do
  @moduledoc false
  use TeiserverWeb, :schema

  schema "moderation_report_groups" do
    belongs_to :match, Teiserver.Battle.Match

    field :report_count, :integer, default: 0
    field :action_count, :integer, default: 0
    field :type, :string
    field :closed, :boolean, default: false

    has_many :actions, Teiserver.Moderation.Action
    has_many :reports, Teiserver.Moderation.Report

    timestamps()
  end

  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(
      params,
      ~w(match_id report_count action_count closed)a
    )
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), map()) :: Boolean.t()
  def authorize(:index, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:search, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:show, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:user, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:respond, conn, _), do: allow?(conn, "Overwatch")
  def authorize(_, conn, _), do: allow?(conn, "Moderator")
end
