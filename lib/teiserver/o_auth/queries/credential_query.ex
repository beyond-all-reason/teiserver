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
    from credential in query,
      where: credential.client_id == ^client_id
  end
end
