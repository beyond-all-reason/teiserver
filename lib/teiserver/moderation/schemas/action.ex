defmodule Teiserver.Moderation.Action do
  @moduledoc false
  use TeiserverWeb, :schema

  schema "moderation_actions" do
    belongs_to :target, Central.Account.User
    field :reason, :string
    field :actions, {:array, :string}
    field :score_modifier, :integer
    field :expires, :naive_datetime

    timestamps()
  end

  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params = params
      |> trim_strings(~w(reason)a)

    struct
      |> cast(params, ~w(target_id reason actions score_modifier expires)a)
      |> validate_required(~w(target_id reason actions score_modifier)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(_, conn, _), do: allow?(conn, "moderation")
end
