defmodule Teiserver.Microblog.UserPreference do
  @moduledoc false
  use TeiserverWeb, :schema

  @primary_key false
  schema "microblog_user_preferences" do
    belongs_to :user, Teiserver.Account.User, primary_key: true

    field :tag_mode, :string

    field :enabled_tags, {:array, :integer}, default: []
    field :disabled_tags, {:array, :integer}, default: []

    field :enabled_posters, {:array, :integer}, default: []
    field :disabled_posters, {:array, :integer}, default: []

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(
      params,
      ~w(user_id tag_mode enabled_tags disabled_tags enabled_posters disabled_posters)a
    )
    |> validate_required(~w(user_id)a)
  end

  @spec authorize(atom, Plug.Conn.t(), map()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Contributor")
end
