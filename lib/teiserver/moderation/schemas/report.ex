defmodule Teiserver.Moderation.Report do
  @moduledoc false
  use TeiserverWeb, :schema

  schema "moderation_reports" do
    belongs_to :reporter, Central.Account.User
    belongs_to :target, Central.Account.User

    field :type, :string
    field :sub_type, :string
    field :extra_text, :string

    belongs_to :match, Teiserver.Battle.Match
    field :relationship, :string
    belongs_to :result, Teiserver.Moderation.Action

    timestamps()
  end

  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params = params
      |> trim_strings(~w(name)a)

    struct
      |> cast(params, ~w(reporter_id target_id type sub_type extra_text match_id relationship result_id)a)
      |> validate_required(~w(reporter_id target_id type sub_type)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(:index, conn, _), do: allow?(conn, "teiserver.staff.reviewer")
  def authorize(:search, conn, _), do: allow?(conn, "teiserver.staff.reviewer")
  def authorize(:show, conn, _), do: allow?(conn, "teiserver.staff.reviewer")
  def authorize(:user, conn, _), do: allow?(conn, "teiserver.staff.reviewer")
  def authorize(_, conn, _), do: allow?(conn, "teiserver.staff.moderator")
end
