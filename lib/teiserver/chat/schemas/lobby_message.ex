defmodule Teiserver.Chat.LobbyMessage do
  @moduledoc false
  use TeiserverWeb, :schema

  schema "teiserver_lobby_messages" do
    field :content, :string
    field :inserted_at, :utc_datetime
    belongs_to :user, Teiserver.Account.User
    belongs_to :match, Teiserver.Battle.Match
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings([:content])

    struct
    |> cast(params, ~w(content inserted_at match_id user_id)a)
    |> validate_required(~w(content inserted_at user_id)a)
  end

  @spec authorize(atom(), Plug.Conn.t(), map()) :: Boolean.t()
  def authorize(:index, conn, _), do: allow?(conn, "Reviewer")
  def authorize(_, conn, _), do: allow?(conn, "Moderator")
end
