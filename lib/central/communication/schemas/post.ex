defmodule Central.Communication.Post do
  @moduledoc false
  use CentralWeb, :schema

  schema "communication_posts" do
    field :url_slug, :string
    field :title, :string
    field :content, :string
    field :short_content, :string

    field :live_from, :utc_datetime
    field :allow_comments, :boolean, default: false

    field :tags, {:array, :string}

    field :visible, :boolean, default: false

    belongs_to :category, Central.Communication.Category
    belongs_to :poster, Central.Account.User

    has_many :comments, Central.Communication.Comment

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    params =
      params
      |> parse_humantimes([:live_from])
      |> safe_strings([:url_slug])
      |> parse_checkboxes([:visible, :allow_comments])

    struct
    |> cast(params, [
      :title,
      :url_slug,
      :content,
      :short_content,
      :live_from,
      :allow_comments,
      :visible,
      :category_id,
      :poster_id,
      :tags
    ])
    |> validate_required([
      :title,
      :url_slug,
      :content,
      :short_content,
      :allow_comments,
      :visible,
      :category_id,
      :poster_id,
      :tags
    ])
  end

  def authorize(_, conn, _), do: allow?(conn, "communication.blog")
end
