defmodule Teiserver.Moderation.Report do
  @moduledoc false
  use TeiserverWeb, :schema

  typed_schema "moderation_reports" do
    belongs_to :reporter, Teiserver.Account.User
    belongs_to :target, Teiserver.Account.User

    field :type, :string
    field :sub_type, :string
    field :extra_text, :string
    field :closed, :boolean, default: false
    field :discord_message_id, :integer

    belongs_to :match, Teiserver.Battle.Match
    field :relationship, :string
    belongs_to :result, Teiserver.Moderation.Action
    belongs_to :report_group, Teiserver.Moderation.ReportGroup

    has_many :responses, Teiserver.Moderation.Response

    timestamps()
  end

  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(name)a)

    struct
    |> cast(
      params,
      ~w(reporter_id target_id type sub_type extra_text match_id discord_message_id relationship result_id closed report_group_id)a
    )
    |> validate_required(~w(reporter_id target_id type sub_type closed)a)
  end

  @spec authorize(atom(), Plug.Conn.t(), map()) :: bool()
  def authorize(:index, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:search, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:show, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:user, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:respond, conn, _), do: allow?(conn, "Overwatch")
  def authorize(_, conn, _), do: allow?(conn, "Moderator")
end
