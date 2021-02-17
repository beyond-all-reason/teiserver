defmodule CentralWeb.General.FallbackController do
  @moduledoc """
  """
  use Phoenix.Controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(CentralWeb.ErrorView)
    |> render(:"404")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(403)
    |> put_view(CentralWeb.ErrorView)
    |> render(:"403")
  end
end
