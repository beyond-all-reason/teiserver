defmodule TeiserverWeb.Moderation.BannedDomainLive.Form do
  @moduledoc false
  alias Teiserver.Moderation
  alias Teiserver.Moderation.BannedDomain

  use TeiserverWeb, :live_view

  @impl LiveView
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage banned_domain records in your database.</:subtitle>
      </.header>

      <.simple_form for={@form} id="banned_domain-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:domain]} type="text" label="Domain" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Banned domain</.button>
          <.button navigate={return_path(@return_to, @banned_domain)}>Cancel</.button>
        </footer>
      </.simple_form>
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
    IO.puts("")
    IO.inspect("X", label: "#{__MODULE__}:#{__ENV__.line}")
    IO.puts("")

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
