defmodule Teiserver.OAuth do
  alias Teiserver.Repo
  alias Teiserver.OAuth.{Application, ApplicationQueries}

  def create_application(attrs \\ %{}) do
    %Application{}
    |> Application.changeset(attrs)
    |> Repo.insert()
  end

  @spec get_application_by_uid(Application.app_id()) :: Application.t() | nil
  defdelegate get_application_by_uid(uid), to: ApplicationQueries
end
