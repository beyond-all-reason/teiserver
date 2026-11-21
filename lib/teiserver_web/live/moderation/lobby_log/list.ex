defmodule TeiserverWeb.ModerationLive.LobbyLog.List do
  @moduledoc false
  alias Ecto.UUID
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Moderation.LobbyLogQueries
  alias Teiserver.Repo
  alias TeiserverWeb.Moderation.LobbyLogComponents

  use TeiserverWeb, :live_view

  import Teiserver.Helper.StringHelper, only: [maybe_to_integer: 1]
  import Teiserver.Config, only: [get_user_config_cache: 2, set_user_config: 3]

  @page_size_config_key "last_used.lobby_log_search_page_size"
  @max_page_size 100

  @impl Phoenix.LiveView
  def mount(params, _session, %Socket{} = socket) when is_connected?(socket) do
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
    socket
    |> assign(page: String.to_integer(page))
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
      MapSet.new(["order_by", "page_size", "event_type", "user_id", "target_id"])
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

    set_user_config(socket, @page_size_config_key, params["page_size"])

    socket
    |> assign(search: Map.merge(assigns.search, params), search_changed?: false, page: 0)
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

  defp init_search_params(%Socket{} = socket, params) do
    params =
      params
      |> convert_search_params()
      |> Map.merge(%{
        "page_size" => get_user_config_cache(socket, @page_size_config_key),
        # Force refresh of form
        "_random" => :rand.uniform()
      })
      |> Map.reject(fn {_k, v} -> is_nil(v) end)

    assign(socket, search: params, search_changed?: false)
  end

  defp convert_search_params(params) do
    %{
      "lobby_id" => params["lobby_id"],
      "event_type" => params["event_type"] || "Any",
      "user_id" => maybe_to_integer(params["user_id"]),
      "target_id" => maybe_to_integer(params["target_id"]),
      "order_by" => params["order_by"] || "Newest first",
      "page_size" => min(maybe_to_integer(params["page_size"]), @max_page_size)
    }
  end

  defp record_query(%Socket{assigns: %{search: search}}) do
    LobbyLogQueries.lobby_logs()
    |> LobbyLogQueries.where_lobby_id(lobby_id(search["lobby_id"]))
    |> LobbyLogQueries.where_event_type(search["event_type"])
    |> LobbyLogQueries.where_user_id(search["user_id"])
    |> LobbyLogQueries.where_target_id(search["target_id"])
  end

  defp lobby_id(nil), do: nil
  defp lobby_id(""), do: nil

  defp lobby_id(str) do
    cast = str |> String.trim() |> UUID.cast()

    case cast do
      {:ok, uuid} -> uuid
      :error -> nil
    end
  end

  defp details_text(nil), do: nil
  defp details_text(details) when details == %{}, do: nil
  defp details_text(details), do: Jason.encode!(details)

  defp get_records(%Socket{assigns: assigns} = socket) do
    records =
      record_query(socket)
      |> LobbyLogQueries.load_user()
      |> LobbyLogQueries.load_target()
      |> LobbyLogQueries.order_by_from_string(assigns.search["order_by"])
      |> QueryHelpers.paginate(assigns.page, assigns.search["page_size"])
      |> Repo.all()

    assign(socket, records: records)
  end

  defp get_record_count(%Socket{assigns: assigns} = socket) do
    record_count = record_query(socket) |> QueryHelpers.count()
    page_count = :math.ceil(record_count / assigns.search["page_size"]) |> round()

    assign(socket, record_count: record_count, page_count: page_count)
  end
end
