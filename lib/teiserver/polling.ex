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

  @spec create_survey() :: {:ok, Teiserver.Polling.Survey.t} | {:error, Ecto.Changeset.t()}
  defdelegate create_survey(), to: SurveyLib

  @spec create_survey(map) :: {:ok, Teiserver.Polling.Survey.t} | {:error, Ecto.Changeset.t()}
  defdelegate create_survey(attrs), to: SurveyLib

  @spec update_survey(Teiserver.Polling.Survey.t, map) :: {:ok, Teiserver.Polling.Survey.t} | {:error, Ecto.Changeset.t()}
  defdelegate update_survey(survey, attrs), to: SurveyLib

  @spec delete_survey(Survey) :: {:ok, Survey} | {:error, Ecto.Changeset.t()}
  defdelegate delete_survey(survey), to: SurveyLib

  @spec change_survey(Survey) :: Ecto.Changeset.t()
  defdelegate change_survey(survey), to: SurveyLib

  @spec change_survey(Survey, map) :: Ecto.Changeset.t()
  defdelegate change_survey(survey, attrs), to: SurveyLib



  # Questions
  alias Teiserver.Polling.QuestionLib

  @spec list_questions() :: [Teiserver.Polling.Question.t]
  defdelegate list_questions(), to: QuestionLib

  @spec list_questions(list) :: [Teiserver.Polling.Question.t]
  defdelegate list_questions(args), to: QuestionLib

  @spec get_question!(non_neg_integer) :: Teiserver.Polling.Question.t
  defdelegate get_question!(id), to: QuestionLib

  @spec get_question!(non_neg_integer, list) :: Teiserver.Polling.Question.t
  defdelegate get_question!(id, args), to: QuestionLib

  @spec create_question() :: {:ok, Teiserver.Polling.Question.t} | {:error, Ecto.Changeset.t()}
  defdelegate create_question(), to: QuestionLib

  @spec create_question(map) :: {:ok, Teiserver.Polling.Question.t} | {:error, Ecto.Changeset.t()}
  defdelegate create_question(attrs), to: QuestionLib

  @spec update_question(Teiserver.Polling.Question.t, map) :: {:ok, Teiserver.Polling.Question.t} | {:error, Ecto.Changeset.t()}
  defdelegate update_question(question, attrs), to: QuestionLib

  @spec delete_question(Question) :: {:ok, Question} | {:error, Ecto.Changeset.t()}
  defdelegate delete_question(question), to: QuestionLib

  @spec change_question(Question) :: Ecto.Changeset.t()
  defdelegate change_question(question), to: QuestionLib

  @spec change_question(Question, map) :: Ecto.Changeset.t()
  defdelegate change_question(question, attrs), to: QuestionLib




  # Responses
  alias Teiserver.Polling.ResponseLib

  @spec list_responses() :: [Teiserver.Polling.Response.t]
  defdelegate list_responses(), to: ResponseLib

  @spec list_responses(list) :: [Teiserver.Polling.Response.t]
  defdelegate list_responses(args), to: ResponseLib

  @spec get_response!(non_neg_integer) :: Teiserver.Polling.Response.t
  defdelegate get_response!(id), to: ResponseLib

  @spec get_response!(non_neg_integer, list) :: Teiserver.Polling.Response.t
  defdelegate get_response!(id, args), to: ResponseLib

  @spec create_response() :: {:ok, Teiserver.Polling.Response.t} | {:error, Ecto.Changeset.t()}
  defdelegate create_response(), to: ResponseLib

  @spec create_response(map) :: {:ok, Teiserver.Polling.Response.t} | {:error, Ecto.Changeset.t()}
  defdelegate create_response(attrs), to: ResponseLib

  @spec update_response(Teiserver.Polling.Response.t, map) :: {:ok, Teiserver.Polling.Response.t} | {:error, Ecto.Changeset.t()}
  defdelegate update_response(response, attrs), to: ResponseLib

  @spec delete_response(Response) :: {:ok, Response} | {:error, Ecto.Changeset.t()}
  defdelegate delete_response(response), to: ResponseLib

  @spec change_response(Response) :: Ecto.Changeset.t()
  defdelegate change_response(response), to: ResponseLib

  @spec change_response(Response, map) :: Ecto.Changeset.t()
  defdelegate change_response(response, attrs), to: ResponseLib



  # AnswerStrings
  alias Teiserver.Polling.AnswerStringLib

  @spec list_answer_strings() :: [Teiserver.Polling.AnswerString.t]
  defdelegate list_answer_strings(), to: AnswerStringLib

  @spec list_answer_strings(list) :: [Teiserver.Polling.AnswerString.t]
  defdelegate list_answer_strings(args), to: AnswerStringLib

  @spec get_answer_string!(non_neg_integer) :: Teiserver.Polling.AnswerString.t
  defdelegate get_answer_string!(id), to: AnswerStringLib

  @spec get_answer_string!(non_neg_integer, list) :: Teiserver.Polling.AnswerString.t
  defdelegate get_answer_string!(id, args), to: AnswerStringLib

  @spec create_answer_string() :: {:ok, Teiserver.Polling.AnswerString.t} | {:error, Ecto.Changeset.t()}
  defdelegate create_answer_string(), to: AnswerStringLib

  @spec create_answer_string(map) :: {:ok, Teiserver.Polling.AnswerString.t} | {:error, Ecto.Changeset.t()}
  defdelegate create_answer_string(attrs), to: AnswerStringLib

  @spec update_answer_string(Teiserver.Polling.AnswerString.t, map) :: {:ok, Teiserver.Polling.AnswerString.t} | {:error, Ecto.Changeset.t()}
  defdelegate update_answer_string(answer_string, attrs), to: AnswerStringLib

  @spec delete_answer_string(AnswerString) :: {:ok, AnswerString} | {:error, Ecto.Changeset.t()}
  defdelegate delete_answer_string(answer_string), to: AnswerStringLib

  @spec change_answer_string(AnswerString) :: Ecto.Changeset.t()
  defdelegate change_answer_string(answer_string), to: AnswerStringLib

  @spec change_answer_string(AnswerString, map) :: Ecto.Changeset.t()
  defdelegate change_answer_string(answer_string, attrs), to: AnswerStringLib




  # AnswerLists
  alias Teiserver.Polling.AnswerListLib

  @spec list_answer_lists() :: [Teiserver.Polling.AnswerList.t]
  defdelegate list_answer_lists(), to: AnswerListLib

  @spec list_answer_lists(list) :: [Teiserver.Polling.AnswerList.t]
  defdelegate list_answer_lists(args), to: AnswerListLib

  @spec get_answer_list!(non_neg_integer) :: Teiserver.Polling.AnswerList.t
  defdelegate get_answer_list!(id), to: AnswerListLib

  @spec get_answer_list!(non_neg_integer, list) :: Teiserver.Polling.AnswerList.t
  defdelegate get_answer_list!(id, args), to: AnswerListLib

  @spec create_answer_list() :: {:ok, Teiserver.Polling.AnswerList.t} | {:error, Ecto.Changeset.t()}
  defdelegate create_answer_list(), to: AnswerListLib

  @spec create_answer_list(map) :: {:ok, Teiserver.Polling.AnswerList.t} | {:error, Ecto.Changeset.t()}
  defdelegate create_answer_list(attrs), to: AnswerListLib

  @spec update_answer_list(Teiserver.Polling.AnswerList.t, map) :: {:ok, Teiserver.Polling.AnswerList.t} | {:error, Ecto.Changeset.t()}
  defdelegate update_answer_list(answer_list, attrs), to: AnswerListLib

  @spec delete_answer_list(AnswerList) :: {:ok, AnswerList} | {:error, Ecto.Changeset.t()}
  defdelegate delete_answer_list(answer_list), to: AnswerListLib

  @spec change_answer_list(AnswerList) :: Ecto.Changeset.t()
  defdelegate change_answer_list(answer_list), to: AnswerListLib

  @spec change_answer_list(AnswerList, map) :: Ecto.Changeset.t()
  defdelegate change_answer_list(answer_list, attrs), to: AnswerListLib
end
