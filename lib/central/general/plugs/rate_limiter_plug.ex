# # Adapted from
# # http://blog.danielberkompas.com/elixir/2015/06/16/rate-limiting-a-phoenix-api.html
# defmodule Central.General.RateLimitPlug do
#   import Phoenix.Controller, only: [text: 2]
#   import Plug.Conn, only: [put_status: 2, halt: 1]

#   def init(_opts) do
#     # Keyword.fetch!(opts, :repo)
#   end

#   def call(conn, _) do
#     case check_rate(conn) do
#       {:ok, _count}   -> conn # Do nothing, pass on to the next plug
#       {:error, _count} -> render_error(conn)
#     end
#   end

#   defp check_rate(conn) do
#     max_requests = conn.assigns[:current_user].configs["general.Rate limit"]

#     case max_requests do
#       nil -> {:ok, nil}
#       _ ->
#         interval_milliseconds = 60_000
#         bucket_name = conn.assigns[:current_user].id

#         ExRated.check_rate(bucket_name, interval_milliseconds, max_requests |> String.to_integer)
#     end
#   end

#   defp render_error(conn) do
#     conn
#     |> put_status(:forbidden)
#     |> text("Rate limit exceeded.")
#     |> halt # Stop execution of further plugs, return response now
#   end
# end
