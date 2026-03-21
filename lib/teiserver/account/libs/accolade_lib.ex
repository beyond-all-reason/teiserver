defmodule Teiserver.Account.AccoladeLib do
  @moduledoc false

  alias Ecto.Adapters.SQL
  alias Teiserver.Account
  alias Teiserver.Account.Accolade
  alias Teiserver.CacheUser
  alias Teiserver.Data.Types, as: T
  use TeiserverWeb, :library
  require Logger

  def miss_count_limit, do: 20

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-solid fa-award"

  @spec colours :: atom
  def colours, do: :info

  @spec make_favourite(map()) :: map()
  def make_favourite(accolade) do
    %{
      type_colour: StylingHelper.colours(colours()) |> elem(0),
      type_icon: icon(),
      item_id: accolade.id,
      item_type: "teiserver_account_accolade",
      item_colour: StylingHelper.colours(colours()) |> elem(0),
      item_icon: icon(),
      item_label: "#{accolade.name}",
      url: "/account/accolades/#{accolade.id}"
    }
  end

  # Queries
  @spec query_accolades() :: Ecto.Query.t()
  def query_accolades do
    from(accolades in Accolade)
  end

  @spec search(Ecto.Query.t(), map() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), atom(), any()) :: Ecto.Query.t()
  def _search(query, _key, ""), do: query
  def _search(query, _key, nil), do: query

  def _search(query, :id, id) do
    from accolades in query,
      where: accolades.id == ^id
  end

  def _search(query, :name, name) do
    from accolades in query,
      where: accolades.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from accolades in query,
      where: accolades.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from accolades in query,
      where: ilike(accolades.name, ^ref_like)
  end

  def _search(query, :filter, "all"), do: query
  def _search(query, :filter, {"all", _value}), do: query

  def _search(query, :filter, {"recipient", user_id}) do
    from accolades in query,
      where: accolades.recipient_id == ^user_id
  end

  def _search(query, :filter, {"giver", user_id}) do
    from accolades in query,
      where: accolades.giver_id == ^user_id
  end

  def _search(query, :filter, {"badge_type", type_id}) do
    from accolades in query,
      where: accolades.badge_type_id == ^type_id
  end

  def _search(query, :has_badge, true) do
    from accolades in query,
      where: not is_nil(accolades.badge_type_id)
  end

  def _search(query, :has_badge, false) do
    from accolades in query,
      where: is_nil(accolades.badge_type_id)
  end

  def _search(query, :user_id, user_id) do
    from accolades in query,
      where: accolades.giver_id == ^user_id or accolades.recipient_id == ^user_id
  end

  def _search(query, :giver_id, giver_id) do
    from accolades in query,
      where: accolades.giver_id == ^giver_id
  end

  def _search(query, :recipient_id, recipient_id_list) when is_list(recipient_id_list) do
    from accolades in query,
      where: accolades.recipient_id in ^recipient_id_list
  end

  def _search(query, :recipient_id, recipient_id) do
    from accolades in query,
      where: accolades.recipient_id == ^recipient_id
  end

  def _search(query, :badge_type_id, badge_type_id_list) when is_list(badge_type_id_list) do
    from accolades in query,
      where: accolades.badge_type_id in ^badge_type_id_list
  end

  def _search(query, :badge_type_id, badge_type_id) do
    from accolades in query,
      where: accolades.badge_type_id == ^badge_type_id
  end

  def _search(query, :inserted_after, timestamp) do
    from accolades in query,
      where: accolades.inserted_at >= ^timestamp
  end

  def _search(query, :inserted_before, timestamp) do
    from accolades in query,
      where: accolades.inserted_at < ^timestamp
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Name (A-Z)") do
    from accolades in query,
      order_by: [asc: accolades.name]
  end

  def order_by(query, "Name (Z-A)") do
    from accolades in query,
      order_by: [desc: accolades.name]
  end

  def order_by(query, "Newest first") do
    from accolades in query,
      order_by: [desc: accolades.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from accolades in query,
      order_by: [asc: accolades.inserted_at]
  end

  @spec preload(Ecto.Query.t(), list() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :badge_type in preloads, do: _preload_badge_type(query), else: query
    query = if :recipient in preloads, do: _preload_recipient(query), else: query
    query = if :giver in preloads, do: _preload_giver(query), else: query
    query
  end

  def _preload_badge_type(query) do
    from accolades in query,
      left_join: badge_types in assoc(accolades, :badge_type),
      preload: [badge_type: badge_types]
  end

  def _preload_recipient(query) do
    from accolades in query,
      left_join: recipients in assoc(accolades, :recipient),
      preload: [recipient: recipients]
  end

  def _preload_giver(query) do
    from accolades in query,
      left_join: givers in assoc(accolades, :giver),
      preload: [giver: givers]
  end

  @spec get_possible_ratings(T.userid(), [map()]) :: any
  def get_possible_ratings(userid, memberships) do
    their_membership = Enum.filter(memberships, fn m -> m.user_id == userid end) |> hd()

    teammate_ids =
      memberships
      # credo:disable-for-lines:2 Credo.Check.Refactor.FilterFilter
      |> Enum.filter(fn m -> m.team_id == their_membership.team_id and m.user_id != userid end)
      |> Enum.filter(fn m -> allow_accolades_for_user?(m.user_id) end)
      |> Enum.map(fn m -> m.user_id end)

    timestamp = Timex.now() |> Timex.shift(days: -5)

    # Get a list of everybody they reviewed recently
    existing =
      Account.list_accolades(
        search: [giver_id: userid, recipient_id: teammate_ids, inserted_after: timestamp]
      )
      |> Enum.map(fn a -> a.recipient_id end)

    # Now get a list of everybody from their team
    teammate_ids
    |> Enum.filter(fn m -> not Enum.member?(existing, m) end)
  end

  defp allow_accolades_for_user?(userid) do
    if CacheUser.restricted?(userid, ["Accolades", "Community"]) do
      false
    else
      stats = Account.get_user_stat_data(userid)
      accolade_miss_count = Map.get(stats, "accolade_miss_count", 0)

      if accolade_miss_count >= miss_count_limit() do
        false
      else
        true
      end
    end
  end

  @spec get_badge_types() :: [{non_neg_integer(), map()}]
  def get_badge_types do
    Teiserver.cache_get_or_store(:application_temp_cache, "accolade_badges", fn ->
      Account.list_badge_types(search: [purpose: "Accolade"], order_by: "Name (A-Z)")
      |> Enum.with_index()
      |> Enum.map(fn {bt, i} -> {i + 1, bt} end)
    end)
  end

  @spec get_giveable_accolade_types(boolean()) :: [map()]
  def get_giveable_accolade_types(is_ally?) do
    restriction =
      if is_ally? do
        "Ally"
      else
        "Enemy"
      end

    query =
      "select id, name, icon, colour from teiserver_account_badge_types tabt
      where (restriction in ($1) or restriction is null) and purpose = 'Accolade'
order by name;"

    results = SQL.query!(Repo, query, [restriction])

    results.rows
    |> Enum.map(fn [id, name, icon, colour] ->
      %{
        id: id,
        name: name,
        icon: icon,
        colour: colour
      }
    end)
  end

  @spec get_player_accolades(T.userid()) :: map()
  def get_player_accolades(userid) do
    Account.list_accolades(search: [recipient_id: userid, has_badge: true])
    |> Enum.map(fn a -> a.badge_type_id end)
    |> Enum.group_by(fn bt -> bt end)
    |> Map.new(fn {k, v} -> {k, Enum.count(v)} end)
  end

  def get_number_of_gifted_accolades(user_id, window_days) do
    query = """
    select count(*) from teiserver_account_accolades taa
    where taa.inserted_at >= now() - interval '#{window_days} day'
    and taa.giver_id = $1
    """

    results =
      SQL.query!(Repo, query, [user_id])

    [[count]] = results.rows
    count
  end

  def does_accolade_exist?(giver_id, recipient_id, match_id) do
    query = """
    select count(*) from teiserver_account_accolades taa
    where taa.giver_id = $1
    and taa.recipient_id = $2
    and taa.match_id = $3
    """

    results =
      SQL.query!(Repo, query, [giver_id, recipient_id, match_id])

    [[count]] = results.rows
    count > 0
  end

  # Fetch the number of unique givers who have given at least one accolade to this recipient
  def get_unique_giver_count(recipient_id) do
    query = """
    select count(distinct taa.giver_id), count(*) from teiserver_account_accolades taa
    where taa.recipient_id  = $1
    and taa.badge_type_id is not null
    """

    result =
      SQL.query!(Repo, query, [recipient_id])

    [[unique_giver_count, total_accolades]] = result.rows

    {unique_giver_count, total_accolades}
  end

  # Returns information about the most recent accolade that was received during the window.
  def recent_accolade(recipient_id, window_days) do
    query = """
    select map, au.name from teiserver_account_accolades taa
    inner join teiserver_battle_matches tbm
    on tbm.id = taa.match_id
    inner join account_users au
    on au.id = taa.giver_id
    where taa.inserted_at >= now() - interval '#{window_days} day'
    and recipient_id = $1
    order by taa.inserted_at  desc
    limit 1
    """

    result =
      SQL.query!(Repo, query, [recipient_id])

    case result.num_rows do
      1 ->
        [[map, giver_name]] = result.rows

        %{
          map: map,
          giver_name: giver_name
        }

      _other ->
        nil
    end
  end
end
