defmodule Teiserver.OAuth.ApplicationQueries do
  use TeiserverWeb, :queries

  alias Teiserver.OAuth.{Application, TokenQueries, CodeQueries, CredentialQueries}
  alias Teiserver.Data.Types, as: T

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

  def application_allows_code?(%Application{} = app) do
    not Enum.empty?(app.redirect_uris)
  end

  def application_allows_code?(id) do
    get_application_by_id(id)
    |> application_allows_code?()
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

  @doc """
  Returns all OAuth applications that the user has authorized (has tokens for, including expired ones).
  """
  @spec list_authorized_applications(T.userid()) :: [Application.t()]
  def list_authorized_applications(user_id) do
    base_query()
    |> join(:left, [app], token in Teiserver.OAuth.Token,
      on: token.application_id == app.id and token.owner_id == ^user_id
    )
    |> where([app, token], not is_nil(token.id))
    |> distinct([app, token], true)
    |> preload(:owner)
    |> Repo.all()
  end

  @doc """
  Returns the count of active tokens for each application that the user has authorized.
  Counts only the user's tokens, not all tokens for the application.
  """
  @spec get_application_token_counts(T.userid()) :: %{
          Application.id() => non_neg_integer()
        }
  def get_application_token_counts(user_id) do
    from(token in Teiserver.OAuth.Token,
      where: token.owner_id == ^user_id,
      where: token.expires_at > ^DateTime.utc_now(),
      group_by: token.application_id,
      select: {token.application_id, count(token.id)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Deletes all tokens (access and refresh) for a specific application and user.
  Returns the count of deleted tokens.
  """
  @spec delete_user_application_tokens(T.userid(), Application.id()) ::
          non_neg_integer()
  def delete_user_application_tokens(user_id, application_id) do
    {count, _} =
      from(token in Teiserver.OAuth.Token,
        where: token.owner_id == ^user_id,
        where: token.application_id == ^application_id
      )
      |> Repo.delete_all()

    count
  end

  @doc """
  Deletes all authorization codes for a specific application and user.
  Returns the count of deleted codes.
  """
  @spec delete_user_application_codes(T.userid(), Application.id()) ::
          non_neg_integer()
  def delete_user_application_codes(user_id, application_id) do
    {count, _} =
      from(code in Teiserver.OAuth.Code,
        where: code.owner_id == ^user_id,
        where: code.application_id == ^application_id
      )
      |> Repo.delete_all()

    count
  end
end
