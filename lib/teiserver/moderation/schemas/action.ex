defmodule Teiserver.Moderation.Action do
  @moduledoc false
  use CentralWeb, :schema
  alias Central.Helpers.TimexHelper

  schema "moderation_actions" do
    belongs_to :target, Central.Account.User
    field :reason, :string
    field :restrictions, {:array, :string}
    field :score_modifier, :integer
    field :expires, :naive_datetime

    field :hidden, :boolean, default: false

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
    |> cast(params, ~w(target_id reason restrictions score_modifier expires hidden)a)
    |> validate_required(~w(target_id reason restrictions expires score_modifier)a)
    |> adjust_restrictions
    |> validate_length(:restrictions, min: 1)
  end

  defp adjust_restrictions(%Ecto.Changeset{} = struct) do
    years = Timex.now() |> Timex.shift(years: 10)
    inbound_restrictions = Ecto.Changeset.get_field(struct, :restrictions, [])

    new_restrictions = if TimexHelper.greater_than(struct.data.expires, years) and Enum.member?(inbound_restrictions, "Login") do
      ["Permanently banned" | inbound_restrictions] |> Enum.uniq
    else
      (inbound_restrictions || []) |> List.delete("Permanently banned")
    end

    Ecto.Changeset.put_change(struct, :restrictions, new_restrictions)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(:index, conn, _), do: allow?(conn, "teiserver.staff.overwatch")
  def authorize(:search, conn, _), do: allow?(conn, "teiserver.staff.overwatch")
  def authorize(:show, conn, _), do: allow?(conn, "teiserver.staff.overwatch")
  def authorize(_, conn, _), do: allow?(conn, "teiserver.staff.moderator")
end
