defmodule Teiserver.Account.SmurfLink do
  use CentralWeb, :schema

  @primary_key false
  schema "teiserver_account_smurf_links" do
    belongs_to :user1, Central.Account.User, primary_key: true
    belongs_to :user2, Central.Account.User, primary_key: true
    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
      |> cast(params, ~w(user1_id user2_id)a)
      |> validate_required(~w(user1_id user2_id)a)
  end
end
