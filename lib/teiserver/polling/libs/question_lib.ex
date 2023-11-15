defmodule Teiserver.Polling.QuestionLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  alias Teiserver.Polling.{Question, QuestionQueries}
  alias Phoenix.PubSub

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-question"

  @spec colours :: atom
  def colours, do: :primary2

  @spec question_types() :: [String.t()]
  def question_types() do
    [
      "string",
      "integer",
      "dropdown",
      "radio",
      "checkbox",
      "date",
      "time",
      "datetime",
    ]
  end

  @doc """
  Returns the list of questions.

  ## Examples

      iex> list_questions()
      [%Question{}, ...]

  """
  @spec list_questions(list) :: [Question]
  def list_questions(args \\ []) do
    args
    |> QuestionQueries.query_questions()
    |> Repo.all()
  end

  @doc """
  Gets a single question.

  Raises `Ecto.NoResultsError` if the Question does not exist.

  ## Examples

      iex> get_question!(123)
      %Question{}

      iex> get_question!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_question!(non_neg_integer()) :: Question.t
  def get_question!(question_id) do
    [id: question_id]
    |> QuestionQueries.query_questions()
    |> Repo.one!()
  end

  @spec get_question!(non_neg_integer(), list) :: Question.t
  def get_question!(question_id, args) do
    ([id: question_id] ++ args)
    |> QuestionQueries.query_questions()
    |> Repo.one!()
  end

  @spec get_question(non_neg_integer()) :: Question.t | nil
  def get_question(question_id) do
    [id: question_id]
    |> QuestionQueries.query_questions()
    |> Repo.one()
  end

  @spec get_question(non_neg_integer(), list) :: Question.t | nil
  def get_question(question_id, args) do
    ([id: question_id] ++ args)
    |> QuestionQueries.query_questions()
    |> Repo.one()
  end

  @doc """
  Creates a question.

  ## Examples

      iex> create_question(%{field: value})
      {:ok, %Question{}}

      iex> create_question(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_question(attrs \\ %{}) do
    %Question{}
    |> Question.changeset(attrs)
    |> Repo.insert()
    |> broadcast_create_question
  end

  defp broadcast_create_question({:ok, %Question{} = question}) do
    spawn(fn ->
      # We sleep this because sometimes the message is seen fast enough the database doesn't
      # show as having the new data (row lock maybe?)
      :timer.sleep(1000)
      PubSub.broadcast(
        Teiserver.PubSub,
        "polling_questions",
        %{
          channel: "polling_questions",
          event: :question_created,
          question: question
        }
      )
    end)

    {:ok, question}
  end

  defp broadcast_create_question(value), do: value

  @doc """
  Updates a question.

  ## Examples

      iex> update_question(question, %{field: new_value})
      {:ok, %Question{}}

      iex> update_question(question, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_question(%Question{} = question, attrs) do
    question
    |> Question.changeset(attrs)
    |> Repo.update()
    |> broadcast_update_question
  end

  defp broadcast_update_question({:ok, %Question{} = question}) do
    spawn(fn ->
      # We sleep this because sometimes the message is seen fast enough the database doesn't
      # show as having the new data (row lock maybe?)
      :timer.sleep(1000)
      PubSub.broadcast(
        Teiserver.PubSub,
        "polling_questions",
        %{
          channel: "polling_questions",
          event: :question_updated,
          question: question
        }
      )
    end)

    {:ok, question}
  end

  defp broadcast_update_question(value), do: value

  @doc """
  Deletes a question.

  ## Examples

      iex> delete_question(question)
      {:ok, %Question{}}

      iex> delete_question(question)
      {:error, %Ecto.Changeset{}}

  """
  def delete_question(%Question{} = question) do
    Repo.delete(question)
    |> broadcast_delete_question
  end

  defp broadcast_delete_question({:ok, %Question{} = question}) do
    PubSub.broadcast(
      Teiserver.PubSub,
      "polling_questions",
      %{
        channel: "polling_questions",
        event: :question_deleted,
        question: question
      }
    )

    {:ok, question}
  end

  defp broadcast_delete_question(value), do: value

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking question changes.

  ## Examples

      iex> change_question(question)
      %Ecto.Changeset{data: %Question{}}

  """
  def change_question(%Question{} = question, attrs \\ %{}) do
    Question.changeset(question, attrs)
  end
end
