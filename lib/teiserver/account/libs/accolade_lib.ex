defmodule Teiserver.Account.AccoladeLib do
  @moduledoc """

  """
  use TeiserverWeb, :library
  alias Teiserver.{Account, CacheUser}
  alias Teiserver.Account.{Accolade, AccoladeBotServer, AccoladeChatServer}
  alias Teiserver.Data.Types, as: T
  require Logger

  def miss_count_limit(), do: 20

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-regular fa-award"

  @spec colours :: atom
  def colours, do: :info

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(accolade) do
    %{
      type_colour: StylingHelper.colours(colours()) |> elem(0),
      type_icon: icon(),
      item_id: accolade.id,
      item_type: "teiserver_account_accolade",
      item_colour: colours() |> elem(0),
      item_icon: Teiserver.Account.AccoladeLib.icon(),
      item_label: "#{accolade.name}",
      url: "/account/accolades/#{accolade.id}"
    }
  end

  # Queries
  @spec query_accolades() :: Ecto.Query.t()
  def query_accolades do
    from(accolades in Accolade)
  end

  @spec search(Ecto.Query.t(), Map.t() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), Atom.t(), any()) :: Ecto.Query.t()
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

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
  def _search(query, :filter, {"all", _}), do: query

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

  @spec preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
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

  @spec do_start() :: :ok
  defp do_start() do
    # Start the supervisor server
    {:ok, _accolade_server_pid} =
      DynamicSupervisor.start_child(Teiserver.Account.AccoladeSupervisor, {
        AccoladeBotServer,
        name: Teiserver.Account.AccoladeBotServer, data: %{}
      })

    :ok
  end

  # @spec get_accolade_bot_pid() :: pid()
  # defp get_accolade_bot_pid() do
  #   Teiserver.cache_get(:teiserver_accolade_server, :accolade_server)
  # end

  @spec start_accolade_server() :: :ok | {:failure, String.t()}
  def start_accolade_server() do
    cond do
      get_accolade_bot_userid() != nil ->
        {:failure, "Already started"}

      true ->
        do_start()
    end
  end

  @spec cast_accolade_bot(any) :: any
  def cast_accolade_bot(msg) do
    case get_accolade_bot_pid() do
      nil -> nil
      pid -> send(pid, msg)
    end
  end

  @spec call_accolade_bot(any) :: any
  def call_accolade_bot(msg) do
    case get_accolade_bot_pid() do
      nil ->
        nil

      pid ->
        try do
          GenServer.call(pid, msg)

          # If the process has somehow died, we just return nil
        catch
          :exit, _ ->
            nil
        end
    end
  end

  @spec get_accolade_bot_userid() :: T.userid()
  def get_accolade_bot_userid() do
    Teiserver.cache_get(:application_metadata_cache, "teiserver_accolade_userid")
  end

  @spec get_accolade_bot_pid() :: pid() | nil
  def get_accolade_bot_pid() do
    case Horde.Registry.lookup(Teiserver.AccoladesRegistry, "AccoladeBotServer") do
      [{pid, _}] ->
        pid

      _ ->
        nil
    end
  end

  @spec get_accolade_chat_pid(T.userid()) :: pid() | nil
  def get_accolade_chat_pid(userid) do
    case Horde.Registry.lookup(Teiserver.AccoladesRegistry, "AccoladeChatServer:#{userid}") do
      [{pid, _}] ->
        pid

      _ ->
        nil
    end
  end

  @spec cast_accolade_chat(T.userid(), any) :: any
  def cast_accolade_chat(userid, msg) do
    case get_accolade_chat_pid(userid) do
      nil -> nil
      pid -> send(pid, msg)
    end
  end

  @spec get_possible_ratings(T.userid(), [map()]) :: any
  def get_possible_ratings(userid, memberships) do
    their_membership = Enum.filter(memberships, fn m -> m.user_id == userid end) |> hd

    teammate_ids =
      memberships
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
    if CacheUser.is_restricted?(userid, ["Accolades", "Community"]) do
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

  @spec start_chat_server(T.userid(), T.userid(), T.lobby_id()) :: pid()
  def start_chat_server(userid, recipient_id, match_id) do
    {:ok, chat_server_pid} =
      DynamicSupervisor.start_child(Teiserver.Account.AccoladeSupervisor, {
        AccoladeChatServer,
        name: "accolade_chat_#{userid}",
        data: %{
          userid: userid,
          recipient_id: recipient_id,
          match_id: match_id
        }
      })

    chat_server_pid
  end

  @spec start_accolade_process(T.userid(), T.userid(), T.lobby_id()) :: :ok | :existing
  def start_accolade_process(userid, recipient_id, match_id) do
    case get_accolade_chat_pid(userid) do
      nil ->
        start_chat_server(userid, recipient_id, match_id)

      _pid ->
        :existing
    end
  end

  @spec get_badge_types() :: [{non_neg_integer(), map()}]
  def get_badge_types() do
    Teiserver.cache_get_or_store(:application_temp_cache, "accolade_badges", fn ->
      Account.list_badge_types(search: [purpose: "Accolade"], order_by: "Name (A-Z)")
      |> Enum.with_index()
      |> Enum.map(fn {bt, i} -> {i + 1, bt} end)
    end)
  end

  @spec get_player_accolades(T.userid()) :: map()
  def get_player_accolades(userid) do
    Account.list_accolades(search: [recipient_id: userid, has_badge: true])
    |> Enum.map(fn a -> a.badge_type_id end)
    |> Enum.group_by(fn bt -> bt end)
    |> Map.new(fn {k, v} -> {k, Enum.count(v)} end)
  end

  @spec live_debug :: nil | :ok
  def live_debug do
    case get_accolade_bot_pid() do
      nil ->
        Logger.error("Error, no accolade bot pid")

      pid ->
        state = :sys.get_state(pid)
        children = DynamicSupervisor.which_children(Teiserver.Account.AccoladeSupervisor)
        child_count = Enum.count(children) - 1

        Logger.info("Accolade bot found, state is:")
        Logger.info("#{Kernel.inspect(state)}")
        Logger.info("Accolade chat count: #{child_count}")

        if Enum.count(children) > 1 do
          Logger.info("Pinging all chat servers...")

          pings =
            children
            |> ParallelStream.filter(fn {_, _, _, [module]} ->
              module == Teiserver.Account.AccoladeChatServer
            end)
            |> ParallelStream.map(fn {_, pid, _, _} ->
              case GenServer.call(pid, :ping, 5000) do
                :ok -> :ok
                _ -> :not_okay
              end
            end)
            |> Enum.filter(fn p -> p == :ok end)

          rate = (Enum.count(pings) / child_count * 100) |> round

          Logger.info(
            "Out of #{child_count} children, #{Enum.count(pings)} respond to ping (#{rate}%)"
          )
        end
    end
  end
end
