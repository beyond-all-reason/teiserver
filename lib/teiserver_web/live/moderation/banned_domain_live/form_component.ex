defmodule TeiserverWeb.Moderation.BannedDomainLive.FormComponent do
  @moduledoc false
  alias Teiserver.Moderation

  use TeiserverWeb, :live_component

  @impl LiveComponent
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage banned_domain records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="banned_domain-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:domain]} type="text" label="Domain" />
        <:actions>
          <.button phx-disable-with="Saving...">Save banned domain</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl LiveComponent
  def update(%{banned_domain: banned_domain} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Moderation.change_banned_domain(banned_domain))
     end)}
  end

  @impl LiveComponent
  def handle_event("validate", %{"banned_domain" => banned_domain_params}, socket) do
    changeset =
      Moderation.change_banned_domain(socket.assigns.banned_domain, banned_domain_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"banned_domain" => banned_domain_params}, socket) do
    save_banned_domain(socket, socket.assigns.action, banned_domain_params)
  end

  defp save_banned_domain(socket, :edit, banned_domain_params) do
    case Moderation.update_banned_domain(socket.assigns.banned_domain, banned_domain_params) do
      {:ok, banned_domain} ->
        notify_parent({:saved, banned_domain})

        {:noreply,
         socket
         |> put_flash(:info, "Banned domain updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_banned_domain(socket, :new, banned_domain_params) do
    case Moderation.create_banned_domain(banned_domain_params) do
      {:ok, banned_domain} ->
        notify_parent({:saved, banned_domain})

        {:noreply,
         socket
         |> put_flash(:info, "Banned domain created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
