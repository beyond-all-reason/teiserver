defmodule Teiserver.Chat.SpringDirectMessage do
  @moduledoc false
  use TeiserverWeb, :schema

  typed_schema "spring_direct_messages" do
    field :content, :string
    field :inserted_at, :utc_datetime
    belongs_to :from, Teiserver.Account.User
    belongs_to :to, Teiserver.Account.User
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
    |> cast(params, ~w(content inserted_at from_id to_id)a)
    |> validate_required(~w(content inserted_at from_id to_id)a)
  end

  @spec authorize(atom(), Plug.Conn.t(), map()) :: bool()
  def authorize(:index, conn, _params), do: allow?(conn, "Moderator")
end
