defmodule TeiserverWeb.API.SessionView do
  use TeiserverWeb, :view

  def render("login.json", %{user: _user, token: token}) do
    %{result: :success, token: token}
  end

  def render("login.json", %{result: :failure, reason: reason}) do
    %{result: :failure, reason: reason}
  end
end
