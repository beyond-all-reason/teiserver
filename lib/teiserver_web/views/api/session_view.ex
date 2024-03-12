defmodule BarserverWeb.API.SessionView do
  use BarserverWeb, :view

  def render("login.json", %{user: _user, token: token}) do
    %{result: :success, token: token}
  end

  def render("login.json", %{result: :failure, reason: reason}) do
    %{result: :failure, reason: reason}
  end

  def render("register.json", %{user: user}) do
    %{result: :success, userid: user.id}
  end

  def render("register.json", %{result: :failure, reason: reason}) do
    %{result: :failure, reason: reason}
  end

  def render("token.json", %{token_value: token_value}) do
    %{result: :success, token_value: token_value}
  end

  def render("token.json", %{result: :failure, reason: reason}) do
    %{result: :failure, reason: reason}
  end
end
