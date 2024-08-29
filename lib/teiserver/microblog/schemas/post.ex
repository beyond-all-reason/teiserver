defmodule Teiserver.Microblog.Post do
  @moduledoc false
  use TeiserverWeb, :schema

  schema "microblog_posts" do
    belongs_to :poster, Teiserver.Account.User

    field :title, :string
    field :summary, :string
    field :contents, :string
    field :view_count, :integer, default: 0

    belongs_to :discord_channel, Teiserver.Communication.DiscordChannel
    field :discord_post_id, :integer

    has_many :post_tags, Teiserver.Microblog.PostTag

    many_to_many :tags, Teiserver.Microblog.Tag,
      join_through: "microblog_post_tags",
      join_keys: [post_id: :id, tag_id: :id]

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    tag_ids =
      params["tags"] ||
        []
        |> Enum.map(fn id -> id end)

    params =
      params
      |> trim_strings(~w(title summary contents)a)

    struct
    |> cast(
      params,
      ~w(poster_id title summary contents view_count discord_channel_id discord_post_id)a
    )
    |> cast_assoc(:post_tags, tag_ids)
    |> validate_required(~w(poster_id title contents)a)
  end

  @spec authorize(atom, Plug.Conn.t(), map()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Contributor")
end
