defmodule Teiserver.Moderation.Report do
  @moduledoc false
  use CentralWeb, :schema

  schema "moderation_reports" do
    belongs_to :reporter, Central.Account.User
    belongs_to :target, Central.Account.User

    field :type, :string
    field :sub_type, :string
    field :extra_text, :string
    field :closed, :boolean, default: false

    belongs_to :match, Teiserver.Battle.Match
    field :relationship, :string
    belongs_to :result, Teiserver.Moderation.Action

    has_many :responses, Teiserver.Moderation.Response

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
  def authorize(:index, conn, _), do: allow?(conn, "teiserver.staff.overwatch")
  def authorize(:search, conn, _), do: allow?(conn, "teiserver.staff.overwatch")
  def authorize(:show, conn, _), do: allow?(conn, "teiserver.staff.overwatch")
  def authorize(:user, conn, _), do: allow?(conn, "teiserver.staff.overwatch")
  def authorize(_, conn, _), do: allow?(conn, "teiserver.staff.moderator")
end
