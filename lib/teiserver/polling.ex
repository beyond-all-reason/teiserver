defmodule Teiserver.Polling do
  @moduledoc """
  Main point of usage for the polling system
  """

  @spec colours :: atom
  def colours(), do: :success

  @spec icon :: String.t()
  def icon(), do: "fa-square-poll-vertical"

  # Surveys
  alias Teiserver.Polling.SurveyLib

  @spec list_surveys() :: [Teiserver.Polling.Survey.t]
  defdelegate list_surveys(), to: SurveyLib

  @spec list_surveys(list) :: [Teiserver.Polling.Survey.t]
  defdelegate list_surveys(args), to: SurveyLib

  @spec get_survey!(non_neg_integer) :: Teiserver.Polling.Survey.t
  defdelegate get_survey!(id), to: SurveyLib

  @spec get_survey!(non_neg_integer, list) :: Teiserver.Polling.Survey.t
  defdelegate get_survey!(id, args), to: SurveyLib

  @spec create_survey() :: {:ok, Teiserver.Polling.Survey.t} | {:error, Ecto.Changeset}
  defdelegate create_survey(), to: SurveyLib

  @spec create_survey(map) :: {:ok, Teiserver.Polling.Survey.t} | {:error, Ecto.Changeset}
  defdelegate create_survey(attrs), to: SurveyLib

  @spec update_survey(Teiserver.Polling.Survey.t, map) :: {:ok, Teiserver.Polling.Survey.t} | {:error, Ecto.Changeset}
  defdelegate update_survey(survey, attrs), to: SurveyLib

  @spec delete_survey(Survey) :: {:ok, Survey} | {:error, Ecto.Changeset}
  defdelegate delete_survey(survey), to: SurveyLib

  @spec change_survey(Survey) :: Ecto.Changeset
  defdelegate change_survey(survey), to: SurveyLib

  @spec change_survey(Survey, map) :: Ecto.Changeset
  defdelegate change_survey(survey, attrs), to: SurveyLib
end
