defmodule Teiserver.Account.TSAuthPlug do
  @moduledoc false
  import Plug.Conn
  alias Teiserver.CacheUser

  def init(_opts) do
    # Keyword.fetch!(opts, :repo)
  end

  def call(%{assigns: %{current_user: nil}} = conn, _opts), do: conn

  def call(%{assigns: %{current_user: current_user}} = conn, _opts) do
    cond do
      CacheUser.is_restricted?(current_user.id, ["Login"]) ->
        conn
        |> assign(:current_user, nil)
        |> Phoenix.Controller.redirect("/logout")

      current_user.smurf_of_id != nil ->
        conn
        |> assign(:current_user, nil)
        |> Phoenix.Controller.redirect("/logout")

      true ->
        conn
    end
  end

  def live_call(%{assigns: %{current_user: nil}} = socket, _session), do: socket

  def live_call(%{assigns: %{current_user: current_user}} = socket, _session) do
    cond do
      CacheUser.is_restricted?(current_user.id, ["Login"]) ->
        socket
        |> Phoenix.LiveView.Utils.assign(:current_user, nil)
        |> Phoenix.LiveView.redirect("/logout")

      current_user.smurf_of_id != nil ->
        socket
        |> Phoenix.LiveView.Utils.assign(:current_user, nil)
        |> Phoenix.LiveView.redirect("/logout")

      true ->
        socket
    end
  end
end
