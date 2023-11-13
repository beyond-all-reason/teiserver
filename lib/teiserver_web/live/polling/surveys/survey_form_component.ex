defmodule TeiserverWeb.Polling.SurveyFormComponent do
  @moduledoc false
  use TeiserverWeb, :live_component
  import Teiserver.Helper.ColourHelper, only: [rgba_css: 2]

  alias Teiserver.{Polling, Account}
  alias Teiserver.Account.AuthLib

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h3>
        <%= @title %>
      </h3>

      <.form for={@form}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        id="survey-form"
      >
        <div class="row mb-4">
          <div class="col-md-12 col-lg-6 col-xl-4">
            <label for="survey_name" class="control-label">Name:</label>
            <.input
              field={@form[:name]}
              type="text"
              autofocus="autofocus"
              phx-debounce="100"
            />
          </div>

          <div class="col">
            <label for="survey_colour" class="control-label">Colour</label>
            <.input
              field={@form[:colour]}
              type="color"
              phx-debounce="100"
            />
          </div>

          <div class="col">
            <label for="survey_icon" class="control-label">Icon</label>
            <Fontawesome.icon icon={@form[:icon].value} style="solid" />
            <.input
              field={@form[:icon]}
              type="text"
              phx-debounce="100"
            />
          </div>
        </div>

        <div class="row mb-4">
          <div class="col-md-12 col-lg-6 col-xl-4">
            <label for="survey_opens_at" class="control-label">Opens:</label>
            <.input
              field={@form[:opens_at]}
              type="datetime-local"
              phx-debounce="100"
            />
          </div>

          <div class="col-md-12 col-lg-6 col-xl-4">
            <label for="survey_closes_at" class="control-label">Closes:</label>
            <.input
              field={@form[:closes_at]}
              type="datetime-local"
              phx-debounce="100"
            />
          </div>
        </div>

        <div class="row mb-4">
          <div class="col-md-12 col-lg-4">
            <label for="survey_user_permission" class="control-label">User permission:</label>
            <.input
              field={@form[:user_permission]}
              type="text"
              phx-debounce="100"
            />
          </div>

          <div class="col-md-12 col-lg-4">
            <label for="survey_results_permission" class="control-label">Results permission:</label>
            <.input
              field={@form[:results_permission]}
              type="text"
              phx-debounce="100"
            />
          </div>

          <div class="col-md-12 col-lg-4">
            <label for="survey_edit_permission" class="control-label">Edit permission:</label>
            <.input
              field={@form[:edit_permission]}
              type="text"
              phx-debounce="100"
            />
          </div>
        </div>

        <% disabled = if not @form.source.valid?, do: "disabled" %>
        <%= if @survey.id do %>
          <div class="row">
            <div class="col">
              <a href={~p"/microblog/show/#{@survey.id}"} class="btn btn-secondary btn-block">
                Cancel
              </a>
            </div>
            <div class="col">
              <%= submit("Update survey", class: "btn btn-primary btn-block #{disabled}") %>
            </div>
          </div>
        <% else %>
          <%= submit("Survey", class: "btn btn-primary btn-block #{disabled}") %>
        <% end %>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{survey: survey} = assigns, socket) do
    changeset = Polling.change_survey(survey)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"survey" => survey_params}, socket) do
    survey_params = Map.merge(survey_params, %{
      "author_id" => socket.assigns.current_user.id
    })

    changeset =
      socket.assigns.survey
      |> Polling.change_survey(survey_params)
      |> Map.put(:action, :validate)

    notify_parent({:updated_changeset, changeset})

    {:noreply, socket
      |> assign_form(changeset)
    }
  end

  def handle_event("save", %{"survey" => survey_params}, socket) do
    save_survey(socket, socket.assigns.action, survey_params)
  end

  defp save_survey(socket, :edit, survey_params) do
    case Polling.update_survey(socket.assigns.survey, survey_params) do
      {:ok, survey} ->
        notify_parent({:saved, survey})

        {:noreply,
         socket
         |> put_flash(:info, "Survey updated successfully")
         |> redirect(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_survey(socket, :new, survey_params) do
    survey_params = Map.merge(survey_params, %{
      "author_id" => socket.assigns.current_user.id
    })

    case Polling.create_survey(survey_params) do
      {:ok, survey} ->
        notify_parent({:saved, survey})

        {:noreply,
         socket
         |> put_flash(:info, "Survey created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
