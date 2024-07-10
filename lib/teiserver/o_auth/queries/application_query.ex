defmodule Teiserver.OAuth.ApplicationQueries do
  use TeiserverWeb, :queries

  alias Teiserver.OAuth.Application

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
  @spec get_application_by_id(String.t()) :: Application.t() | nil
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

  def base_query() do
    from app in Application, as: :app
  end

  def where_id(query, id) do
    from e in query,
      where: e.id == ^id
  end

  def where_uid(query, uid) do
    from e in query,
      where: e.uid == ^uid
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
