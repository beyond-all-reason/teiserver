defmodule Teiserver.Logging.ServerDayLogLib do
  @moduledoc false
  use TeiserverWeb, :library

  alias Teiserver.Logging.ServerDayLog

  @spec colours :: atom
  def colours(), do: :warning

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-heart-pulse"

  @spec get_server_day_logs :: Ecto.Query.t()
  def get_server_day_logs() do
    from(logs in ServerDayLog)
  end

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

  def _search(query, :date, date) do
    from logs in query,
      where: logs.date == ^date
  end

  def _search(query, :start_date, date) do
    from logs in query,
      where: logs.date >= ^date
  end

  def _search(query, :end_date, date) do
    from logs in query,
      where: logs.date <= ^date
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Newest first") do
    from logs in query,
      order_by: [desc: logs.date]
  end

  def order_by(query, "Oldest first") do
    from logs in query,
      order_by: [asc: logs.date]
  end

  @user_types ~w(menu lobby player spectator total)a

  # [] List means 1 day segments
  # %{} Dict means total for the block of that key
  # 0 Integer means sum or average
  @empty_log %{
    # Used to make calculating the end of month stats easier, this will not appear in the final result
    tmp_reduction: %{
      unique_users: [],
      unique_players: [],
      accounts_created: 0,
      peak_user_counts: @user_types |> Map.new(fn t -> {t, 0} end),
      battles: 0
    },
    events: %{
      complex_client: %{},
      simple_client: %{},
      complex_anon: %{},
      simple_anon: %{},
      complex_server: %{},
      simple_server: %{},
      complex_lobby: %{},
      simple_lobby: %{},
      complex_match: %{},
      simple_match: %{}
    },

    # Monthly totals
    aggregates: %{
      # Stats will be overwritten by tmp_reductions
      stats: nil,

      # Total number of minutes spent doing that across all players that month
      minutes: %{
        player: 0,
        spectator: 0,
        lobby: 0,
        menu: 0,
        total: 0
      }
    }
  }

  @spec aggregate_day_logs(list()) :: map()
  def aggregate_day_logs(logs) do
    logs
    |> Enum.reduce(@empty_log, fn log, acc ->
      extend_segment(acc, log)
    end)
    |> calculate_aggregates()
  end

  # Given an existing segment and a batch of logs, calculate the segment and add them together
  defp extend_segment(existing, {%{data: data} = _server_log, %{data: activity} = _activity_log}) do
    %{
      # Used to make calculating the end of day stats easier, this will not appear in the final result
      tmp_reduction: %{
        battles: existing.tmp_reduction.battles + get_in(data, ~w(aggregates stats battles)),
        unique_users:
          existing.tmp_reduction.unique_users ++
            Map.keys(activity["total"]),
        unique_players:
          existing.tmp_reduction.unique_players ++
            Map.keys(activity["player"]),
        accounts_created:
          existing.tmp_reduction.accounts_created +
            get_in(data, ~w(aggregates stats accounts_created)),
        peak_user_counts:
          @user_types
          |> Map.new(fn type ->
            {type,
             max(
               get_in(existing, [:tmp_reduction, :peak_user_counts, type]),
               get_in(data, ["aggregates", "stats", "peak_user_counts", to_string(type)])
             )}
          end)
      },

      # Telemetry events
      events: %{
        complex_client:
          add_maps(existing.events.complex_client, get_in(data, ~w(events complex_client))),
        simple_client:
          add_maps(existing.events.simple_client, get_in(data, ~w(events simple_client))),
        complex_anon:
          add_maps(existing.events.complex_anon, get_in(data, ~w(events complex_anon))),
        simple_anon: add_maps(existing.events.simple_anon, get_in(data, ~w(events simple_anon))),
        complex_server:
          add_maps(existing.events.complex_server, get_in(data, ~w(events complex_server))),
        simple_server:
          add_maps(existing.events.simple_server, get_in(data, ~w(events simple_server))),
        complex_lobby:
          add_maps(existing.events.complex_lobby, get_in(data, ~w(events complex_lobby))),
        simple_lobby:
          add_maps(existing.events.simple_lobby, get_in(data, ~w(events simple_lobby))),
        complex_match:
          add_maps(existing.events.complex_match, get_in(data, ~w(events complex_match))),
        simple_match:
          add_maps(existing.events.simple_match, get_in(data, ~w(events simple_match)))
      },

      # Monthly totals
      aggregates: %{
        stats: nil,

        # Total number of minutes spent doing that across all players that month
        minutes: %{
          player:
            existing.aggregates.minutes.player + get_in(data, ~w(aggregates minutes player)),
          spectator:
            existing.aggregates.minutes.spectator + get_in(data, ~w(aggregates minutes spectator)),
          lobby: existing.aggregates.minutes.lobby + get_in(data, ~w(aggregates minutes lobby)),
          menu: existing.aggregates.minutes.menu + get_in(data, ~w(aggregates minutes menu)),
          total: existing.aggregates.minutes.total + get_in(data, ~w(aggregates minutes total))
        }
      }
    }
  end

  # Given a day log, calculate the end of day stats
  defp calculate_aggregates(data) do
    aggregate_stats = %{
      accounts_created: data.tmp_reduction.accounts_created,
      unique_users: data.tmp_reduction.unique_users |> Enum.uniq() |> Enum.count(),
      unique_players: data.tmp_reduction.unique_players |> Enum.uniq() |> Enum.count(),
      peak_user_counts: data.tmp_reduction.peak_user_counts
    }

    put_in(data, ~w(aggregates stats)a, aggregate_stats)
    |> Map.delete(:tmp_reduction)
  end

  defp add_maps(m1, nil), do: m1

  defp add_maps(m1, m2) do
    Map.merge(m1, m2, fn _k, v1, v2 -> v1 + v2 end)
  end
end
