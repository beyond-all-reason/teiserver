defmodule TeiserverWeb.Plugs.ValidatePaginationParams do
  @moduledoc """
  Plug to automatically validate pagination parameters (limit, page) before they reach controllers.
  This prevents abuse and ensures consistent pagination behavior across all controllers.
  """

  def init(opts), do: opts

  def call(conn, _opts) do
    # Use centralized validation logic
    validated = TeiserverWeb.Validators.PaginationParams.validate_params(conn.params)

    # Update the params with validated values
    updated_params =
      conn.params
      |> Map.put("limit", to_string(validated.limit))
      |> Map.put("page", to_string(validated.page))

    # Update the connection with validated params
    %{conn | params: updated_params}
  end
end
