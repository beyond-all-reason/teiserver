defmodule Central.Communication.Comment do
  use CentralWeb, :schema

  schema "communication_comments" do
    field :content, :string
    field :poster_name, :string

    field :approved, :boolean, default: true

    belongs_to :post, Central.Communication.Post
    belongs_to :poster, Central.Account.User

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:content, :approved, :post_id, :poster_id, :poster_name])
    |> validate_required([:content, :approved, :post_id])
  end

  def authorize(_, conn, _), do: allow?(conn, "communication.blog")
end
