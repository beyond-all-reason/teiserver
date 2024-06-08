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

  def base_query() do
    from app in Application, as: :app
  end

  def where_uid(query, uid) do
    from e in query,
      where: e.uid == ^uid
  end
end
