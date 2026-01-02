defmodule Teiserver.OAuth.Token do
  @moduledoc false
  use TeiserverWeb, :schema

  alias Teiserver.OAuth

  typed_schema "oauth_tokens" do
    field :value, :string
    belongs_to :owner, Teiserver.Account.User
    belongs_to :application, OAuth.Application, primary_key: true
    field :scopes, {:array, :string}
    field :original_scopes, {:array, :string}
    field :expires_at, :utc_datetime
    field :type, Ecto.Enum, values: [:access, :refresh]
    belongs_to :refresh_token, __MODULE__
    belongs_to :bot, Teiserver.Bot.Bot

    timestamps()
  end

  def changeset(token, attrs) do
    attrs =
      attrs
      |> Map.put_new(:original_scopes, attrs[:scopes])
      |> uniq_lists([:scopes, :original_scopes])

    token
    |> cast(attrs, [
      :value,
      :owner_id,
      :application_id,
      :scopes,
      :original_scopes,
      :expires_at,
      :type,
      :bot_id
    ])
    |> cast_assoc(:refresh_token)
    |> validate_required([:value, :application_id, :scopes, :expires_at, :type])
    |> Ecto.Changeset.validate_subset(:scopes, OAuth.Application.allowed_scopes())
  end
end
