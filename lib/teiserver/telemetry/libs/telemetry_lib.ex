defmodule Teiserver.Telemetry.TelemetryLib do
  @moduledoc false
  import Telemetry.Metrics
  alias Teiserver.Telemetry.TelemetryServer

  @spec colours :: atom
  def colours(), do: :warning2

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-heart-pulse"

  @spec get_totals_and_reset :: map()
  def get_totals_and_reset() do
    # credo:disable-for-next-line Credo.Check.Readability.PreferImplicitTry
    try do
      GenServer.call(TelemetryServer, :get_totals_and_reset)
      # In certain situations (e.g. just after startup) it can be
      # the process hasn't started up so we need to handle that
      # without dying
    catch
      :exit, _ ->
        nil
    end
  end

  @spec increment(any) :: :ok
  def increment(key) do
    send(TelemetryServer, {:increment, key})
    :ok
  end

  @spec cast_to_server(any) :: :ok
  def cast_to_server(msg) do
    GenServer.cast(TelemetryServer, msg)
  end

  @spec metrics() :: List.t()
  def metrics() do
    [
      last_value("teiserver.client.total"),
      last_value("teiserver.client.menu"),
      last_value("teiserver.client.lobby"),
      last_value("teiserver.client.spectator"),
      last_value("teiserver.client.player"),
      last_value("teiserver.battle.total"),
      last_value("teiserver.battle.lobby"),
      last_value("teiserver.battle.in_progress"),

      # Spring legacy pubsub trackers, multiplied by the number of users
      # User
      last_value("spring_mult.user_logged_in"),
      last_value("spring_mult.user_logged_out"),

      # Client
      last_value("spring_mult.mystatus"),

      # Battle
      last_value("spring_mult.global_battle_updated"),
      last_value("spring_mult.add_user_to_battle"),
      last_value("spring_mult.remove_user_from_battle"),
      last_value("spring_mult.kick_user_from_battle"),

      # Spring legacy pubsub trackers, raw update count only
      # User
      last_value("spring_raw.user_logged_in"),
      last_value("spring_raw.user_logged_out"),

      # Client
      last_value("spring_raw.mystatus"),

      # Battle
      last_value("spring_raw.global_battle_updated"),
      last_value("spring_raw.add_user_to_battle"),
      last_value("spring_raw.remove_user_from_battle"),
      last_value("spring_raw.kick_user_from_battle"),
      distribution(
        [:teiserver, :spring, :in, :duration],
        event_name: [:spring, :in],
        measurement: :duration,
        reporter_options: [
          buckets: [1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597, 2584, 4181]
        ],
        tags: [:command]
      ),
      distribution(
        [:teiserver, :spring, :out, :duration],
        event_name: [:spring, :out],
        measurement: :duration,
        reporter_options: [
          buckets: [1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597, 2584, 4181]
        ],
        tags: [:command]
      ),
      counter(
        [:teiserver, :spring, :in, :count],
        event_name: [:spring, :in],
        measurement: :count,
        tags: [:command]
      ),
      counter(
        [:teiserver, :spring, :out, :count],
        event_name: [:spring, :out],
        measurement: :count,
        tags: [:command]
      )
    ]
  end
end
