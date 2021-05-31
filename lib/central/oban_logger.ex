defmodule Central.ObanLogger do
  require Logger

  import Central.Logging.Helpers, only: [add_error_log: 1]

  def handle_event([:oban, :job, :start], _measure, _meta, _) do
    # Logger.warn("[Oban] :started #{meta.worker} at #{measure.system_time}")
  end

  def handle_event([:oban, :job, :exception], _measure, meta, _) do
    data = %{
      conn: %{
        request_path: "Oban:#{meta.worker}",
        method: "Oban worker - Error",
        assigns: %{current_user: %{id: nil}, cache: %{}},
        remote_ip: {},
        params: meta.args
      },
      reason: meta.error,
      stack: meta.stack
    }

    log = add_error_log(data)

    error_str = Kernel.inspect(meta.error)
    Logger.error("[Oban] [failure] #{error_str} Logged as ##{log.id}")
  end

  def handle_event([:oban, :circuit, :trip], _measure, meta, _) do
    data = %{
      conn: %{
        request_path: "Oban:#{meta.worker}",
        method: "Oban worker - trip_circuit",
        assigns: %{current_user: %{id: nil}, cache: %{}},
        remote_ip: {},
        params: meta.args
      },
      reason: meta.error,
      stack: meta.stack
    }

    log = add_error_log(data)

    Logger.error("[Oban] [failure] {Logged as ##{log.id}}")
  end

  def handle_event([:oban, :job, event], measure, meta, _) do
    Logger.info("[Oban] #{event} #{meta.worker} ran in #{measure.duration}")
  end
end
