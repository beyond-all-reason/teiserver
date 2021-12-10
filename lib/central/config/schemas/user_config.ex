defmodule Central.Config.UserConfig do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "config_user" do
    field :key, :string
    field :value, :string
    field :user_id, :id

    timestamps()
  end

  @doc false
  def changeset(user_config, attrs) do
    user_config
    |> cast(attrs, [:key, :value, :user_id])
    |> validate_required([:key, :value, :user_id])
  end

  def creation_changeset(struct, config_info) do
    struct
    |> cast(%{}, [:key, :value, :user_id])
    |> put_change(:key, config_info.key)
    |> put_change(:value, config_info.default)
  end
end
