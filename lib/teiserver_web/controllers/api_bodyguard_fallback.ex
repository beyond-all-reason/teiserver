defmodule TeiserverWeb.Controllers.ApiBodyguardFallback do
  @moduledoc """
  To handle thrown exceptions when an api caller hits an endpoint they don't
  have permission for.

  The browser equivalent, `TeiserverWeb.Controllers.BodyguardFallback`, sets a
  flash and redirects, neither of which works on a json pipeline with no session.
  """

  use TeiserverWeb, :controller

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "forbidden"})
    |> halt()
  end

  def call(conn, _stuff) do
    conn
  end
end
