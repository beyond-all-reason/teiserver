defmodule PhoenixOauth2Provider.TokenController do
  @moduledoc false
  use PhoenixOauth2Provider.Controller, :api

  alias ExOauth2Provider.Token

  @spec create(Conn.t(), map(), keyword()) :: Conn.t()
  def create(conn, params, config) do
    params
    |> Token.grant(config)
    |> case do
      {:ok, access_token} ->
        json(conn, access_token)

      {:error, error, status} ->
        conn
        |> put_status(status)
        |> json(error)
    end
  end

  @spec revoke(Conn.t(), map(), keyword()) :: Conn.t()
  def revoke(conn, params, config) do
    params
    |> Token.revoke(config)
    |> case do
      {:ok, response} ->
        json(conn, response)

      {:error, error, status} ->
        conn
        |> put_status(status)
        |> json(error)
    end
  end
end
