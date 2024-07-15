defmodule Teiserver.OAuth.CredentialQueries do
  use TeiserverWeb, :queries
  alias Teiserver.OAuth.Credential

  def get_credential(nil), do: nil

  def get_credential(client_id) do
    base_query()
    |> preload(:application)
    |> where_client_id(client_id)
    |> Repo.one()
  end

  def base_query() do
    from credential in Credential,
      as: :credential
  end

  def where_client_id(query, client_id) do
    from [credential: credential] in query,
      where: credential.client_id == ^client_id
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
end
