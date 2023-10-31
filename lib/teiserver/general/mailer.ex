defmodule Teiserver.Mailer do
  @moduledoc false
  use Bamboo.Mailer, otp_app: :teiserver

  def noreply_address do
    Application.get_env(:teiserver, Teiserver.Mailer)[:noreply_address]
  end

  def contact_address do
    Application.get_env(:teiserver, Teiserver.Mailer)[:contact_address]
  end
end
