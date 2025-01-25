defmodule Teiserver.OAuth.Credential do
  @moduledoc false
  use TeiserverWeb, :schema

  alias Teiserver.OAuth

  @type id :: non_neg_integer()
  @type t :: %__MODULE__{
          application: OAuth.Application.t(),
          autohost: Teiserver.Bot.Bot.t(),
          autohost_id: Teiserver.Bot.id(),
          hashed_secret: binary()
        }

  schema "oauth_credentials" do
    belongs_to :application, OAuth.Application
    belongs_to :autohost, Teiserver.Bot.Bot, primary_key: true
    field :client_id, :string
    field :hashed_secret, :binary

    timestamps(type: :utc_datetime)
  end

  def changeset(credential, attrs) do
    credential
    |> cast(attrs, [:application_id, :autohost_id, :client_id, :hashed_secret])
    |> validate_required([:client_id, :hashed_secret])
  end
end
