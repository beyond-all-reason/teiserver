defmodule Teiserver.Moderation.ReportGroupMessage do
  @moduledoc false
  use TeiserverWeb, :schema

  typed_schema "moderation_report_group_messages" do
    belongs_to :report_group, Teiserver.Moderation.ReportGroup
    belongs_to :user, Teiserver.Account.User

    field :content, :string

    timestamps()
  end

  @spec changeset(map(), map()) :: Ecto.Changeset.t()
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

  @spec authorize(atom(), Plug.Conn.t(), map()) :: bool()
  def authorize(:index, conn, _params), do: allow?(conn, "Overwatch")
  def authorize(:search, conn, _params), do: allow?(conn, "Overwatch")
  def authorize(:show, conn, _params), do: allow?(conn, "Overwatch")
  def authorize(:user, conn, _params), do: allow?(conn, "Overwatch")
  def authorize(:respond, conn, _params), do: allow?(conn, "Overwatch")
  def authorize(_action, conn, _params), do: allow?(conn, "Moderator")
end
