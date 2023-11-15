defmodule TeiserverWeb.Polling.QuestionFormComponent do
  @moduledoc false
  use TeiserverWeb, :live_component
  import Teiserver.Helper.ColourHelper, only: [rgba_css: 2]

  alias Teiserver.{Polling, Account}
  alias Teiserver.Polling.QuestionLib
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
        id="question-form"
      >
        <div class="row mb-4">
          <div class="col">
            <label for="question_label" class="control-label">Label:</label>
            <.input
              field={@form[:label]}
              type="text"
              autofocus="autofocus"
              phx-debounce="100"
            />
          </div>

          <div class="col">
            <label for="question_description" class="control-label">Description:</label>
            <.input
              field={@form[:description]}
              type="text"
              phx-debounce="100"
            />
          </div>

          <div class="col">
            <label for="question_question_type" class="control-label">Type</label>
            <.input
              field={@form[:question_type]}
              type="select"
              options={for n <- QuestionLib.question_types(), do: {String.capitalize(n), n}}
              phx-debounce="100"
            />
          </div>
        </div>

        <div class="row mb-4">
          <div class="col">
            <label for="question_page" class="control-label">Page number:</label>
            <.input
              field={@form[:page]}
              type="text"
              phx-debounce="100"
            />
          </div>

          <div class="col">
            <label for="question_ordering" class="control-label">Ordering</label>
            <.input
              field={@form[:ordering]}
              type="text"
              phx-debounce="100"
            />
          </div>

          <div class="col" :if={has_choices?(@form[:question_type])}>
            <label for="question_choices" class="control-label">Choices:</label> (One per line)
            <.input
              field={@form[:choices]}
              type="textarea"
              rows="8"
              phx-debounce="100"
            />
          </div>
        </div>

        <% disabled = if not @form.source.valid?, do: "disabled" %>
        <%= if @question.id do %>
          <div class="row">
            <div class="col">
              <a href={~p"/polling/surveys/#{@survey.id}/question/#{@question.id}"} class="btn btn-secondary btn-block">
                Cancel
              </a>
            </div>
            <div class="col">
              <%= submit("Update question", class: "btn btn-primary btn-block #{disabled}") %>
            </div>
          </div>
        <% else %>
          <%= submit("Create question", class: "btn btn-primary btn-block #{disabled}") %>
        <% end %>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{question: question} = assigns, socket) do
    changeset = Polling.change_question(question)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"question" => question_params}, socket) do
    question_params = Map.merge(question_params, %{
      "survey_id" => socket.assigns.survey.id
    })

    changeset =
      socket.assigns.question
      |> Polling.change_question(question_params)
      |> Map.put(:action, :validate)

    notify_parent({:updated_changeset, changeset})

    {:noreply, socket
      |> assign_form(changeset)
    }
  end

  def handle_event("save", %{"question" => question_params}, socket) do
    save_question(socket, socket.assigns.action, question_params)
  end

  defp save_question(socket, :edit, question_params) do
    question_params = convert_form_params(question_params)
    case Polling.update_question(socket.assigns.question, question_params) do
      {:ok, question} ->
        notify_parent({:saved, question})

        {:noreply,
         socket
         |> put_flash(:info, "Survey updated successfully")
         |> redirect(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_question(socket, :new, question_params) do
    question_params = convert_form_params(question_params)
    question_params = Map.merge(question_params, %{
      "survey_id" => socket.assigns.survey.id
    })

    case Polling.create_question(question_params) do
      {:ok, question} ->
        notify_parent({:saved, question})

        {:noreply,
         socket
         |> put_flash(:info, "Survey created successfully")
         |> redirect(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp convert_form_params(params) do
    options = %{
      "choices" => params["choices"]
    }

    Map.put(params, "options", options)
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp has_choices?(type_field) do
    case type_field.value do
      "dropdown" -> true
      "radio" -> true
      "checkbox" -> true
      _ -> false
    end
    true
  end
end
