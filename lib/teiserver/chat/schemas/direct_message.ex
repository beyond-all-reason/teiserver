defmodule Teiserver.Chat.DirectMessage do
  @moduledoc false
  use CentralWeb, :schema

  schema "direct_messages" do
    field :content, :string
    field :inserted_at, :utc_datetime
    field :delivered, :boolean, default: false
    belongs_to :from, Central.Account.User
    belongs_to :to, Central.Account.User
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
    |> cast(params, ~w(content inserted_at from_id to_id delivered)a)
    |> validate_required(~w(content inserted_at from_id to_id delivered)a)
  end

  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(:index, conn, _), do: allow?(conn, "Moderator")
end
