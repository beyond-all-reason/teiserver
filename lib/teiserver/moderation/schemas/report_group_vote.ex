defmodule Teiserver.Moderation.ReportGroupVote do
  @moduledoc false
  use TeiserverWeb, :schema

  schema "moderation_report_group_votes" do
    belongs_to :report_group, Teiserver.Moderation.ReportGroup
    belongs_to :user, Teiserver.Account.User

    field :action, :string
    field :accuracy, :string

    timestamps()
  end

  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(action accuracy)a)

    struct
    |> cast(
      params,
      ~w(report_group_id user_id action accuracy)a
    )
    |> validate_required(~w(report_group_id user_id action accuracy)a)
  end

  @spec authorize(atom(), Plug.Conn.t(), map()) :: Boolean.t()
  def authorize(:index, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:search, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:show, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:user, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:respond, conn, _), do: allow?(conn, "Overwatch")
  def authorize(_, conn, _), do: allow?(conn, "Moderator")
end
