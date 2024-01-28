defmodule Barserver.Account.FriendRequest do
  @moduledoc false
  use BarserverWeb, :schema

  @primary_key false
  schema "account_friend_requests" do
    belongs_to :from_user, Barserver.Account.User, primary_key: true
    belongs_to :to_user, Barserver.Account.User, primary_key: true

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(from_user_id to_user_id)a)
    |> validate_required(~w(from_user_id to_user_id)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(:index, conn, _), do: allow?(conn, "Moderator")
end
