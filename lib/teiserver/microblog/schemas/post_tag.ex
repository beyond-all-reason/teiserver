defmodule Teiserver.Microblog.PostTag do
  @moduledoc false
  use TeiserverWeb, :schema

  @primary_key false
  schema "microblog_post_tags" do
    belongs_to :post, Teiserver.Microblog.Post, primary_key: true
    belongs_to :tag, Teiserver.Microblog.Tag, primary_key: true
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(post_id tag_id)a)
    |> validate_required(~w(post_id tag_id)a)
  end

  @spec authorize(atom, Plug.Conn.t(), map()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
