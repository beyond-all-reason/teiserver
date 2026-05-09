defmodule TeiserverWeb.Controllers.BodyguardFallback do
  @moduledoc """
  To handle thrown exceptions when someone gets to a page they shouldn't have
  access
  """

  use TeiserverWeb, :controller

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_flash(:error, "Unauthorized")
    |> redirect(to: ~p"/")
  end

  def call(conn, _stuff) do
    conn
  end
end
