defmodule Teiserver.Microblog.Upload do
  @moduledoc false
  use TeiserverWeb, :schema

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "microblog_uploads" do
    belongs_to :uploader, Teiserver.Account.User

    field :filename, :string
    field :type, :string
    field :file_size, :integer

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(uploader_id filename type file_size)a
  @optional_fields ~w()a

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(Map.t(), Map.t()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
