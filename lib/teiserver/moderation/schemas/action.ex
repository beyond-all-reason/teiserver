defmodule Teiserver.Moderation.Action do
  @moduledoc false
  use CentralWeb, :schema

  schema "moderation_actions" do
    belongs_to :target, Central.Account.User
    field :reason, :string
    field :restrictions, {:array, :string}
    field :score_modifier, :integer
    field :expires, :naive_datetime

    has_many :reports, Teiserver.Moderation.Report, foreign_key: :result_id

    timestamps()
  end

  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(reason)a)
      |> parse_humantimes(~w(expires)a)

    struct
    |> cast(params, ~w(target_id reason restrictions score_modifier expires)a)
    |> validate_required(~w(target_id reason restrictions expires score_modifier)a)
    |> validate_length(:restrictions, min: 1)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(:index, conn, _), do: allow?(conn, "teiserver.staff.overwatch")
  def authorize(:search, conn, _), do: allow?(conn, "teiserver.staff.overwatch")
  def authorize(:show, conn, _), do: allow?(conn, "teiserver.staff.overwatch")
  def authorize(_, conn, _), do: allow?(conn, "teiserver.staff.moderator")
end
