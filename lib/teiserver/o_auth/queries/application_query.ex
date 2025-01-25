defmodule Teiserver.OAuth.ApplicationQueries do
  use TeiserverWeb, :queries

  alias Teiserver.OAuth.{Application, TokenQueries, CodeQueries, CredentialQueries}

  @doc """
  Returns the application corresponding to the given uid/client id
  """
  @spec get_application_by_uid(String.t()) :: Application.t() | nil
  def get_application_by_uid(nil), do: nil

  def get_application_by_uid(uid) do
    base_query() |> where_uid(uid) |> Repo.one()
  end

  @doc """
  Returns the application for the given id
  """
  @spec get_application_by_id(Application.id()) :: Application.t() | nil
  def get_application_by_id(nil), do: nil

  def get_application_by_id(id) do
    try do
      base_query() |> preload(:owner) |> where_id(id) |> Repo.one()
    rescue
      Ecto.Query.CastError -> nil
    end
  end

  @doc """
  Returns all applications.
  We're not supposed to have a ton of them, so it's fine. If/when that changes
  need to add some pagination to that query
  """
  @spec list_applications() :: [Application.t()]
  def list_applications() do
    base_query() |> preload(:owner) |> Repo.all()
  end

  @doc """
  returns the number of authorisation codes, authentication token and
  client credentials for the given applications
  """
  @spec get_stats(Application.id() | [Application.id()]) :: [
          %{
            code_count: non_neg_integer(),
            token_count: non_neg_integer(),
            credential_count: non_neg_integer()
          }
        ]
  def get_stats(app_ids) when not is_list(app_ids), do: get_stats([app_ids])

  def get_stats(app_ids) do
    code_counts = CodeQueries.count_per_apps(app_ids)
    token_counts = TokenQueries.count_per_apps(app_ids)
    cred_counts = CredentialQueries.count_per_apps(app_ids)

    List.foldr(app_ids, [], fn app_id, acc ->
      elem = %{
        code_count: Map.get(code_counts, app_id, 0),
        token_count: Map.get(token_counts, app_id, 0),
        credential_count: Map.get(cred_counts, app_id, 0)
      }

      [elem | acc]
    end)
  end

  def base_query() do
    from app in Application, as: :app
  end

  def where_id(query, id) do
    from [app: app] in query,
      where: app.id == ^id
  end

  def where_uid(query, uid) do
    from [app: app] in query,
      where: app.uid == ^uid
  end

  def join_application(query, name \\ :application) do
    if has_named_binding?(query, :application) do
      query
    else
      from token in query,
        join: app in assoc(token, ^name),
        as: :application
    end
  end
end
