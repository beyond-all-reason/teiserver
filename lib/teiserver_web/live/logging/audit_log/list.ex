defmodule TeiserverWeb.LoggingLive.AuditLog.List do
  @moduledoc false
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Logging.AuditLogQueries
  alias Teiserver.Repo
  alias TeiserverWeb.LoggingLive.AuditLogComponents

  use TeiserverWeb, :live_view

  import Teiserver.Config, only: [get_user_config_cache: 2, set_user_config: 3]

  @page_size_config_key "last_used.audit_log_search_page_size"
  @max_page_size 100

  @impl LiveView
  def mount(params, _session, %Socket{} = socket) when is_connected?(socket) do
    socket
    |> assign(page: 0)
    |> init_search_params(params)
    |> get_audit_logs()
    |> get_audit_log_count()
    |> ok()
  end

  def mount(_params, _session, %Socket{} = socket) do
    socket
    |> assign(audit_log_count: 0, page: 0, page_count: 1, search: %{}, search_changed?: false)
    |> stream(:audit_logs, [])
    |> ok()
  end

  @impl LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :list, _params) do
    socket
    |> assign(:page_title, "Listing Audit Logs")
    |> assign(:audit_log, nil)
  end

  @impl LiveView
  def handle_event("set-page", %{"page" => page}, %Socket{} = socket) do
    page = String.to_integer(page)

    socket
    |> assign(page: page)
    |> get_audit_logs()
    |> noreply()
  end

  def handle_event("validate-search", params, %Socket{assigns: %{search: search}} = socket) do
    new_search = convert_search_params(params)

    diff_keys =
      Map.keys(new_search)
      |> Enum.filter(fn key ->
        new_value = new_search[key]
        existing_value = search[key]

        new_value != existing_value
      end)
      |> MapSet.new()

    contains_update_keys? =
      MapSet.new(["order_by", "page_size"])
      |> MapSet.intersection(diff_keys)
      |> Enum.empty?()
      |> Kernel.not()

    # Certain keys are things where we'll want to update the results as they type/update
    if contains_update_keys? do
      handle_event("update-search", params, socket)
    else
      socket
      |> assign(search_changed?: true)
      |> noreply()
    end
  end

  def handle_event("update-search", params, %Socket{assigns: assigns} = socket) do
    params = convert_search_params(params)

    new_search = Map.merge(assigns.search, params)

    set_user_config(socket, @page_size_config_key, params["page_size"])

    socket
    |> assign(search: new_search, search_changed?: false, page: 0)
    |> get_audit_log_count()
    |> get_audit_logs()
    |> noreply()
  end

  def handle_event("reset-search", _params, %Socket{} = socket) do
    socket
    |> init_search_params(%{})
    |> get_audit_log_count()
    |> get_audit_logs()
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
      "action" => params["action"],
      "order_by" => params["order_by"] || "Newest first",
      "page_size" => min(maybe_to_integer(params["page_size"]), @max_page_size)
    }
  end

  defp audit_log_query(%Socket{assigns: %{search: search}} = _socket) do
    AuditLogQueries.audit_logs()
    |> AuditLogQueries.where_action(search["action"])
  end

  defp get_audit_logs(%Socket{assigns: %{page: page, search: search}} = socket) do
    audit_logs =
      audit_log_query(socket)
      |> AuditLogQueries.load_user()
      |> AuditLogQueries.order_by_from_string(search["order_by"])
      |> QueryHelpers.paginate(page, search["page_size"])
      |> Repo.all()

    socket
    |> stream(:audit_logs, audit_logs, reset: true)
  end

  defp get_audit_log_count(%Socket{assigns: assigns} = socket) do
    audit_log_count =
      audit_log_query(socket)
      |> QueryHelpers.count()

    page_count = :math.ceil(audit_log_count / assigns.search["page_size"]) |> round()

    socket
    |> assign(audit_log_count: audit_log_count)
    |> assign(page_count: page_count)
  end
end
