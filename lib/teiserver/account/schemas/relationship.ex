defmodule Teiserver.Account.Relationship do
  @moduledoc false
  use CentralWeb, :schema

  @primary_key false
  schema "account_relationships" do
    belongs_to :from_user, Central.Account.User, primary_key: true
    belongs_to :to_user, Central.Account.User, primary_key: true

    field :state, :string
    field :follow, :boolean, default: false

    field :notes, :string
    field :tags, {:array, :string}

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(state notes)a)

    struct
    |> cast(params, ~w(from_user_id to_user_id state follow notes tags)a)
    |> validate_required(~w(from_user_id to_user_id)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(:index, conn, _), do: allow?(conn, "Moderator")
end
