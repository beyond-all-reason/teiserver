defmodule Teiserver.Account.UserLib do
  use CentralWeb, :library
  alias Central.Account.UserQueries
  require Logger

  # Functions
  @spec icon :: String.t()
  def icon, do: "far fa-user-robot"

  @spec colours :: atom
  def colours, do: :success

  @spec make_favourite(Central.Account.User.t()) :: Map.t()
  def make_favourite(user) do
    %{
      type_colour: StylingHelper.colours(colours()) |> elem(0),
      type_icon: icon(),
      item_id: user.id,
      item_type: "teiserver_user",
      item_colour: user.colour,
      item_icon: user.icon,
      item_label: "#{user.name}",
      url: "/teiserver/admin/user/#{user.id}"
    }
  end

  # Queries
  @spec get_user() :: Ecto.Query.t()
  def get_user, do: UserQueries.get_users()

  @spec search(Ecto.Query.t(), map | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), atom, any) :: Ecto.Query.t()
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query
  def _search(query, _, "Any"), do: query

  def _search(query, :exact_name, value) do
    from users in query,
      where: users.name == ^value
  end

  def _search(query, :data_equal, {field, value}) do
    from users in query,
      where: fragment("? ->> ? = ?", users.data, ^field, ^value)
  end

  def _search(query, :data_greater_than, {field, value}) do
    from users in query,
      where: fragment("? ->> ? > ?", users.data, ^field, ^value)
  end

  def _search(query, :data_less_than, {field, value}) do
    from users in query,
      where: fragment("? ->> ? < ?", users.data, ^field, ^value)
  end

  def _search(query, :data_not, {field, value}) do
    from users in query,
      where: fragment("? ->> ? != ?", users.data, ^field, ^value)
  end

  # https://www.postgresql.org/docs/current/functions-json.html - Unable to find a function for this :(
  # def _search(query, :data_contains, {field, value}) do
  #   from users in query,
  #     where: fragment("? ->> ? != ?", users.data, ^field, ^value)
  # end

  def _search(query, :pre_cache, value) do
    from users in query,
      where: users.pre_cache == ^value
  end

  def _search(query, :bot, "Person") do
    Logger.error("user.data['bot'] is being queried, this property is due to be depreciated")
    from users in query,
      where: fragment("? ->> ? = ?", users.data, "bot", "false")
  end

  def _search(query, :bot, "Robot") do
    Logger.error("user.data['bot'] is being queried, this property is due to be depreciated")
    from users in query,
      where: fragment("? ->> ? = ?", users.data, "bot", "true")
  end

  def _search(query, :moderator, "User") do
    Logger.error("user.data['verified'] is being queried, this property is due to be depreciated")
    from users in query,
      where: fragment("? ->> ? = ?", users.data, "moderator", "false")
  end

  def _search(query, :moderator, "Moderator") do
    Logger.error("user.data['moderator'] is being queried, this property is due to be depreciated")
    from users in query,
      where: fragment("? ->> ? = ?", users.data, "moderator", "true")
  end

  def _search(query, :verified, "Unverified") do
    Logger.error("user.data['verified'] is being queried, this property is due to be depreciated")
    from users in query,
      where: fragment("? ->> ? = ?", users.data, "verified", "false")
  end

  def _search(query, :verified, "Verified") do
    Logger.error("user.data['verified'] is being queried, this property is due to be depreciated")
    from users in query,
      where: fragment("? ->> ? = ?", users.data, "verified", "true")
  end

  def _search(query, :tester, "Trusted") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "roles", "\"Trusted\"")
  end

  def _search(query, :tester, "Tester") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "roles", "\"Tester\"")
  end

  def _search(query, :tester, "Normal") do
    from users in query,
      where: fragment("not ? -> ? @> ?", users.data, "roles", "\"Tester\"")
  end

  def _search(query, :streamer, "Streamer") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "roles", "\"Streamer\"")
  end

  def _search(query, :streamer, "Normal") do
    from users in query,
      where: fragment("not ? -> ? @> ?", users.data, "roles", "\"Streamer\"")
  end

  def _search(query, :donor, "Donor") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "roles", "\"Donor\"")
  end

  def _search(query, :donor, "Normal") do
    from users in query,
      where: fragment("not ? -> ? @> ?", users.data, "roles", "\"Donor\"")
  end

  def _search(query, :contributor, "Contributor") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "roles", "\"Contributor\"")
  end

  def _search(query, :contributor, "Normal") do
    from users in query,
      where: fragment("not ? -> ? @> ?", users.data, "roles", "\"Contributor\"")
  end

  def _search(query, :developer, "Developer") do
    from users in query,
      where: fragment("? -> ? @> ?", users.data, "roles", "\"Developer\"")
  end

  def _search(query, :developer, "Normal") do
    from users in query,
      where: fragment("not ? -> ? @> ?", users.data, "roles", "\"Developer\"")
  end

  def _search(query, :lobby_client, lobby_client) do
    from users in query,
      where: fragment("? ->> ? = ?", users.data, "lobby_client", ^lobby_client)
  end

  def _search(query, :previous_names, name) do
    uname = "%" <> name <> "%"

    from users in query,
      where: ilike(users.name, ^uname)
  end

  def _search(query, :mod_action, "Banned") do
    from users in query,
      where: fragment("? -> ? ->> 0 = 'true'", users.data, "banned")
  end

  def _search(query, :mod_action, "Muted") do
    from users in query,
      where: fragment("? -> ? ->> 0 = 'true'", users.data, "muted")
  end

  def _search(query, :mod_action, "Warned") do
    from users in query,
      where: fragment("? -> ? ->> 0 = 'true'", users.data, "warned")
  end

  def _search(query, :mod_action, "Any action") do
    from users in query,
      where: fragment("? -> ? ->> 0 = 'true'", users.data, "warned")
        or fragment("? -> ? ->> 0 = 'true'", users.data, "muted")
        or fragment("? -> ? ->> 0 = 'true'", users.data, "banned")
  end

  def _search(query, :mod_action, "None") do
    from users in query,
      where: fragment("? -> ? ->> 0 = 'false'", users.data, "warned")
        and fragment("? -> ? ->> 0 = 'false'", users.data, "muted")
        and fragment("? -> ? ->> 0 = 'false'", users.data, "banned")
  end

  def _search(query, key, value) do
    UserQueries._search(query, key, value)
  end

  @spec order_by(Ecto.Query.t(), tuple() | String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, {:data, field, :asc}) do
    from users in query,
      order_by: [asc: fragment("? -> ?", users.data, ^field)]
  end

  def order_by(query, {:data, field, :desc}) do
    from users in query,
      order_by: [desc: fragment("? -> ?", users.data, ^field)]
  end

  def order_by(query, key), do: UserQueries.order(query, key)

  @spec preload(Ecto.Query.t(), list() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = UserQueries.preload(query, preloads)

    query = if :user_stat in preloads, do: _preload_user_stat(query), else: query

    query
  end

  def _preload_user_stat(query) do
    from user in query,
      left_join: user_stats in assoc(user, :user_stat),
      preload: [user_stat: user_stats]
  end

  @spec restriction_list :: [String.t()]
  def restriction_list() do
    [
      # Chat
      "Bridging",
      "Room chat",
      "Direct chat",
      "Lobby chat",
      "Battle chat",

      # Lobby interaction
      "Host commands",
      "Voting",

      # Lobbies - Joining
      "Hosting games",
      "Joining existing lobbies",
      "Joining duel",
      "Joining ffa",
      "Joining team",
      "Joining coop",

      # Lobbies - Playing
      "Playing duel",
      "Playing ffa",
      "Playing team",
      "Playing coop",

      # MM

      # In game?
      # "pausing the game (if possible, probably needs spads support)",

      # Community related stuff
      "Accolades",
      "Reporting",

      # Global overrides
      "All chat",
      "All lobbies",
      "Site",
      "Matchmaking",
      "Community",# Accolades/Polls
      "Login",
    ]
  end

  @spec role_def(String.t()) :: nil | {String.t(), String.t()}
  def role_def("Default"), do: {"#AA0000", "fas fa-user"}
  def role_def("Admin"), do: {"#CE5C00", "fas fa-user-circle"}
  def role_def("Moderator"), do: {"#FFAA00", "fas fa-gavel"}
  def role_def("Developer"), do: {"#008800", "fas fa-code-branch"}
  def role_def("Contributor"), do: {"#00AA66", "fas fa-code-commit"}
  def role_def("Donor"), do: {"#0066AA", "fas fa-euro"}
  def role_def("Streamer"), do: {"#0066AA", "fab fa-twitch"}
  def role_def("Tester"), do: {"#00AACC", "fas fa-vial"}
  def role_def(_), do: nil
end
