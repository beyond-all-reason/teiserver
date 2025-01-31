defmodule Teiserver.OAuth.CredentialQueries do
  use TeiserverWeb, :queries
  alias Teiserver.OAuth.{Credential, Application}
  alias Teiserver.Bot.Bot

  def get_credential(nil), do: nil

  def get_credential(client_id) do
    base_query()
    |> preload(:application)
    |> where_client_id(client_id)
    |> Repo.one()
  end

  def get_credential_by_id(nil), do: nil

  def get_credential_by_id(id) do
    base_query()
    |> preload(:application)
    |> where_id(id)
    |> Repo.one()
  end

  @spec for_bot(Bot.t() | Bot.id()) :: [
          Credential.t()
        ]
  def for_bot(%Bot{} = bot) do
    for_bot(bot.id)
  end

  def for_bot(bot_id) do
    base_query() |> preload(:application) |> where_bot_id(bot_id) |> Repo.all()
  end

  @spec count_per_bots([Bot.id()]) :: %{Bot.id() => non_neg_integer()}
  def count_per_bots(bot_ids) do
    query =
      base_query()
      |> where_bot_ids(bot_ids)

    from([credential: credential] in query,
      group_by: credential.bot_id,
      select: {credential.bot_id, count(credential.id)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  def base_query() do
    from credential in Credential,
      as: :credential
  end

  def where_client_id(query, client_id) do
    from [credential: credential] in query,
      where: credential.client_id == ^client_id
  end

  def where_id(query, cred_id) do
    from [credential: credential] in query,
      where: credential.id == ^cred_id
  end

  @spec count_per_apps([Application.id()]) :: %{Application.id() => non_neg_integer()}
  def count_per_apps(app_ids) do
    query =
      base_query()
      |> where_app_ids(app_ids)

    from([credential: credential] in query,
      group_by: credential.application_id,
      select: {credential.application_id, count(credential.id)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  def where_app_ids(query, app_ids) do
    from [credential: credential] in query,
      where: credential.application_id in ^app_ids
  end

  def where_bot_id(query, bot_id) do
    from [credential: credential] in query,
      where: credential.bot_id == ^bot_id
  end

  def where_bot_ids(query, bot_ids) do
    from [credential: credential] in query,
      where: credential.bot_id in ^bot_ids
  end
end
