defmodule Teiserver.EmailHelper do
  @moduledoc false
  defp send_email(_to, _subject, _body) do
    # Stub function to allow us to add intent to other code
  end

  def send_verification(user) do
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
