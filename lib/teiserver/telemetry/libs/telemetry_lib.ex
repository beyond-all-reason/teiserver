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
      last_value("spring_raw.kick_user_from_battle")
    ]
  end

  @spec periodic_measurements() :: List.t()
  def periodic_measurements() do
    [
      # {Teiserver.Telemetry, :measure_users, []},
      # {:process_info,
      #   event: [:teiserver, :ts],
      #   name: Teiserver.Telemetry.TelemetryServer,
      #   keys: [:message_queue_len, :memory]}
    ]
  end
end
