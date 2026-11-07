defmodule TeiserverWeb.ModerationLive.User.List do
  @moduledoc false
  alias Teiserver.Account.User
  alias Teiserver.Account.UserQueries
  alias Teiserver.Account.UserStatQueries
  alias Teiserver.Helper.DateHelper
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Repo
  alias TeiserverWeb.ModerationLive.UserComponents
  alias TeiserverWeb.ModerationLive.UserListPreferences

  use TeiserverWeb, :live_view

  import Teiserver.Config, only: [get_user_config_cache: 2, set_user_config: 3]

  @page_size_config_key "last_used.users_search_page_size"
  @max_page_size 100

  @impl LiveView
  def mount(params, _session, %Socket{} = socket) when is_connected?(socket) do
    is_moderator? = allow?(socket, "Moderator")

    preferences = UserListPreferences.get_preferences(socket.assigns.scope)

    socket
    |> assign(page: 0, is_moderator?: is_moderator?, preferences: preferences)
    |> init_search_params(params)
    |> get_users()
    |> get_user_count()
    |> generate_cmd_palette_commands()
    |> maybe_redirect_to_single_user(params)
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
      is_moderator?: false,
      preferences: nil
    )
    # |> stream(:users, [])
    |> assign(users: [])
    |> ok()
  end

  @impl LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :list, _params) do
    socket
    |> assign(:page_title, "Listing Users")
    |> assign(:user, nil)
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
    |> generate_cmd_palette_commands()
    |> noreply()
  end

  def handle_event("reset-search", _params, %Socket{} = socket) do
    socket
    |> init_search_params(%{})
    |> get_user_count()
    |> get_users()
    |> generate_cmd_palette_commands()
    |> noreply()
  end

  @impl LiveView
  def handle_info({:updated_preference, key, value}, %Socket{} = socket) do
    new_preferences =
      socket.assigns.preferences
      |> Map.put(key, value)

    socket
    |> assign(preferences: new_preferences)
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
      # User entity
      "name" => params["name"],
      "email" => params["email"],
      "name_or_email" => params["name_or_email"],
      "role" => params["role"],
      "last_login" => params["last_login"],
      "without_role" => params["without_role"],
      "restriction" => params["restriction"] || "",

      # UserStat entity
      "cpu" => params["cpu"],
      "gpu" => params["gpu"],
      "ram" => params["ram"],
      "operating_system" => params["operating_system"],
      "screen" => params["screen"],
      "ip" => params["ip"],

      # Custom UserStat data
      "custom_key" => params["custom_key"],
      "custom_value" => params["custom_value"],

      # Metadata
      "order_by" => params["order_by"] || "Newest first",
      "page_size" => min(maybe_to_integer(params["page_size"]), @max_page_size)
    }
  end

  defp user_query(%Socket{assigns: %{search: search}} = _socket) do
    last_login = DateHelper.parse_ymd(search["last_login"]) || ""

    name_or_email = (search["name_or_email"] || "") |> String.trim()

    UserQueries.users()
    |> UserQueries.where_name_like(search["name"] || "")
    |> UserQueries.where_email_like(search["email"] || "")
    |> UserQueries.where_name_or_email_like(name_or_email)
    |> UserQueries.where_logged_in_after(last_login)
    |> UserQueries.where_has_role(search["role"] || "")
    |> UserQueries.where_not_has_role(search["without_role"] || "")
    |> UserQueries.where_has_restriction(search["restriction"] || "")
    |> UserQueries.join_user_stats()
    |> UserStatQueries.where_data_equal("hardware:cpuinfo", search["cpu"])
    |> UserStatQueries.where_data_equal("hardware:raminfo", search["ram"])
    |> UserStatQueries.where_data_equal("hardware:gpuinfo", search["gpu"])
    |> UserStatQueries.where_data_equal("hardware:displaymax", search["screen"])
    |> UserStatQueries.where_data_equal(search["custom_key"], search["custom_value"])
    |> UserStatQueries.where_data_like("last_ip", search["ip"])

    # TODO: Possible extra filters to add
    # PreviousNames
  end

  defp get_users(
         %Socket{assigns: %{page: page, search: search, preferences: preferences}} = socket
       ) do
    # If they have searched for a name, we want to put that name
    # at the top of the table
    try_exact_search? =
      Enum.any?([
        search["name"] && search["name"] != "",
        search["email"] && search["email"] != "",
        search["name_or_email"] && search["name_or_email"] != ""
      ])

    exact_user_by_id =
      case Integer.parse(search["name"] || search["name_or_email"] || "") do
        {id, _rem} ->
          UserQueries.users()
          |> UserQueries.where_id(id)
          |> UserQueries.load_user_stat()
          |> QueryHelpers.limit_query(1)
          |> Repo.one()

        _any ->
          nil
      end

    exact_user_by_string =
      if try_exact_search? do
        UserQueries.users()
        |> UserQueries.where_name_lower(search["name"] || "")
        |> UserQueries.where_email_lower(search["email"] || "")
        |> UserQueries.where_name_or_email_lower(search["name_or_email"] || "")
        |> UserQueries.load_user_stat()
        |> QueryHelpers.limit_query(1)
        |> Repo.one()
      end

    exact_matches =
      [exact_user_by_id, exact_user_by_string]
      |> Enum.reject(&is_nil/1)

    exact_ids = Enum.map(exact_matches, & &1.id)

    users =
      user_query(socket)
      |> maybe_load_user_stat(preferences)
      |> UserQueries.order_by_from_string(search["order_by"])
      |> QueryHelpers.paginate(page, search["page_size"])
      |> Repo.all()
      # This reject puts our exact matches at the top of the list, we have to remove
      # the other instance of that user or it will not appear at the top of
      # the list
      |> Enum.reject(&Enum.member?(exact_ids, &1.id))
      |> then(fn results ->
        exact_matches ++ results
      end)
      |> Enum.map(fn %User{} = user ->
        # If a user has not logged in yet they will
        # not have a user stat so we need a default value for that
        # additionally if the relevant columns are hidden we won't
        # need to load it. We still pretend we do for consistency though.
        stat =
          case user do
            %{user_stat: nil} -> %{}
            %{user_stat: %{data: %{}}} -> user.user_stat.data
            _any -> %{}
          end

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
    |> assign(users: users, exact_matches: exact_matches)
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
    |> assign(user_count: user_count, page_count: page_count)
  end

  # The quick search in the header sends name_or_email as a url param, if it
  # matches exactly one user we go straight to them. The search form on this
  # page does not go through mount so it never redirects.
  defp maybe_redirect_to_single_user(%Socket{assigns: assigns} = socket, params) do
    quick_search = String.trim(params["name_or_email"] || "")

    case assigns.users do
      [user] when quick_search != "" and assigns.user_count <= 1 ->
        redirect(socket, to: ~p"/moderation/users/#{user.id}")

      _users ->
        socket
    end
  end

  defp maybe_load_user_stat(query, %{skip_user_stat?: true}), do: query

  defp maybe_load_user_stat(query, _any) do
    UserQueries.load_user_stat(query)
  end

  defp generate_cmd_palette_commands(%Socket{assigns: assigns} = socket) do
    first_user =
      if Enum.empty?(assigns.exact_matches) do
        Enum.at(assigns.users, 0)
      else
        Enum.at(assigns.exact_matches, 0)
      end

    extra_commands =
      if is_nil(first_user) do
        []
      else
        [
          %{
            id: "goto:first_user",
            cmd: :goto,
            label: "View user: #{first_user.name}",
            path: ~p"/moderation/users/#{first_user.id}"
          }
        ]
      end

    socket
    |> assign(extra_commands: extra_commands)
  end
end
