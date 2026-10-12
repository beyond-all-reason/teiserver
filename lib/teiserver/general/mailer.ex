defmodule Teiserver.Mailer do
  @moduledoc false
  use Swoosh.Mailer, otp_app: :teiserver

  def noreply_address do
    Application.get_env(:teiserver, Teiserver.Mailer)[:noreply_address] || "noreply@example.com"
  end

  def contact_address do
    Application.get_env(:teiserver, Teiserver.Mailer)[:contact_address] || "contact@example.com"
  end
end
