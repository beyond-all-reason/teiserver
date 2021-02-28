defmodule Central.Logging.LoggingLib do
  import Plug.Conn, only: [assign: 3]

  def colours(), do: {"#666", "#EEE", "default"}
  def icon(), do: "far fa-bars"

  def do_not_log(conn) do
    assign(conn, :do_not_log, true)
  end
end
