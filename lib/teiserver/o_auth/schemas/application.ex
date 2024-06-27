defmodule Teiserver.OAuth.Application do
  @moduledoc false
  use TeiserverWeb, :schema
  alias Teiserver.Account.User

  @type app_id() :: String.t()
  @type scopes() :: nonempty_list(String.t())
  @type t :: %__MODULE__{
          name: String.t(),
          owner: User.t(),
          uid: app_id(),
          secret: String.t() | nil,
          scopes: scopes(),
          redirect_uris: [String.t()],
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "oauth_applications" do
    field :name, :string
    belongs_to :owner, Teiserver.Account.User, primary_key: true
    field :uid, :string
    field :secret, :string
    field :scopes, {:array, :string}
    field :redirect_uris, {:array, :string}, default: []
    field :description, :string

    timestamps(type: :utc_datetime)
  end

  def allowed_scopes do
    ~w(tachyon.lobby)
  end

  def changeset(application, attrs) do
    attrs = attrs |> uniq_lists(~w(scopes)a)

    application
    |> cast(attrs, [:name, :owner_id, :uid, :secret, :scopes, :redirect_uris, :description])
    |> validate_required([:name, :owner_id, :uid, :scopes])
    |> Ecto.Changeset.validate_subset(:scopes, allowed_scopes())
  end
end
