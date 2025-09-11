defmodule TeiserverWeb.Plugs.PaginationParams do
  @moduledoc """
  Plug to automatically parse pagination parameters (limit, page) before they reach controllers.
  This prevents abuse and ensures consistent pagination behavior across all controllers.
  """

  def init(opts), do: opts

  def call(conn, _opts) do
    # Use centralized parsing logic
    parsed_params = TeiserverWeb.Parsers.PaginationParams.parse_params(conn.params)

    # Update the params with parsed values
    updated_params =
      conn.params
      |> Map.put("limit", parsed_params.limit)
      |> Map.put("page", parsed_params.page)

    # Update the connection with parsed params
    %{conn | params: updated_params}
  end
end
