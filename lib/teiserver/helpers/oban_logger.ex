defmodule Teiserver.Helper.ObanLogger do
  @moduledoc false
  require Logger

  def handle_event([:oban, :job, :start], _measure, _meta, _) do
    # Logger.warning("[Oban] :started #{meta.worker} at #{measure.system_time}")
  end

  def handle_event([:oban, :job, :exception], %{duration: duration}, meta, nil) do
    # data = %{
    #   conn: %{
    #     request_path: "Oban:#{meta.worker}",
    #     method: "Oban worker - Error",
    #     assigns: %{current_user: %{id: nil}, cache: %{}},
    #     remote_ip: {},
    #     params: meta.args
    #   },
    #   reason: meta.error,
    #   stack: meta.stack
    # }

    error_str = inspect(meta.reason)

    Logger.warning(
      "[Oban] [failure] [#{meta.queue}] #{meta.worker} failed in #{duration} - #{error_str}"
    )
  end

  def handle_event([:oban, :circuit, :trip], _measure, _meta, _) do
    # data = %{
    #   conn: %{
    #     request_path: "Oban:#{meta.worker}",
    #     method: "Oban worker - trip_circuit",
    #     assigns: %{current_user: %{id: nil}, cache: %{}},
    #     remote_ip: {},
    #     params: meta.args
    #   },
    #   reason: meta.error,
    #   stack: meta.stack
    # }

    Logger.error("[Oban] [failure]")
  end

  def handle_event([:oban, :job, :stop], %{duration: duration}, meta, _) do
    Logger.info(
      "[Oban] stop #{meta.worker} ran in #{System.convert_time_unit(duration, :native, :millisecond)}ms"
    )
  end
end
