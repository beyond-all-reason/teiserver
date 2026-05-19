defmodule TeiserverWeb.OAuth.UserinfoView do
  use TeiserverWeb, :view

  def render("userinfo.json", data) do
    data[:claims]
  end
end
