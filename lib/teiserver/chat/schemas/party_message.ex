defmodule Teiserver.Chat.PartyMessage do
  use TeiserverWeb, :schema

  typed_schema "teiserver_party_messages" do
    field :content, :string
    field :party_id, :string
    field :inserted_at, :utc_datetime
    belongs_to :user, Teiserver.Account.User
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> trim_strings(~w(content party_id)a)

    struct
    |> cast(params, ~w(content party_id inserted_at user_id)a)
    |> validate_required(~w(content party_id inserted_at user_id)a)
  end

  @spec authorize(atom(), Plug.Conn.t(), map()) :: bool()
  def authorize(_, conn, _), do: allow?(conn, "chat")
end
