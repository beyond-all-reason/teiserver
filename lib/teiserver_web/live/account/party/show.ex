defmodule TeiserverWeb.Account.PartyLive.Show do
  use TeiserverWeb, :live_view
  alias Phoenix.PubSub
  require Logger

  alias Teiserver.Account
  alias Teiserver.Account.PartyLib
  import Central.Helpers.StringHelper, only: [possessive: 1]
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
        |> AuthPlug.live_call(session)
        |> TSAuthPlug.live_call(session)
        |> NotificationPlug.live_call()

    client = Account.get_client_by_id(socket.assigns.user_id)
    user = Account.get_user_by_id(socket.assigns.user_id)

    :ok = PubSub.subscribe(Central.PubSub, "teiserver_client_messages:#{socket.assigns.user_id}")

    socket = socket
      |> add_breadcrumb(name: "Teiserver", url: "/teiserver")
      |> add_breadcrumb(name: "Parties", url: "/teiserver/account/parties")
      |> assign(:client, client)
      |> assign(:user, user)
      |> build_user_lookup

    {:ok, socket}
  end

  @impl true
  def handle_params(_, _, %{assigns: %{current_user: nil}} = socket) do
    {:noreply, socket |> redirect(to: Routes.general_page_path(socket, :index))}
  end

  def handle_params(%{"id" => party_id}, _, socket) do
    party = Account.get_party(party_id)
    leader_name = Account.get_username(party.leader)

    if party do
      if Enum.member?(party.members, socket.assigns.user_id) or allow?(socket, "teiserver.moderator.account") do
        {:noreply,
          socket
            |> add_breadcrumb(name: "#{leader_name |> possessive} party", url: "/teiserver/account/parties")
            |> assign(:site_menu_active, "parties")
            |> assign(:menu_override, Routes.ts_general_general_path(socket, :index))
            |> assign(:view_colour, PartyLib.colours())
            |> assign(:user_lookup, %{})
            |> assign(:party_id, party_id)
            |> assign(:party, party)
            |> build_user_lookup
        }
      else
        {:noreply, socket |> redirect(to: Routes.ts_game_party_index_path(socket, :index))}
      end
    else
      {:noreply, socket |> redirect(to: Routes.ts_game_party_index_path(socket, :index))}
    end
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(TeiserverWeb.Account.PartyLiveView, "show.html", assigns)
  end

  @impl true
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

  def handle_info(%{channel: "teiserver_client_messages:" <> _}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("create_invite", %{"userid" => userid_str}, socket) do
    userid = int_parse(userid_str)
    Account.create_party_invite(socket.assigns.party_id, userid)
    {:noreply, socket}
  end

  @spec build_user_lookup(map) :: map
  def build_user_lookup(socket) do
    existing_user_ids = Map.keys(socket.assigns[:user_lookup] || %{})

    ids = [
      socket.assigns.party.members,
      socket.assigns.party.pending_invites,
      socket.assigns.user.friends
    ]
      |> List.flatten
      |> Enum.uniq

    new_users = ids
      |> Enum.reject(fn m -> Enum.member?(existing_user_ids, m) end)
      |> Account.list_users_from_cache
      |> Map.new(fn u -> {u.id, u} end)

    new_user_lookup = Map.merge(socket.assigns.user_lookup, new_users)

    socket
      |> assign(:user_lookup, new_user_lookup)
  end
end
