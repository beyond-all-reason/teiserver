defmodule TeiserverWeb.ModerationLive.AntiAbuseRecord.List do
  @moduledoc false
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Moderation
  alias Teiserver.Moderation.AntiAbuseRecordQueries
  alias Teiserver.Repo
  alias TeiserverWeb.Moderation.AntiAbuseRecordComponents

  use TeiserverWeb, :live_view

  import Teiserver.Helper.StringHelper,
    only: [uuid_part: 1, boolean_from_form: 1, maybe_to_integer: 1]

  import Teiserver.Config, only: [get_user_config_cache: 2, set_user_config: 3]

  @page_size_config_key "last_used.anti_abuse_search_page_size"
  @max_page_size 100

  @impl Phoenix.LiveView
  def mount(params, _session, %Socket{assigns: %{scope: scope}} = socket)
      when is_connected?(socket) do
    Moderation.log_anti_abuse_record_access(nil, scope, :list)

    socket
    |> assign(page: 0)
    |> init_search_params(params)
    |> get_records()
    |> get_record_count()
    |> ok()
  end

  def mount(_params, _session, %Socket{} = socket) do
    socket
    |> assign(
      records: [],
      record_count: 0,
      page: 0,
      page_count: 1,
      search: %{},
      search_changed?: false
    )
    |> ok()
  end

  @impl Phoenix.LiveView
  def handle_event("set-page", %{"page" => page}, %Socket{} = socket) do
    page = String.to_integer(page)

    socket
    |> assign(page: page)
    |> get_records()
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
      MapSet.new(["order_by", "page_size", "clean?", "restored?", "expired?"])
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
    |> get_record_count()
    |> get_records()
    |> noreply()
  end

  def handle_event("reset-search", _params, %Socket{} = socket) do
    socket
    |> init_search_params(%{})
    |> get_record_count()
    |> get_records()
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
      "user_id" => maybe_to_integer(params["user_id"]),
      "clean?" => boolean_from_form(params["clean?"]),
      "restored?" => boolean_from_form(params["restored?"]),
      "restored_by_id" => params["restored_by_id"],
      "order_by" => params["order_by"] || "Newest first",
      "page_size" => min(maybe_to_integer(params["page_size"]), @max_page_size)
    }
  end

  defp record_query(%Socket{assigns: %{search: search}} = _socket) do
    AntiAbuseRecordQueries.anti_abuse_records()
    |> AntiAbuseRecordQueries.where_user_id(search["user_id"])
    |> AntiAbuseRecordQueries.where_clean(search["clean?"])
    |> AntiAbuseRecordQueries.where_restored(search["restored?"])
    |> AntiAbuseRecordQueries.where_restored_by_id(search["restored_by_id"])
  end

  defp get_records(%Socket{assigns: assigns} = socket) do
    records =
      record_query(socket)
      |> AntiAbuseRecordQueries.load_user()
      |> AntiAbuseRecordQueries.load_restorer()
      |> AntiAbuseRecordQueries.order_by_inserted_at(:desc)
      |> QueryHelpers.paginate(assigns.page, assigns.search["page_size"])
      |> Repo.all()

    socket
    |> assign(records: records)
  end

  defp get_record_count(%Socket{assigns: assigns} = socket) do
    record_count =
      record_query(socket)
      |> QueryHelpers.count()

    page_count = :math.ceil(record_count / assigns.search["page_size"]) |> round()

    socket
    |> assign(record_count: record_count)
    |> assign(page_count: page_count)
  end
end
