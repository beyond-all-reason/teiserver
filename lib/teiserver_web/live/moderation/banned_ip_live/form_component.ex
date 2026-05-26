defmodule TeiserverWeb.Moderation.BannedIPLive.FormComponent do
  @moduledoc false
  alias Teiserver.Moderation

  use TeiserverWeb, :live_component

  @impl LiveComponent
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage banned_ip records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="banned_ip-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:cidr]} type="text" label="Cidr" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Banned ip</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl LiveComponent
  def update(%{banned_ip: banned_ip} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Moderation.change_banned_ip(banned_ip))
     end)}
  end

  @impl LiveComponent
  def handle_event("validate", %{"banned_ip" => banned_ip_params}, socket) do
    changeset = Moderation.change_banned_ip(socket.assigns.banned_ip, banned_ip_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"banned_ip" => banned_ip_params}, socket) do
    save_banned_ip(socket, socket.assigns.action, banned_ip_params)
  end

  defp save_banned_ip(socket, :edit, banned_ip_params) do
    case Moderation.update_banned_ip(socket.assigns.banned_ip, banned_ip_params) do
      {:ok, banned_ip} ->
        notify_parent({:saved, banned_ip})

        {:noreply,
         socket
         |> put_flash(:info, "Banned ip updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_banned_ip(socket, :new, banned_ip_params) do
    case Moderation.create_banned_ip(banned_ip_params) do
      {:ok, banned_ip} ->
        notify_parent({:saved, banned_ip})

        {:noreply,
         socket
         |> put_flash(:info, "Banned ip created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
