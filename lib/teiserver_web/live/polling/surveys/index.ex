defmodule TeiserverWeb.Polling.SurveyLive.Index do
@moduledoc false
  require TeiserverWeb.Polling.SurveyLive.Index
  use TeiserverWeb, :live_view
  alias Teiserver.Polling
  import TeiserverWeb.PollingComponents

  @impl true
  def mount(_params, _session, socket) when is_connected?(socket) do
    surveys = Polling.list_surveys(
      where: [],
      order_by: ["Name (A-Z)"]
    )

    {:ok,
      socket
      |> assign(:surveys, surveys)
    }
  end

  def mount(_params, _session, socket) do
    {:ok,
      socket
      |> assign(:surveys, [])
    }
  end

  @impl true
  def handle_params(params, _url, socket) do
    case allow?(socket.assigns[:current_user], "Polling") do
      true ->
        {:noreply, apply_action(socket, socket.assigns.live_action, params)}

      false ->
        {:noreply,
         socket
         |> redirect(to: ~p"/polling")}
    end
  end

  defp apply_action(socket, _action, _params) do
    socket
    |> assign(:page_title, "Polling admin page")
    |> assign(:post, %{})
    |> assign(:site_menu_active, "polling")
    |> assign(:view_colour, Polling.SurveyLib.colours())
    |> add_breadcrumb(name: "Polling", url: ~p"/polling")
    |> add_breadcrumb(name: "Surveys", url: ~p"/polling/surveys")
  end

  @impl true
  def handle_info({TeiserverWeb.Polling.SurveyFormComponent, {:saved, _post}}, socket) do
    {:noreply, socket
      |> put_flash(:info, "Post created successfully")
      |> redirect(to: ~p"/polling")
    }
  end

  def handle_info({TeiserverWeb.Polling.SurveyFormComponent, {:updated_changeset, %{changes: post}}}, socket) do
    {:noreply, socket
      |> assign(:post, post)
    }
  end
end
