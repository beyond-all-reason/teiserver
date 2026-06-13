defmodule TeiserverWeb.Moderation.BannedDomainLive.Form do
  @moduledoc false
  alias Teiserver.Moderation
  alias Teiserver.Moderation.BannedDomain

  use TeiserverWeb, :live_view

  @impl LiveView
  def render(assigns) do
    ~H"""
    <div class="w-full max-w-3xl mx-auto px-4 py-8">
      <div class="mb-6">
        <.header>
          {@page_title}
        </.header>
      </div>

      <div class="bg-white border-0 md:border-l border-r border-t border-gray-300 rounded-lg shadow-sm p-6">
        <.simple_form
          for={@form}
          id="banned_domain-form"
          phx-change="validate"
          phx-submit="save"
          class="space-y-4 mx-auto"
        >
          <div>
            <label for="banned_domain-domain" class="block text-sm font-medium text-gray-700 mb-1">
              Domain
            </label>
            <.input field={@form[:domain]} type="text" id="banned_domain-domain" autocomplete="off" />
          </div>

          <footer class="flex items-center justify-between mt-4">
            <.button navigate={return_path(@return_to, @banned_domain)}>Cancel</.button>
            <.button phx-disable-with="Saving..." variant="primary">Save Banned domain</.button>
          </footer>
        </.simple_form>
      </div>
    </div>
    """
  end

  @impl LiveView
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_other), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    banned_domain = Moderation.get_banned_domain!(id)

    socket
    |> assign(:page_title, "Edit Banned domain")
    |> assign(:banned_domain, banned_domain)
    |> assign(
      :form,
      to_form(Moderation.change_banned_domain(banned_domain))
    )
  end

  defp apply_action(socket, :new, _params) do
    banned_domain = %BannedDomain{}

    socket
    |> assign(:page_title, "New Banned domain")
    |> assign(:banned_domain, banned_domain)
    |> assign(
      :form,
      to_form(Moderation.change_banned_domain(banned_domain))
    )
  end

  @impl LiveView
  def handle_event("validate", %{"banned_domain" => banned_domain_params}, socket) do
    changeset =
      Moderation.change_banned_domain(
        socket.assigns.banned_domain,
        banned_domain_params
      )

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"banned_domain" => banned_domain_params}, socket) do
    save_banned_domain(socket, socket.assigns.live_action, banned_domain_params)
  end

  defp save_banned_domain(socket, :edit, banned_domain_params) do
    case Moderation.update_banned_domain(
           socket.assigns.banned_domain,
           banned_domain_params
         ) do
      {:ok, banned_domain} ->
        {:noreply,
         socket
         |> put_flash(:info, "Banned domain updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, banned_domain))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_banned_domain(socket, :new, banned_domain_params) do
    case Moderation.create_banned_domain(banned_domain_params) do
      {:ok, banned_domain} ->
        {:noreply,
         socket
         |> put_flash(:info, "Banned domain created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, banned_domain))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _banned_domain), do: ~p"/moderation/banned_domains"

  defp return_path("show", banned_domain),
    do: ~p"/moderation/banned_domains/#{banned_domain}"
end
