defmodule Teiserver.Account.Friend do
  @moduledoc false
  use TeiserverWeb, :schema

  @primary_key false
  schema "account_friends" do
    belongs_to :user1, Teiserver.Account.User, primary_key: true
    belongs_to :user2, Teiserver.Account.User, primary_key: true

    field :other_user, :map, virtual: true

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(user1_id user2_id)a)
    |> validate_required(~w(user1_id user2_id)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), map()) :: Boolean.t()
  def authorize(:index, conn, _), do: allow?(conn, "Moderator")
end
