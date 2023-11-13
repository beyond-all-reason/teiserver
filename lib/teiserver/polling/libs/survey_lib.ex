defmodule Teiserver.Polling.SurveyLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  alias Teiserver.Polling.{Survey, SurveyQueries}
  alias Phoenix.PubSub

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-circle-envelope"

  @spec colours :: atom
  def colours, do: :primary

  @doc """
  Returns the list of surveys.

  ## Examples

      iex> list_surveys()
      [%Survey{}, ...]

  """
  @spec list_surveys(list) :: [Survey]
  def list_surveys(args \\ []) do
    args
    |> SurveyQueries.query_surveys()
    |> Repo.all()
  end

  @doc """
  Gets a single survey.

  Raises `Ecto.NoResultsError` if the Survey does not exist.

  ## Examples

      iex> get_survey!(123)
      %Survey{}

      iex> get_survey!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_survey!(non_neg_integer()) :: Survey.t
  def get_survey!(survey_id) do
    [id: survey_id]
    |> SurveyQueries.query_surveys()
    |> Repo.one!()
  end

  @spec get_survey!(non_neg_integer(), list) :: Survey.t
  def get_survey!(survey_id, args) do
    ([id: survey_id] ++ args)
    |> SurveyQueries.query_surveys()
    |> Repo.one!()
  end

  @spec get_survey(non_neg_integer()) :: Survey.t | nil
  def get_survey(survey_id) do
    [id: survey_id]
    |> SurveyQueries.query_surveys()
    |> Repo.one()
  end

  @spec get_survey(non_neg_integer(), list) :: Survey.t | nil
  def get_survey(survey_id, args) do
    ([id: survey_id] ++ args)
    |> SurveyQueries.query_surveys()
    |> Repo.one()
  end

  @doc """
  Creates a survey.

  ## Examples

      iex> create_survey(%{field: value})
      {:ok, %Survey{}}

      iex> create_survey(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_survey(attrs \\ %{}) do
    %Survey{}
    |> Survey.changeset(attrs)
    |> Repo.insert()
    |> broadcast_create_survey
  end

  defp broadcast_create_survey({:ok, %Survey{} = survey}) do
    spawn(fn ->
      # We sleep this because sometimes the message is seen fast enough the database doesn't
      # show as having the new data (row lock maybe?)
      :timer.sleep(1000)
      PubSub.broadcast(
        Teiserver.PubSub,
        "polling_surveys",
        %{
          channel: "polling_surveys",
          event: :survey_created,
          survey: survey
        }
      )
    end)

    {:ok, survey}
  end

  defp broadcast_create_survey(value), do: value

  @doc """
  Updates a survey.

  ## Examples

      iex> update_survey(survey, %{field: new_value})
      {:ok, %Survey{}}

      iex> update_survey(survey, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_survey(%Survey{} = survey, attrs) do
    survey
    |> Survey.changeset(attrs)
    |> Repo.update()
    |> broadcast_update_survey
  end

  defp broadcast_update_survey({:ok, %Survey{} = survey}) do
    spawn(fn ->
      # We sleep this because sometimes the message is seen fast enough the database doesn't
      # show as having the new data (row lock maybe?)
      :timer.sleep(1000)
      PubSub.broadcast(
        Teiserver.PubSub,
        "polling_surveys",
        %{
          channel: "polling_surveys",
          event: :survey_updated,
          survey: survey
        }
      )
    end)

    {:ok, survey}
  end

  defp broadcast_update_survey(value), do: value

  @doc """
  Deletes a survey.

  ## Examples

      iex> delete_survey(survey)
      {:ok, %Survey{}}

      iex> delete_survey(survey)
      {:error, %Ecto.Changeset{}}

  """
  def delete_survey(%Survey{} = survey) do
    Repo.delete(survey)
    |> broadcast_delete_survey
  end

  defp broadcast_delete_survey({:ok, %Survey{} = survey}) do
    PubSub.broadcast(
      Teiserver.PubSub,
      "polling_surveys",
      %{
        channel: "polling_surveys",
        event: :survey_deleted,
        survey: survey
      }
    )

    {:ok, survey}
  end

  defp broadcast_delete_survey(value), do: value

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking survey changes.

  ## Examples

      iex> change_survey(survey)
      %Ecto.Changeset{data: %Survey{}}

  """
  def change_survey(%Survey{} = survey, attrs \\ %{}) do
    Survey.changeset(survey, attrs)
  end
end
