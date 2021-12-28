defmodule Teiserver.Account.AccoladeLib do
  use CentralWeb, :library
  alias Teiserver.Account
  alias Teiserver.Account.{Accolade, AccoladeBotServer}
  alias Teiserver.Data.Types, as: T

  # Functions
  @spec icon :: String.t()
  def icon, do: "far fa-award"

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:info)

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(accolade) do
    %{
      type_colour: colours() |> elem(0),
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
  @spec query_accolades() :: Ecto.Query.t
  def query_accolades do
    from accolades in Accolade
  end

  @spec search(Ecto.Query.t, Map.t | nil) :: Ecto.Query.t
  def search(query, nil), do: query
  def search(query, params) do
    params
    |> Enum.reduce(query, fn ({key, value}, query_acc) ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t, Atom.t(), any()) :: Ecto.Query.t
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

  def _search(query, :simple_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from accolades in query,
      where: (
            ilike(accolades.name, ^ref_like)
        )
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

  def _search(query, :user_id, user_id) do
    from accolades in query,
      where: (accolades.giver_id == ^user_id or accolades.recipient_id == ^user_id)
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

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
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

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, _preloads) do
    # query = if :things in preloads, do: _preload_things(query), else: query
    query
  end

  # def _preload_things(query) do
  #   from accolades in query,
  #     left_join: things in assoc(accolades, :things),
  #     preload: [things: things]
  # end


  @spec do_start() :: :ok
  defp do_start() do
    # Start the supervisor server
    {:ok, _accolade_server_pid} =
      DynamicSupervisor.start_child(Teiserver.Coordinator.DynamicSupervisor, {
        Teiserver.Account.AccoladeBotServer,
        name: Teiserver.Account.AccoladeBotServer,
        data: %{}
      })
    :ok
  end

  # @spec get_accolade_bot_pid() :: pid()
  # defp get_accolade_bot_pid() do
  #   ConCache.get(:teiserver_accolade_server, :accolade_server)
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
      nil -> nil
      pid -> GenServer.call(pid, msg)
    end
  end

  @spec get_accolade_bot_userid() :: T.userid()
  def get_accolade_bot_userid() do
    ConCache.get(:application_metadata_cache, "teiserver_accolade_userid")
  end

  @spec get_accolade_bot_pid() :: pid() | nil
  def get_accolade_bot_pid() do
    ConCache.get(:teiserver_accolade_pids, :accolade_bot)
  end

  @spec get_possible_ratings(T.userid(), [map()]) :: any
  def get_possible_ratings(userid, memberships) do
    member_ids = Enum.map(memberships, fn m -> m.user_id end)
    timestamp = Timex.now() |> Timex.shift(days: -5)

    # Get a list of everybody they reviewed recently
    existing = Account.list_accolades(search: [giver_id: userid, recipient_id: member_ids, inserted_after: timestamp])
    |> Enum.map(fn a -> a.recipient_id end)

    # Now get a list of everybody in the match minus the ones they have reviewed recently
    member_ids
    |> Enum.filter(fn m -> not Enum.member?(existing, m) and m != userid end)
  end
end
