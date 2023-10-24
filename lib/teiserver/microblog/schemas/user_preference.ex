defmodule Teiserver.Microblog.UserPreference do
  @moduledoc false
  use CentralWeb, :schema

  @primary_key false
  schema "microblog_user_preferences" do
    belongs_to :user, Central.Account.User, primary_key: true

    field :enabled_tags, {:array, :integer}
    field :disabled_tags, {:array, :integer}

    field :enabled_posters, {:array, :integer}
    field :disabled_posters, {:array, :integer}

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(user_id enabled_tags disabled_tags enabled_posters disabled_posters)a)
    |> validate_required(~w(user_id)a)
  end

  @spec authorize(atom, Plug.Conn.t(), Map.t()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Contributor")
end
