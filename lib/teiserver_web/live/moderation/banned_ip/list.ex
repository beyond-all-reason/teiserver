defmodule TeiserverWeb.ModerationLive.BannedIP.List do
  @moduledoc false
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Moderation
  alias Teiserver.Moderation.BannedIP
  alias Teiserver.Moderation.BannedIPQueries
  alias Teiserver.Repo
  alias TeiserverWeb.ModerationLive.BannedIP.FormComponent
  alias TeiserverWeb.ModerationLive.BannedIPComponents

  use TeiserverWeb, :live_view

  import Teiserver.Helper.StringHelper,
    only: [maybe_to_integer: 1]

  import Teiserver.Config, only: [get_user_config_cache: 2, set_user_config: 3]

  @page_size_config_key "last_used.banned_ip_search_page_size"
  @max_page_size 100

  @impl LiveView
  def mount(params, _session, %Socket{} = socket) when is_connected?(socket) do
    socket
    |> assign(page: 0)
    |> init_search_params(params)
    |> get_banned_ips()
    |> get_ip_count()
    |> ok()
  end

  def mount(_params, _session, %Socket{} = socket) do
    socket
    |> assign(banned_ip_count: 0, page: 0, page_count: 1, search: %{}, search_changed?: false)
    |> stream(:banned_ips, [])
    |> ok()
  end

  @impl LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Banned IP")
    |> assign(:banned_ip, Moderation.get_banned_ip!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Banned IP")
    |> assign(:banned_ip, %BannedIP{})
  end

  defp apply_action(socket, :list, _params) do
    socket
    |> assign(:page_title, "Listing Banned IPs")
    |> assign(:banned_ip, nil)
  end

  @impl LiveView
  def handle_info({FormComponent, {:saved, banned_ip}}, socket) do
    {:noreply, stream_insert(socket, :banned_ips, banned_ip)}
  end

  @impl LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    banned_ip = Moderation.get_banned_ip!(id)
    {:ok, _banned_ip} = Moderation.delete_banned_ip(banned_ip)

    {:noreply, stream_delete(socket, :banned_ips, banned_ip)}
  end

  def handle_event("set-page", %{"page" => page}, %Socket{} = socket) do
    page = String.to_integer(page)

    socket
    |> assign(page: page)
    |> get_banned_ips()
    |> noreply()
  end

  def handle_event("validate-search", _params, %Socket{} = socket) do
    socket
    |> assign(search_changed?: true)
    |> noreply()
  end

  def handle_event("update-search", params, %Socket{assigns: assigns} = socket) do
    params = convert_search_params(params)

    new_search = Map.merge(assigns.search, params)

    set_user_config(socket, @page_size_config_key, params["page_size"])

    socket
    |> assign(search: new_search, search_changed?: false, page: 0)
    |> get_ip_count()
    |> get_banned_ips()
    |> noreply()
  end

  def handle_event("reset-search", _params, %Socket{} = socket) do
    socket
    |> init_search_params(%{})
    |> get_ip_count()
    |> get_banned_ips()
    |> noreply()
  end

  defp init_search_params(%Socket{assigns: _assigns} = socket, params) do
    params =
      params
      |> convert_search_params()
      |> Map.merge(%{
        "page_size" => get_user_config_cache(socket, @page_size_config_key),
        # Force refresh of form
        "_random" => :rand.uniform()
      })
      |> Map.reject(fn {_k, v} -> is_nil(v) end)

    socket
    |> assign(search: params, search_changed?: false)
  end

  defp convert_search_params(params) do
    %{
      "ip" => params["ip"],
      "order_by" => params["order_by"] || "Newest first",
      "page_size" => min(maybe_to_integer(params["page_size"]), @max_page_size)
    }
  end

  defp ip_query(%Socket{assigns: %{search: search}} = _socket) do
    BannedIPQueries.banned_ips()
    |> BannedIPQueries.where_cidr_like(search["ip"])
  end

  defp get_banned_ips(%Socket{assigns: %{page: page, search: search}} = socket) do
    banned_ips =
      ip_query(socket)
      |> BannedIPQueries.order_by_from_string(search["order_by"])
      |> QueryHelpers.paginate(page, search["page_size"])
      |> Repo.all()

    socket
    |> stream(:banned_ips, banned_ips, reset: true)
  end

  defp get_ip_count(%Socket{assigns: assigns} = socket) do
    ip_count =
      ip_query(socket)
      |> QueryHelpers.count()

    page_count = :math.ceil(ip_count / assigns.search["page_size"]) |> round()

    socket
    |> assign(banned_ip_count: ip_count)
    |> assign(page_count: page_count)
  end
end
