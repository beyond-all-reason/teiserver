defmodule Teiserver.Moderation.Action do
  @moduledoc false
  use TeiserverWeb, :schema
  alias Teiserver.Helper.TimexHelper

  schema "moderation_actions" do
    belongs_to :target, Teiserver.Account.User
    field :reason, :string
    field :appeal_status, :string
    field :notes, :string
    field :restrictions, {:array, :string}
    field :score_modifier, :integer
    field :expires, :naive_datetime

    field :hidden, :boolean, default: false

    field :discord_message_id, :bigint

    belongs_to :report_group, Teiserver.Moderation.ReportGroup

    timestamps()
  end

  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(reason notes)a)
      |> parse_humantimes(~w(expires)a)

    struct
    |> cast(
      params,
      ~w(target_id report_group_id reason restrictions score_modifier expires notes hidden discord_message_id appeal_status)a
    )
    |> validate_required(~w(target_id reason restrictions expires score_modifier)a)
    |> adjust_restrictions
    |> validate_length(:restrictions, min: 1)
  end

  defp adjust_restrictions(%Ecto.Changeset{} = struct) do
    years = Timex.now() |> Timex.shift(years: 10)
    expires = Ecto.Changeset.get_field(struct, :expires, [])
    inbound_restrictions = Ecto.Changeset.get_field(struct, :restrictions, [])

    new_restrictions =
      if TimexHelper.greater_than(expires, years) and Enum.member?(inbound_restrictions, "Login") do
        ["Permanently banned" | inbound_restrictions] |> Enum.uniq()
      else
        (inbound_restrictions || []) |> List.delete("Permanently banned")
      end

    Ecto.Changeset.put_change(struct, :restrictions, new_restrictions)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), map()) :: Boolean.t()
  def authorize(:index, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:search, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:show, conn, _), do: allow?(conn, "Overwatch")
  def authorize(_, conn, _), do: allow?(conn, "Moderator")
end
