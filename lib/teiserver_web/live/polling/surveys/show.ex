defmodule TeiserverWeb.Polling.SurveyLive.Show do
  use TeiserverWeb, :live_view

  alias Teiserver.Polling

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"survey_id" => id}, _, socket) do
    if allow?(socket.assigns[:current_user], "Polling") do
      survey = Polling.get_survey!(id,
        preload: [:questions]
      )

      {:noreply,
        socket
        |> assign(:page_title, page_title(socket.assigns.live_action))
        |> assign(:survey, survey)
        |> assign(:view_colour, Polling.SurveyLib.colours())
        |> add_breadcrumb(name: "Polling", url: ~p"/polling")
        |> add_breadcrumb(name: "Surveys", url: ~p"/polling/surveys")
        |> add_breadcrumb(name: "Survey: #{survey.name}", url: "#")
      }
    else
      {:noreply,
        socket
        |> redirect(to: ~p"/polling")}
    end
  end

  def handle_params(_, _, socket) do
    if allow?(socket.assigns[:current_user], "Polling") do
      {:noreply,
        socket
        |> assign(:page_title, page_title(socket.assigns.live_action))
        |> assign(:survey, %Teiserver.Polling.Survey{
          author_id: socket.assigns.current_user.id,
          icon: Teiserver.Helper.StylingHelper.random_icon(),
          colour: Teiserver.Helper.StylingHelper.random_colour()
        })
        |> assign(:view_colour, Polling.SurveyLib.colours())
        |> add_breadcrumb(name: "Polling", url: ~p"/polling")
        |> add_breadcrumb(name: "Surveys", url: ~p"/polling/surveys")
        |> add_breadcrumb(name: page_title(socket.assigns.live_action), url: ~p"/polling/surveys/new")
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
