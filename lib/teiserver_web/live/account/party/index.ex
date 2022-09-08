defmodule TeiserverWeb.Account.PartyLive.Index do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub
  require Logger

  alias Teiserver.Account
  alias Teiserver.Account.PartyLib

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> AuthPlug.live_call(session)
      |> TSAuthPlug.live_call(session)
      |> NotificationPlug.live_call()

    client = Account.get_client_by_id(socket.assigns.user_id)

    :ok = PubSub.subscribe(Central.PubSub, "teiserver_client_messages:#{socket.assigns.user_id}")

    admin_mode = cond do
      not allow?(socket, "teiserver.moderator.account") -> false
      params["mode"] == "admin" -> true
      true -> false
    end

    mode = if admin_mode, do: "admin", else: "player"

    socket = socket
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Parties", url: "/teiserver/account/parties")
      |> assign(:mode, mode)
      |> assign(:client, client)
      |> assign(:site_menu_active, "parties")
      |> assign(:menu_override, Routes.ts_general_general_path(socket, :index))
      |> assign(:view_colour, PartyLib.colours())
      |> assign(:user_lookup, %{})
      |> list_parties()
      |> build_user_lookup()

    {:ok, socket}
  end

  @impl true
  def handle_params(_, _, %{assigns: %{current_user: nil}} = socket) do
    {:noreply, socket |> redirect(to: Routes.general_page_path(socket, :index))}
  end

  def handle_params(_, _, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(TeiserverWeb.Account.PartyLiveView, "index.html", assigns)
  end

  @impl true
  def handle_info(%{channel: "teiserver_party:" <> party_id, event: :closed}, socket) do
    :ok = PubSub.unsubscribe(Central.PubSub, "teiserver_party:#{party_id}")
    new_parties = socket.assigns.parties
      |> Enum.reject(fn p -> p.id == party_id end)

    {:noreply,
      socket
        |> assign(:parties, new_parties)
        |> build_user_lookup
    }
  end

  def handle_info(%{channel: "teiserver_party:" <> _, event: :message}, socket) do
    {:noreply, socket}
  end

  def handle_info(data = %{channel: "teiserver_party:" <> party_id, event: :updated_values}, socket) do
    new_parties = socket.assigns.parties
      |> Enum.map(fn p ->
        if p.id == party_id do
          Map.merge(p, data.new_values)
        else
          p
        end
      end)

    {:noreply,
      socket
        |> assign(:parties, new_parties)
        |> build_user_lookup
    }
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _, event: :connected}, socket) do
    {:noreply,
      socket
        |> assign(:client, Account.get_client_by_id(socket.assigns.user_id))
    }
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _, event: :disconnected}, socket) do
    {:noreply,
      socket
        |> assign(:client, nil)
    }
  end

  def handle_info(data = %{channel: "teiserver_client_messages:" <> _, event: :party_invite}, socket) do
    party = Account.get_party(data.party_id)

    new_parties = socket.assigns.parties
      |> Enum.reject(fn p -> p.id == party.id end)

    {:noreply,
      socket
        |> assign(:parties, [party | new_parties])
        |> build_user_lookup()
    }
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("invite:accept", %{"party_id" => party_id}, socket) do
    PartyLib.call_party(party_id, {:accept_invite, socket.assigns.user_id})
    :timer.sleep(100)
    {:noreply, socket |> redirect(to: Routes.ts_game_party_show_path(socket, :show, party_id))}
  end

  def handle_event("invite:decline", %{"party_id" => party_id}, socket) do
    PartyLib.cast_party(party_id, {:cancel_invite, socket.assigns.user_id})
    {:noreply, socket}
  end

  def handle_event("create_party", _, socket) do
    party = Account.create_party(socket.assigns.user_id)
    :timer.sleep(100)
    {:noreply, socket |> redirect(to: Routes.ts_game_party_show_path(socket, :show, party.id))}
  end


  @spec list_parties(map) :: map
  defp list_parties(%{assigns: %{mode: "admin"}} = socket) do
    parties = Account.list_party_ids()
      |> Account.list_parties()

    parties
      |> Enum.each(fn party ->
        :ok = PubSub.subscribe(Central.PubSub, "teiserver_party:#{party.id}")
      end)

    socket
      |> assign(:parties, parties)
  end

  defp list_parties(socket) do
    parties = socket.assigns.user_id
      |> Account.get_user_by_id
      |> Map.get(:friends)
      |> Kernel.++([socket.assigns.user_id])
      |> Enum.map(fn user_id ->
        Account.get_client_by_id(user_id)
      end)
      |> Enum.reject(&(&1 == nil))
      |> Enum.map(fn c -> c.party_id end)
      |> Enum.reject(&(&1 == nil))
      |> Enum.uniq
      |> Account.list_parties()

    parties
      |> Enum.each(fn party ->
        :ok = PubSub.subscribe(Central.PubSub, "teiserver_party:#{party.id}")
      end)

    socket
      |> assign(:parties, parties)
  end

  @spec build_user_lookup(map) :: map
  def build_user_lookup(socket) do
    existing_user_ids = Map.keys(socket.assigns.user_lookup)

    new_users = socket.assigns.parties
      |> Enum.map(fn p -> p.members end)
      |> List.flatten
      |> Enum.reject(fn m -> Enum.member?(existing_user_ids, m) end)
      |> Account.list_users_from_cache
      |> Map.new(fn u -> {u.id, u} end)

    new_user_lookup = Map.merge(socket.assigns.user_lookup, new_users)

    socket
      |> assign(:user_lookup, new_user_lookup)
  end
end
