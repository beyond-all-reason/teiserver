defmodule Teiserver.EmailHelper do
  alias Central.Mailer
  alias Bamboo.Email

  @moduledoc false
  def send_verification(user) do
    html_body = """
<p>Welcome to Beyond All Reason.</p>

<p>To activate your account you will need to enter the following verification code: <span style="font-family: monospace">123-456-789</span><p>
"""
  text_body = """
Welcome to Beyond All Reason.

To activate your account you will need to enter the following verification code: 123-456-789
"""

    Email.new_email
    |> Email.to({user.name, user.email})
    |> Email.from({"BAR Teiserver", Mailer.noreply_address()})
    |> Email.subject("BAR - New account verification code")
    |> Email.html_body(html_body)
    |> Email.text_body(text_body)
    |> Mailer.deliver_now
  end

  def send_password_reset(user) do
    to = user.email
    subject = "Password reset - Teiserver"

    body = """
      Your code is XXX
    """
  end

  def send_new_password(user, new_password) do
    to = user.email
    subject = "Password reset - Teiserver"

    body = """
      Your new password is #{new_password}, please login and change it at the earliest opportunity.
    """
  end
end
