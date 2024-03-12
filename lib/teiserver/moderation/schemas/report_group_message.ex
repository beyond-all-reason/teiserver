defmodule Barserver.Moderation.ReportGroupMessage do
  @moduledoc false
  use BarserverWeb, :schema

  schema "moderation_report_group_messages" do
    belongs_to :report_group, Barserver.Moderation.ReportGroup
    belongs_to :user, Barserver.Account.User

    field :content, :string

    timestamps()
  end

  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(content)a)

    struct
    |> cast(
      params,
      ~w(report_group_id user_id content)a
    )
    |> validate_required(~w(report_group_id user_id content)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(:index, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:search, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:show, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:user, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:respond, conn, _), do: allow?(conn, "Overwatch")
  def authorize(_, conn, _), do: allow?(conn, "Moderator")
end
