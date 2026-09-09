defmodule TeiserverWeb.ModerationLive.User.List do
  @moduledoc false
  alias Teiserver.Account.User
  alias Teiserver.Account.UserQueries
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Repo
  alias TeiserverWeb.ModerationLive.User.FormComponent
  alias TeiserverWeb.ModerationLive.UserComponents

  use TeiserverWeb, :live_view

  import Teiserver.Config, only: [get_user_config_cache: 2, set_user_config: 3]

  @page_size_config_key "last_used.users_search_page_size"
  @max_page_size 100

  @impl LiveView
  def mount(params, _session, %Socket{} = socket) when is_connected?(socket) do
    is_moderator? = allow?(socket, "Moderator")

    socket
    |> assign(page: 0, is_moderator?: is_moderator?)
    |> init_search_params(params)
    |> get_users()
    |> get_user_count()
    |> ok()
  end

  def mount(_params, _session, %Socket{} = socket) do
    socket
    |> assign(
      user_count: 0,
      page: 0,
      page_count: 1,
      search: %{},
      search_changed?: false,
      is_moderator?: false
    )
    |> stream(:users, [])
    |> ok()
  end

  @impl LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :list, _params) do
    socket
    |> assign(:page_title, "Listing Banned Domains")
    |> assign(:user, nil)
  end

  @impl LiveView
  def handle_info({FormComponent, {:saved, user}}, socket) do
    {:noreply, stream_insert(socket, :users, user)}
  end

  @impl LiveView
  def handle_event("set-page", %{"page" => page}, %Socket{} = socket) do
    page = String.to_integer(page)

    socket
    |> assign(page: page)
    |> get_users()
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
    |> get_user_count()
    |> get_users()
    |> noreply()
  end

  def handle_event("reset-search", _params, %Socket{} = socket) do
    socket
    |> init_search_params(%{})
    |> get_user_count()
    |> get_users()
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
      "name" => params["name"],
      "order_by" => params["order_by"] || "Newest first",
      "page_size" => min(maybe_to_integer(params["page_size"]), @max_page_size)
    }
  end

  defp user_query(%Socket{assigns: %{search: search}} = _socket) do
    UserQueries.users()
    |> UserQueries.where_name_like(search["name"] || "")
  end

  defp get_users(%Socket{assigns: %{page: page, search: search}} = socket) do
    users =
      user_query(socket)
      |> UserQueries.load_user_stat()
      |> UserQueries.order_by_from_string(search["order_by"])
      |> QueryHelpers.paginate(page, search["page_size"])
      |> Repo.all()

    users =
      users
      |> Enum.map(fn %User{} = user ->
        # If a user has not logged in yet they will
        # not have a user stat so we need a default value for that
        stat = (user.user_stat && user.user_stat.data) || %{}

        hw_string =
          if stat["hardware:cpuinfo"] != "" and stat["hardware:cpuinfo"] != nil do
            raw([
              stat["hardware:cpuinfo"],
              "<br />",
              "#{stat["hardware:gpuinfo"]} @ #{stat["hardware:displaymax"]}"
            ])
          else
            []
          end

        Map.merge(user, %{
          client: stat["lobby_client"],
          hw_string: hw_string,
          last_ip: stat["last_ip"]
        })
      end)

    socket
    |> stream(:users, users, reset: true)
  end

  defp get_user_count(%Socket{assigns: assigns} = socket) do
    user_count =
      user_query(socket)
      |> QueryHelpers.count()

    page_count = :math.ceil(user_count / assigns.search["page_size"]) |> round()

    socket
    |> assign(user_count: user_count)
    |> assign(page_count: page_count)
  end
end
