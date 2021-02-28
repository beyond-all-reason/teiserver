defmodule Central.General.AssignPlug do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    opts
    |> Enum.reduce(conn, fn {k, v}, c ->
      assign(c, k, v)
    end)
  end
end
