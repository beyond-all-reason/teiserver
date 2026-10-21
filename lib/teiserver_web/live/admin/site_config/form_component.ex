defmodule TeiserverWeb.AdminLive.SiteConfig.FormComponent do
  @moduledoc false
  alias Teiserver.Account.Scope
  alias Teiserver.Config

  use TeiserverWeb, :live_component

  attr :title, :string, required: true
  attr :action, :string, required: true
  attr :config_type, :map, required: true
  attr :value, :any, required: true
  attr :patch, :string, required: true
  attr :scope, Scope, required: true

  @impl LiveComponent
  def render(assigns) do
    input_type =
      case assigns[:config_type] do
        %{type: "select"} -> "select"
        %{type: "boolean"} -> "checkbox"
        %{type: "string"} -> "text"
        %{type: "integer"} -> "text"
        %{type: "float"} -> "text"
      end

    assigns = assign(assigns, input_type: input_type)

    ~H"""
    <div>
      <.header>
        {@config_type.label}
      </.header>

      <.simple_form
        for={@form}
        id="site_config-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        {@config_type.description}

        <.input_tw
          :if={@input_type == "select"}
          field={@form[:value]}
          type="select"
          label=""
          options={@config_type.opts[:choices]}
        />

        <.input_tw :if={@input_type == "text"} field={@form[:value]} type="text" label="" />

        <.input_tw :if={@input_type == "checkbox"} field={@form[:value]} type="checkbox" label="" />

        <:actions>
          <div class="flex">
            <.button
              phx-disable-with="Saving..."
              class="float-right btn btn-primary"
            >
              Save changes
            </.button>
          </div>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl LiveComponent
  def update(%{config_type: _config_type, config_value: config_value} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:form, fn ->
      to_form(%{"value" => config_value})
    end)
    |> ok()
  end

  @impl LiveComponent
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save", %{"value" => value}, socket) do
    %{config_type: config_type, config_value: old_value, scope: scope, patch: patch} =
      socket.assigns

    result =
      Repo.transact(fn ->
        with true <- allow?(scope, config_type.permissions),
             :ok <- Config.update_site_config(config_type.key, value),
             %{} <-
               add_audit_log(scope, "Update SiteConfig", %{
                 key: config_type.key,
                 old_value: old_value,
                 new_value: value
               }) do
          {:ok, {config_type.key, value}}
        end
      end)

    case result do
      {:ok, updated_site_config} ->
        notify_parent({:saved, updated_site_config})

        socket
        |> put_flash(:info, "Site config updated successfully")
        |> push_patch(to: patch)
        |> noreply()

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
