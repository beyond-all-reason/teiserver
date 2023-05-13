defmodule Teiserver.Chat.LobbyMessage do
  use CentralWeb, :schema

  schema "teiserver_lobby_messages" do
    field :content, :string
    field :inserted_at, :utc_datetime
    belongs_to :user, Central.Account.User
    belongs_to :match, Teiserver.Battle.Match
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings([:content])

    struct
    |> cast(params, ~w(content inserted_at match_id user_id)a)
    |> validate_required(~w(content inserted_at user_id)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(:index, conn, _), do: allow?(conn, "Reviewer")
  def authorize(_, conn, _), do: allow?(conn, "Moderator")
end
