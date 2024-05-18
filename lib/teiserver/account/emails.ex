defmodule Teiserver.Account.Emails do
  @moduledoc false
  require Logger
  alias Bamboo.Email
  alias Teiserver.Helper.TimexHelper

  def send_password_reset(user, code \\ nil) do
    {code, email} = password_reset(user, code)
    response = Teiserver.Mailer.deliver_now(email, response: true)

    case response do
      {:ok, _email, _response} ->
        :ok

      {:error, error} ->
        case Teiserver.Account.delete_code(code) do
          # the cursed path
          {:error, err} ->
            Logger.error(
              "Failed to delete code #{inspect(code)} for user at #{user.email}: #{inspect(err)}"
            )

          _ ->
            Logger.info(
              "Deleted password reset token for user at #{user.email} because email failed"
            )
        end

        {:error, error}
    end
  end

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
          Teiserver.Account.create_code(%{
            value: UUID.uuid1(),
            purpose: "reset_password",
            expires: Timex.now() |> Timex.shift(hours: 24),
            user_id: user.id
          })

        code
      end

    host = Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]
    url = "https://#{host}/password_reset/#{code.value}"

    html_body = """
    <p>A password reset has been requested for your account. To reset your password follow the link below. If you did not request this reset please ignore this email. The code will expire in 24 hours.</p>

    <p><a href="#{url}">#{url}</a></p>

    <p>If you did not request this password reset then please ignore it. The code will expire in 24 hours.</p>
    """

    text_body = """
    A password reset has been requested for your account. To reset your password follow the link below. If you did not request this reset please ignore this email. The code will expire in 24 hours.

    #{url}

    If you did not request this password reset then please ignore it. The code will expire in 24 hours.
    """

    date = TimexHelper.date_to_str(Timex.now(), format: :email_date)
    message_id = "<#{UUID.uuid1()}@#{Application.get_env(:teiserver, Teiserver)[:host]}>"
    subject = Application.get_env(:teiserver, Teiserver)[:game_name] <> " - Password reset"

    email =
      Email.new_email()
      |> Email.to({user.name, user.email})
      |> Email.from(
        {Application.get_env(:teiserver, Teiserver.Mailer)[:noreply_name],
         Teiserver.Mailer.noreply_address()}
      )
      |> Email.subject(subject)
      |> Email.put_header("Date", date)
      |> Email.put_header("Message-Id", message_id)
      |> Email.html_body(html_body)
      |> Email.text_body(text_body)

    {code, email}
  end
end
