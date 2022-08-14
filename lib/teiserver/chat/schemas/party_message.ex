defmodule Teiserver.Chat.PartyMessage do
  use CentralWeb, :schema

  schema "teiserver_party_messages" do
    field :content, :string
    field :party_id, :string
    field :inserted_at, :utc_datetime
    belongs_to :user, Central.Account.User
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    params = params
    |> trim_strings(~w(content party_id)a)

    struct
    |> cast(params, ~w(content party_id inserted_at user_id)a)
    |> validate_required(~w(content party_id inserted_at user_id)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(_, conn, _), do: allow?(conn, "chat")
end
