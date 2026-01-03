defmodule Teiserver.Account.FriendRequest do
  @moduledoc false
  use TeiserverWeb, :schema

  @primary_key false
  typed_schema "account_friend_requests" do
    belongs_to :from_user, Teiserver.Account.User, primary_key: true
    belongs_to :to_user, Teiserver.Account.User, primary_key: true

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(from_user_id to_user_id)a)
    |> validate_required(~w(from_user_id to_user_id)a)
  end

  @spec authorize(atom(), Plug.Conn.t(), map()) :: bool()
  def authorize(:index, conn, _), do: allow?(conn, "Moderator")
end
