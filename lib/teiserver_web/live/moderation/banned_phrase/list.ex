defmodule TeiserverWeb.ModerationLive.BannedPhrase.List do
  @moduledoc false
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Moderation
  alias Teiserver.Moderation.BannedPhrase
  alias Teiserver.Moderation.BannedPhraseQueries
  alias Teiserver.Repo
  alias TeiserverWeb.ModerationLive.BannedPhrase.FormComponent
  alias TeiserverWeb.ModerationLive.BannedPhraseComponents

  use TeiserverWeb, :live_view

  import Teiserver.Helper.StringHelper,
    only: [maybe_to_integer: 1]

  import Teiserver.Config, only: [get_user_config_cache: 2, set_user_config: 3]

  @page_size_config_key "last_used.banned_phrase_search_page_size"
  @max_page_size 100

  @impl LiveView
  def mount(params, _session, %Socket{} = socket) when is_connected?(socket) do
    socket
    |> assign(page: 0)
    |> init_search_params(params)
    |> get_banned_phrases()
    |> get_phrase_count()
    |> ok()
  end

  def mount(_params, _session, %Socket{} = socket) do
    socket
    |> assign(banned_phrase_count: 0, page: 0, page_count: 1, search: %{}, search_changed?: false)
    |> stream(:banned_phrases, [])
    |> ok()
  end

  @impl LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Banned Phrase")
    |> assign(:banned_phrase, Moderation.get_banned_phrase!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Banned Phrase")
    |> assign(:banned_phrase, %BannedPhrase{})
  end

  defp apply_action(socket, :list, _params) do
    socket
    |> assign(:page_title, "Listing Banned Phrases")
    |> assign(:banned_phrase, nil)
  end

  @impl LiveView
  def handle_info({FormComponent, {:saved, banned_phrase}}, socket) do
    {:noreply, stream_insert(socket, :banned_phrases, banned_phrase)}
  end

  @impl LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    banned_phrase = Moderation.get_banned_phrase!(id)
    {:ok, _banned_phrase} = Moderation.delete_banned_phrase(banned_phrase)

    {:noreply, stream_delete(socket, :banned_phrases, banned_phrase)}
  end

  def handle_event("set-page", %{"page" => page}, %Socket{} = socket) do
    page = String.to_integer(page)

    socket
    |> assign(page: page)
    |> get_banned_phrases()
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
    |> get_phrase_count()
    |> get_banned_phrases()
    |> noreply()
  end

  def handle_event("reset-search", _params, %Socket{} = socket) do
    socket
    |> init_search_params(%{})
    |> get_phrase_count()
    |> get_banned_phrases()
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
      "phrase" => params["phrase"],
      "order_by" => params["order_by"] || "Newest first",
      "page_size" => min(maybe_to_integer(params["page_size"]), @max_page_size)
    }
  end

  defp phrase_query(%Socket{assigns: %{search: search}} = _socket) do
    BannedPhraseQueries.banned_phrases()
    |> BannedPhraseQueries.where_phrase_like(search["phrase"])
  end

  defp get_banned_phrases(%Socket{assigns: %{page: page, search: search}} = socket) do
    banned_phrases =
      phrase_query(socket)
      |> BannedPhraseQueries.order_by_from_string(search["order_by"])
      |> QueryHelpers.paginate(page, search["page_size"])
      |> Repo.all()

    socket
    |> stream(:banned_phrases, banned_phrases, reset: true)
  end

  defp get_phrase_count(%Socket{assigns: assigns} = socket) do
    phrase_count =
      phrase_query(socket)
      |> QueryHelpers.count()

    page_count = :math.ceil(phrase_count / assigns.search["page_size"]) |> round()

    socket
    |> assign(banned_phrase_count: phrase_count)
    |> assign(page_count: page_count)
  end
end
