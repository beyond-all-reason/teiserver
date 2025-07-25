defmodule Teiserver.OAuth.Application do
  @moduledoc false
  use TeiserverWeb, :schema
  alias Teiserver.Account.User

  @type id() :: non_neg_integer()
  @type app_id() :: String.t()
  @type scopes() :: nonempty_list(String.t())
  @type t :: %__MODULE__{
          name: String.t(),
          owner: User.t(),
          uid: app_id(),
          scopes: scopes(),
          redirect_uris: [String.t()],
          description: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "oauth_applications" do
    field :name, :string
    belongs_to :owner, Teiserver.Account.User, primary_key: true
    field :uid, :string
    field :scopes, {:array, :string}
    field :redirect_uris, {:array, :string}, default: []
    field :description, :string

    timestamps(type: :utc_datetime)
  end

  def allowed_scopes do
    ["tachyon.lobby", "admin.map", "admin.engine", "admin.user"]
  end

  def changeset(application, attrs) do
    attrs = attrs |> uniq_lists(~w(scopes)a)

    application
    |> cast(attrs, [:name, :owner_id, :uid, :scopes, :redirect_uris, :description])
    |> validate_required([:name, :owner_id, :uid, :scopes])
    |> Ecto.Changeset.validate_change(:redirect_uris, fn :redirect_uris, uris ->
      invalid_uris = Enum.filter(uris, fn uri -> is_nil(URI.parse(uri).host) end)

      if Enum.empty?(invalid_uris) do
        []
      else
        [redirect_uris: "invalid uri found: #{Enum.join(invalid_uris, ", ")}"]
      end
    end)
    |> Ecto.Changeset.unique_constraint(:uid)
    |> Ecto.Changeset.validate_subset(:scopes, allowed_scopes(),
      message: "Must a subset of #{Enum.join(allowed_scopes(), ", ")}"
    )
    |> Ecto.Changeset.validate_length(:scopes, min: 1)
  end
end
