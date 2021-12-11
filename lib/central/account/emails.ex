defmodule Central.Account.Emails do
  @moduledoc false
  alias Bamboo.Email
  alias Central.Account
  alias Central.Helpers.TimexHelper

  def password_reset(user, code \\ nil) do
    # We need this to enable recreating the email if we know it
    # should exist but at the same time we don't want
    # callers of this function to have to create the code
    # themselves
    code =
      if code do
        code
      else
        {:ok, code} =
          Account.create_code(%{
            value: UUID.uuid1(),
            purpose: "reset_password",
            expires: Timex.now() |> Timex.shift(hours: 24),
            user_id: user.id
          })

        code
      end

    host = Application.get_env(:central, CentralWeb.Endpoint)[:url][:host]
    url = "https://#{host}/password_reset/#{code.value}"

    html_body = """
    <p>A request for a password reset has been requested for you. To reset your password follow the link below. If you did not request this reset please ignore the email.</p>

    <p><a href="#{url}">#{url}</a></p>

    <p>If you did not request this password reset then please ignore it. The code will expire in 24 hours.</p>
    """

    text_body =
"""
A request for a password reset has been requested for you. To reset your password follow the link below. If you did not request this reset please ignore the email.

#{url}

If you did not request this password reset then please ignore it. The code will expire in 24 hours.
"""

    date = TimexHelper.date_to_str(Timex.now(), format: :email_date)
    message_id = UUID.uuid1()
    subject = Application.get_env(:central, Central)[:site_title] <> " - Password reset"

    Email.new_email()
    |> Email.to({user.name, user.email})
    |> Email.from({Application.get_env(:central, Central.Mailer)[:noreply_name], Central.Mailer.noreply_address()})
    |> Email.subject(subject)
    |> Email.put_header("Date", date)
    |> Email.put_header("Message-Id", message_id)
    |> Email.html_body(html_body)
    |> Email.text_body(text_body)
  end
end
