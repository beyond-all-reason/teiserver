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
      |> put_if_present("limit", to_string(validated.limit))
      |> put_if_present("page", to_string(validated.page))

    # Update the connection with validated params
    %{conn | params: updated_params}
  end

  defp put_if_present(params, key, value) do
    if Map.has_key?(params, key) do
      Map.put(params, key, to_string(value))
    else
      params
    end
  end
end
