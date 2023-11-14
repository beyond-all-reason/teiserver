defmodule TeiserverWeb.Polling.SurveyLive.Question do
  use TeiserverWeb, :live_view

  alias Teiserver.Polling

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"survey_id" => survey_id, "question_id" => question_id}, _, socket) do
    if allow?(socket.assigns[:current_user], "Polling") do
      survey = Polling.get_survey!(survey_id)
      question = Polling.get_question!(question_id)

      {:noreply,
        socket
        |> assign(:page_title, page_title(socket.assigns.live_action))
        |> assign(:survey, survey)
        |> assign(:question, question)
        |> assign(:view_colour, Polling.QuestionLib.colours())
        |> add_breadcrumb(name: "Polling", url: ~p"/polling")
        |> add_breadcrumb(name: "Surveys", url: ~p"/polling/surveys")
        |> add_breadcrumb(name: "#{survey.name}", url: ~p"/polling/surveys/#{survey_id}")
        |> add_breadcrumb(name: "Question: #{question.label}", url: "#")
      }
    else
      {:noreply,
        socket
        |> redirect(to: ~p"/polling")}
    end
  end

  def handle_params(%{"survey_id" => survey_id}, _, socket) do
    if allow?(socket.assigns[:current_user], "Polling") do
      survey = Polling.get_survey!(survey_id)

      {:noreply,
        socket
        |> assign(:page_title, page_title(socket.assigns.live_action))
        |> assign(:survey, survey)
        |> assign(:question, %Teiserver.Polling.Question{
          survey_id: survey.id,
          page: 1,
          ordering: 1
        })
        |> assign(:view_colour, Polling.QuestionLib.colours())
        |> add_breadcrumb(name: "Polling", url: ~p"/polling")
        |> add_breadcrumb(name: "Surveys", url: ~p"/polling/surveys")
        |> add_breadcrumb(name: "#{survey.name}", url: ~p"/polling/surveys/#{survey_id}")
        |> add_breadcrumb(name: "New question", url: "#")
      }
    else
      {:noreply,
        socket
        |> redirect(to: ~p"/polling")}
    end
  end

  defp page_title(:new), do: "New Survey"
  defp page_title(:show), do: "Show Survey"
  defp page_title(:edit), do: "Edit Survey"
end
