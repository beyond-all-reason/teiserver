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
      MapSet.new(["order_by", "page_size", "restriction"])
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
      "email" => params["email"],
      "role" => params["role"],
      "restriction" => params["restriction"],
      "order_by" => params["order_by"] || "Newest first",
      "page_size" => min(maybe_to_integer(params["page_size"]), @max_page_size)
    }
  end

  defp user_query(%Socket{assigns: %{search: search}} = _socket) do
    UserQueries.users()
    |> UserQueries.where_name_like(search["name"] || "")
    |> UserQueries.where_email_like(search["email"] || "")
    |> UserQueries.where_has_role(search["role"] || "")
    |> UserQueries.where_has_restriction(search["restriction"] || "")

    # TODO: Possible extra filters to add
    # IP
    # PreviousNames
  end

  defp get_users(%Socket{assigns: %{page: page, search: search}} = socket) do
    # If they have searched for a name, we want to put that name
    # at the top of the table
    try_exact_search? =
      Enum.any?([
        search["name"] && search["name"] != "",
        search["email"] && search["email"] != ""
      ])

    exact_user =
      if try_exact_search? do
        UserQueries.users()
        |> UserQueries.where_name_lower(search["name"])
        |> UserQueries.where_email_lower(search["email"])
        |> UserQueries.load_user_stat()
        |> QueryHelpers.limit_query(1)
        |> Repo.one()
      end

    users =
      user_query(socket)
      |> UserQueries.load_user_stat()
      |> UserQueries.order_by_from_string(search["order_by"])
      |> QueryHelpers.paginate(page, search["page_size"])
      |> Repo.all()
      |> then(fn results ->
        # This puts our exact match at the top of the list, we have to remove
        # the other instance of that user or it will not appear at the top of
        # the list
        if exact_user do
          [exact_user | Enum.reject(results, fn %{id: id} -> id == exact_user.id end)]
        else
          results
        end
      end)
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
    # If we don't have any search values we know the number of users will be very high
    # at least 500k at time of writing so getting a count of users is a bit pointless
    search_values =
      assigns.search
      |> Map.drop(["_random", "order_by", "page_size"])

    user_count =
      if Enum.empty?(search_values) do
        500_000
      else
        user_query(socket)
        |> QueryHelpers.count()
      end

    page_count = :math.ceil(user_count / assigns.search["page_size"]) |> round()

    socket
    |> assign(user_count: user_count)
    |> assign(page_count: page_count)
  end
end
