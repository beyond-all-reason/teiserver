defmodule TeiserverWeb.ModerationLive.BannedDomain.List do
  @moduledoc false
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Moderation
  alias Teiserver.Moderation.BannedDomain
  alias Teiserver.Moderation.BannedDomainQueries
  alias Teiserver.Repo
  alias TeiserverWeb.ModerationLive.BannedDomain.FormComponent
  alias TeiserverWeb.ModerationLive.BannedDomainComponents

  use TeiserverWeb, :live_view

  import Teiserver.Helper.StringHelper,
    only: [maybe_to_integer: 1]

  import Teiserver.Config, only: [get_user_config_cache: 2, set_user_config: 3]

  @page_size_config_key "last_used.banned_domain_search_page_size"
  @max_page_size 100

  @impl LiveView
  def mount(params, _session, %Socket{} = socket) when is_connected?(socket) do
    socket
    |> assign(page: 0)
    |> init_search_params(params)
    |> get_banned_domains()
    |> get_domain_count()
    |> ok()
  end

  def mount(_params, _session, %Socket{} = socket) do
    socket
    |> assign(banned_domain_count: 0, page: 0, page_count: 1, search: %{}, search_changed?: false)
    |> stream(:banned_domains, [])
    |> ok()
  end

  @impl LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Banned Domain")
    |> assign(:banned_domain, Moderation.get_banned_domain!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Banned Domain")
    |> assign(:banned_domain, %BannedDomain{})
  end

  defp apply_action(socket, :list, _params) do
    socket
    |> assign(:page_title, "Listing Banned Domains")
    |> assign(:banned_domain, nil)
  end

  @impl LiveView
  def handle_info({FormComponent, {:saved, banned_domain}}, socket) do
    {:noreply, stream_insert(socket, :banned_domains, banned_domain)}
  end

  @impl LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    banned_domain = Moderation.get_banned_domain!(id)
    {:ok, _banned_domain} = Moderation.delete_banned_domain(banned_domain)

    {:noreply, stream_delete(socket, :banned_domains, banned_domain)}
  end

  def handle_event("set-page", %{"page" => page}, %Socket{} = socket) do
    page = String.to_integer(page)

    socket
    |> assign(page: page)
    |> get_banned_domains()
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
    |> get_domain_count()
    |> get_banned_domains()
    |> noreply()
  end

  def handle_event("reset-search", _params, %Socket{} = socket) do
    socket
    |> init_search_params(%{})
    |> get_domain_count()
    |> get_banned_domains()
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
      "domain" => params["domain"],
      "order_by" => params["order_by"] || "Newest first",
      "page_size" => min(maybe_to_integer(params["page_size"]), @max_page_size)
    }
  end

  defp domain_query(%Socket{assigns: %{search: search}} = _socket) do
    BannedDomainQueries.banned_domains()
    |> BannedDomainQueries.where_domain_like(search["domain"])
  end

  defp get_banned_domains(%Socket{assigns: %{page: page, search: search}} = socket) do
    banned_domains =
      domain_query(socket)
      |> BannedDomainQueries.order_by_from_string(search["order_by"])
      |> QueryHelpers.paginate(page, search["page_size"])
      |> Repo.all()

    socket
    |> stream(:banned_domains, banned_domains, reset: true)
  end

  defp get_domain_count(%Socket{assigns: assigns} = socket) do
    domain_count =
      domain_query(socket)
      |> QueryHelpers.count()

    page_count = :math.ceil(domain_count / assigns.search["page_size"]) |> round()

    socket
    |> assign(banned_domain_count: domain_count)
    |> assign(page_count: page_count)
  end
end
