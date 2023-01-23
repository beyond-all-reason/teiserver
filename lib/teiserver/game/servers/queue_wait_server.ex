defmodule Teiserver.Game.QueueWaitServer do
  @moduledoc """
  This is the server used to match players for a battle before passing them off
  to a QueueMatchServer.
  """

  use GenServer
  require Logger
  alias Teiserver.Data.{Matchmaking, QueueGroup}
  alias Phoenix.PubSub
  alias Teiserver.{Account, Telemetry}
  alias Teiserver.Data.Types, as: T

  @default_telemetry_interval 60_000
  @default_range_increase_interval 30_000
  @default_tick_interval 250
  @update_interval 2_500
  @max_range 5

  def handle_call({:add_group, %QueueGroup{members: _, rating: _} = group}, _from, state) do
    {resp, new_state} =
      cond do
        Map.has_key?(state.groups_map, group.id) ->
          {:duplicate, state}

        Enum.count(group.members) > state.team_size ->
          {:oversized_group, state}

        true ->
          bucket_key = bucket_function(group)

          new_group = %{group |
            bucket: bucket_key,
            max_distance: (state.settings["max_range"] || @max_range)
          }
          new_groups_map = Map.put(state.groups_map, group.id, new_group)

          new_bucket = [group.id | Map.get(state.buckets, bucket_key, [])]
          new_buckets = Map.put(state.buckets, bucket_key, new_bucket)

          new_state = %{
            state
            | buckets: new_buckets,
              groups_map: new_groups_map,
              skip: false,
              join_count: (state.join_count + 1)
          }

          # If it's a party, tell the party they are now in the queue
          if not is_integer(group.id) do
            Account.party_join_queue(group.id, state.id)
          end

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_queue:#{state.queue_id}",
            %{
              channel: "teiserver_queue:#{state.queue_id}",
              event: :queue_add_group,
              queue_id: state.queue_id,
              group_id: group.id
            }
          )

          group.members
          |> Enum.each(fn userid ->
            PubSub.broadcast(
              Central.PubSub,
              "teiserver_client_messages:#{userid}",
              %{
                channel: "teiserver_client_messages:#{userid}",
                event: :matchmaking,
                sub_event: :joined_queue,
                queue_id: state.queue_id
              }
            )
          end)

          {:ok, new_state}
      end

    {:reply, resp, new_state}
  end

  def handle_call({:remove_group, group_id}, _from, state) do
    {resp, new_state} =
      case Map.has_key?(state.groups_map, group_id) do
        true ->
          new_state = remove_group(group_id, state)

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_queue:#{state.queue_id}",
            %{
              channel: "teiserver_queue:#{state.queue_id}",
              event: :queue_remove_group,
              queue_id: state.queue_id,
              group_id: group_id
            }
          )

          state.groups_map[group_id]
            |> Map.get(:members)
            |> Enum.each(fn userid ->
              PubSub.broadcast(
                Central.PubSub,
                "teiserver_client_messages:#{userid}",
                %{
                  channel: "teiserver_client_messages:#{userid}",
                  event: :matchmaking,
                  sub_event: :left_queue,
                  queue_id: state.queue_id
                }
              )
            end)

          {:ok, %{new_state | leave_count: (state.leave_count + 1)}}

        false ->
          {:missing, state}
      end

    {:reply, resp, new_state}
  end

  def handle_call(:get_info, _from, state) do
    resp = %{
      mean_wait_time: state.mean_wait_time,
      member_count: Enum.count(state.groups_map)
    }

    {:reply, resp, state}
  end

  def handle_cast({:re_add_group, group}, state) do
    {_resp, new_state} =
      case Map.has_key?(state.groups_map, group.id) do
        true ->
          {:duplicate, state}

        false ->
          new_groups_map = Map.put(state.groups_map, group.id, group)

          bucket_range = (group.bucket - group.search_distance)..(group.bucket + group.search_distance)

          new_buckets = bucket_range
            |> Enum.reduce(state.buckets, fn (bucket_key, state_buckets) ->
              new_bucket = [group.id | Map.get(state_buckets, bucket_key, [])]

              Map.put(state_buckets, bucket_key, new_bucket)
            end)

          new_state = %{
            state
            | buckets: new_buckets,
              groups_map: new_groups_map,
              skip: false,
              join_count: (state.join_count + 1)
          }

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_queue:#{state.queue_id}",
            %{
              channel: "teiserver_queue:#{state.queue_id}",
              event: :queue_add_group,
              queue_id: state.queue_id,
              group_id: group.id
            }
          )

          group.members
          |> Enum.each(fn userid ->
            PubSub.broadcast(
              Central.PubSub,
              "teiserver_client_messages:#{userid}",
              %{
                channel: "teiserver_client_messages:#{userid}",
                event: :matchmaking,
                sub_event: :joined_queue,
                queue_id: state.queue_id
              }
            )
          end)

          {:ok, new_state}
      end

    {:noreply, new_state}
  end

  def handle_info({:refresh_from_db, db_queue}, state) do
    update_state_from_db(state, db_queue)
  end

  def handle_info(:increase_range, state) do
    # First we go through all the groups, those that are going to be
    # expanded we map out as going into new buckets
    # at the end of this, new_bucket_entries should be a map
    # of %{bucket_key => [group_id]}
    new_bucket_entries = state.groups_map
      |> Map.values
      |> Enum.filter(fn group ->
        group.search_distance < group.max_distance
      end)
      |> Enum.map(fn group ->
        [
          {group.bucket - group.search_distance - 1, group.id},
          {group.bucket + group.search_distance + 1, group.id}
        ]
      end)
      |> List.flatten
      |> Enum.group_by(fn {bucket, _group_id} ->
        bucket
      end, fn {_bucket, group_id} ->
        group_id
      end)

    new_buckets = (Map.keys(state.buckets) ++ Map.keys(new_bucket_entries))
      |> Enum.uniq
      |> Map.new(fn key ->
        contents = (state.buckets[key] || []) ++ (new_bucket_entries[key] || [])
          |> Enum.uniq
        {key, contents}
      end)

    # Update the groups
    new_groups_map = state.groups_map
      |> Map.new(fn {group_id, group} ->
        new_group = if group.search_distance < group.max_distance do
          Map.put(group, :search_distance, group.search_distance + 1)
        else
          group
        end

        {group_id, new_group}
      end)

    {:noreply, %{state |
      groups_map: new_groups_map,
      buckets: new_buckets
    }}
  end

  def handle_info(:telemetry_tick, state) do
    member_count = if Enum.empty?(state.groups_map) do
      0
    else
      state.groups_map
        |> Map.values
        |> Enum.map(fn group -> Enum.count(group.members) end)
        |> Enum.sum
    end

    Telemetry.cast_to_server({:matchmaking_update, state.queue_id, %{
      mean_wait_time: calculate_mean_wait_time(state),
      member_count: member_count,
      join_count: state.join_count,
      leave_count: state.leave_count,
      found_match_count: state.found_match_count
    }})

    {:noreply, %{state |
      recent_wait_times: [],
      old_wait_times: state.recent_wait_times,
      join_count: 0,
      leave_count: 0,
      found_match_count: 0
    }}
  end

  def handle_info(:broadcast_update, state) do
    mean_wait_time = calculate_mean_wait_time(state)

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_queue_all_queues",
      {:queue_periodic_update, state.queue_id, Enum.count(state.groups_map), mean_wait_time}
    )
    {:noreply, %{state | mean_wait_time: mean_wait_time}}
  end

  def handle_info(:tick, %{skip: true} = state) do
    :timer.send_after(state.tick_interval, :tick)
    {:noreply, state}
  end

  def handle_info(:tick, state) do
    new_state = case main_loop_search(state) do
      nil ->
        state

      {selected_groups, new_buckets, new_groups_map} ->
        Matchmaking.create_match(selected_groups, state.queue_id)

        wait_times = selected_groups
          |> Enum.map(fn g -> System.system_time(:second) - g.join_time end)

        %{state |
          buckets: new_buckets,
          groups_map: new_groups_map,
          found_match_count: (state.found_match_count + 1),
          recent_wait_times: state.recent_wait_times ++ wait_times
        }
    end

    :timer.send_after(state.tick_interval, :tick)
    {:noreply, new_state}
  end

  def handle_info({:update, :settings, new_list}, state),
    do: {:noreply, %{state | settings: new_list}}

  def handle_info({:update, :map_list, new_list}, state),
    do: {:noreply, %{state | map_list: new_list}}


  @spec find_matches_in_bucket(map(), [non_neg_integer()], non_neg_integer()) :: list()
  defp find_matches_in_bucket(state, group_id_list, bucket_key) do
    group_list = group_id_list
      |> Enum.map(fn group_id -> state.groups_map[group_id] end)

    user_count = group_list
      |> Enum.map(fn group -> group.count end)
      |> Enum.sum

    if user_count >= state.players_needed do
      select_groups_for_balance(state, group_list, bucket_key)
    else
      nil
    end
  end

  @spec select_groups_for_balance(map(), [QueueGroup.t()], non_neg_integer()) :: [QueueGroup.t()]
  defp select_groups_for_balance(state, group_list, bucket_key) do
    # We just need to find N teams of S people, then we balance it
    # largest groups first, we don't care about which team
    # they are on, that will be handled by the MatchServer

    # First we sort the group list, should be biggest groups first followed
    # by the groups closest to the correct bucket
    group_list = group_list
      |> Enum.sort_by(fn group -> {group.count, -abs(group.bucket - bucket_key)} end, &>=/2)

    # Now we iterate through each team_id and pick groups
    # it doesn't matter which team they are picked for as we'll be balancing it later
    {picks, _} = 1..state.team_count
      |> Enum.map_reduce(group_list, fn (_team_id, remaining_groups) ->
        # Grab the first groups we find from the list as long as they match the required size
        picked = pick_groups_from_list_to_size(remaining_groups, state.team_size, [])

        # Failure happens when we have enough users but can't fit them into
        # the right number of teams (e.g. 3 groups of 2 for a 3v3)#
        # previously it would also happen as the result of a bug
        if picked == :failure do
          {[], []}
        else
          # Convert the groups to ids
          picked_ids = picked |> Enum.map(fn g -> g.id end)

          # Strip out from the list any groups we've picked
          new_remaining = remaining_groups
            |> Enum.reject(fn g -> Enum.member?(picked_ids, g.id) end)

          # map and reduce
          {picked, new_remaining}
        end
      end)

    # Picks will now be a list of groups picked for balancing, we don't care which
    # team they were picked as a part of since we don't handle balance here
    List.flatten(picks)
  end

  # Recursively goes through a list and gets the first groups that match it's criteria of size
  defp pick_groups_from_list_to_size(_, 0, acc), do: acc
  defp pick_groups_from_list_to_size([], _, _), do: :failure

  defp pick_groups_from_list_to_size([first_group | remaining_list], target_size, acc) do
    if first_group.count <= target_size do
      new_acc = [first_group | acc]
      new_target = target_size - first_group.count

      pick_groups_from_list_to_size(remaining_list, new_target, new_acc)
    else
      pick_groups_from_list_to_size(remaining_list, target_size, acc)
    end
  end

  # Returns a list of the groups selected for the next match (nil if no match found)
  # the new buckets and the new groups_map
  @spec main_loop_search(map()) :: {list(), map(), map()} | nil
  defp main_loop_search(state) do
    selected_groups = state.buckets
      |> Stream.filter(fn {_bucket_key, group_list} ->
        max_count = group_list
          |> Enum.map(fn group_id ->
            Enum.count(state.groups_map[group_id].members)
          end)
          |> Enum.sum

        max_count >= state.players_needed
      end)
      |> Stream.map(fn {bucket_key, group_list} ->
        find_matches_in_bucket(state, group_list, bucket_key)
      end)
      |> Stream.reject(&(&1 == nil))
      |> Stream.take(1)
      |> Enum.to_list
      |> List.flatten

    if Enum.empty?(selected_groups) do
      nil
    else
      selected_ids = selected_groups
        |> Enum.map(fn g -> g.id end)

      # Drop the selected ids from any bucket values
      new_buckets = state.buckets
        |> Map.new(fn {key, bucket_list} ->
          {key, Enum.reject(bucket_list, fn g_id -> Enum.member?(selected_ids, g_id) end)}
        end)
        |> Map.filter(fn {_, bucket_list} -> not Enum.empty?(bucket_list) end)

      # Drop the groups from the groups_map too
      new_groups_map = Map.drop(state.groups_map, selected_ids)

      {selected_groups, new_buckets, new_groups_map}
    end
  end

  # Used to remove players from all aspects of the queue, either because
  # they left or their game started
  @spec remove_group(T.userid() | String.t(), Map.t()) :: Map.t()
  defp remove_group(group_id, state) do
    # Drop the selected ids from any bucket values
    new_buckets = state.buckets
      |> Map.new(fn {key, bucket_list} ->
        {key, List.delete(bucket_list, group_id)}
      end)
      |> Map.filter(fn {_, bucket_list} -> not Enum.empty?(bucket_list) end)

    new_groups_map = Map.drop(state.groups_map, [group_id])

    %{state |
      buckets: new_buckets,
      groups_map: new_groups_map
    }
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  defp update_state_from_db(state, db_queue) do
    Map.merge(state, %{
      id: db_queue.id,
      team_size: db_queue.team_size,
      team_count: db_queue.team_count,
      players_needed: (db_queue.team_size * db_queue.team_count),
      map_list: db_queue.map_list |> Enum.map(fn m -> String.trim(m) end),
      settings: db_queue.settings,
      tick_interval: db_queue.settings["tick_interval"] || @default_tick_interval
    })
  end

  @spec bucket_function(QueueGroup.t()) :: non_neg_integer()
  defp bucket_function(%QueueGroup{rating: rating}) do
    rating
      |> round
      |> max(1)
  end

  defp calculate_mean_wait_time(state) do
    wait_times = state.recent_wait_times ++ state.old_wait_times

    Enum.sum(wait_times)/(Enum.count(wait_times) + 1)
  end

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    :timer.send_interval(@default_telemetry_interval, self(), :telemetry_tick)
    :timer.send_interval(@default_range_increase_interval, self(), :increase_range)
    :timer.send_interval(@update_interval, self(), :broadcast_update)

    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.QueueWaitRegistry,
      opts.queue.id,
      opts.queue.id
    )

    state = update_state_from_db(%{
      buckets: %{},
      groups_map: %{},

      skip: false,
      queue_id: opts.queue.id,

      # Telemetry related
      mean_wait_time: 0,
      recent_wait_times: [],
      old_wait_times: [],
      join_count: 0,
      leave_count: 0,
      found_match_count: 0
    }, opts.queue)

    send(self(), :tick)

    {:ok, state}
  end
end
