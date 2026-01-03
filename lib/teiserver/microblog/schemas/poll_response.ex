defmodule Teiserver.Microblog.PollResponse do
  @moduledoc false
  use TeiserverWeb, :schema

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  typed_schema "microblog_poll_responses" do
    belongs_to :post, Teiserver.Microblog.Post
    belongs_to :user, Teiserver.Account.User

    field :response, :string

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(post_id response)a
  @optional_fields ~w(user_id)a

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
