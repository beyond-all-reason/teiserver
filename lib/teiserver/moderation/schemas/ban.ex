defmodule Teiserver.Moderation.Ban do
  @moduledoc false
  use TeiserverWeb, :schema

  schema "moderation_bans" do
    belongs_to :source, Teiserver.Account.User
    belongs_to :added_by, Teiserver.Account.User

    field :key_values, {:array, :string}
    field :enabled, :boolean
    field :reason, :string

    timestamps()
  end

  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(reason)a)

    struct
    |> cast(params, ~w(source_id added_by_id key_values enabled reason)a)
    |> validate_required(~w(source_id added_by_id key_values enabled reason)a)
  end

  @spec authorize(atom(), Plug.Conn.t(), map()) :: bool()
  def authorize(:index, conn, _), do: allow?(conn, "Overwatch")
  def authorize(:show, conn, _), do: allow?(conn, "Reviewer")
  def authorize(_, conn, _), do: allow?(conn, "Moderator")
end
