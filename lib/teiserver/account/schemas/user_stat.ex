defmodule Teiserver.Account.UserStat do
  use CentralWeb, :schema

  @primary_key false
  schema "teiserver_account_user_stats" do
    belongs_to :user, Central.Account.User, primary_key: true
    field :data, :map, default: %{}
  end

  @doc false
  def changeset(stats, attrs \\ %{}) do
    stats
    |> cast(attrs, [:user_id, :data])
    |> validate_required([:user_id, :data])
  end
end
