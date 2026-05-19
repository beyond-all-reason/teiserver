defmodule Teiserver.OAuth.Token do
  @moduledoc false

  alias Ecto.Changeset
  alias Teiserver.Account
  alias Teiserver.OAuth
  alias Teiserver.OAuth.Libs.ScopeLib

  use TeiserverWeb, :schema

  typed_schema "oauth_tokens" do
    field :value, :string, redact: true
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
    |> Changeset.validate_subset(:scopes, attrs.original_scopes)
    |> Changeset.validate_change(:scopes, fn :scopes, scopes ->
      with owner when not is_nil(owner) <- get_owner(token, attrs),
           :ok <- ScopeLib.all_scopes_allowed?(owner, scopes) do
        []
      else
        # no owner will be caught by the other checks
        nil ->
          []

        {:error, invalid_scopes} ->
          [scopes: "not authorized for scopes #{Enum.join(invalid_scopes, ", ")}"]
      end
    end)
  end

  defp get_owner(_tok, %{owner: %Account.User{} = owner}), do: owner
  defp get_owner(_tok, %{bot: %Teiserver.Bot.Bot{} = bot}), do: bot
  defp get_owner(%__MODULE__{owner: %Account.User{} = owner}, _attrs), do: owner
  defp get_owner(%__MODULE__{bot: %Teiserver.Bot.Bot{} = bot}, _attrs), do: bot
  defp get_owner(_tok, _attrs), do: nil
end
