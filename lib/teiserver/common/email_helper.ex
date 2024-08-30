defmodule Teiserver.EmailHelper do
  @moduledoc false
  alias Teiserver.Mailer
  alias Teiserver.Config
  alias Bamboo.Email
  alias Teiserver.Helper.TimexHelper
  require Logger

  def new_user(user) do
    case Config.get_site_config_cache("teiserver.Require email verification") do
      true ->
        case do_new_user(user) do
          {:ok, _email, _response} ->
            Teiserver.Telemetry.log_complex_server_event(user.id, "email.verification", %{
              result: "success"
            })

            :ok

          {:error, error} ->
            Teiserver.Telemetry.log_complex_server_event(user.id, "email.verification", %{
              result: "failure",
              error: error
            })

            {:error, error}
        end

      false ->
        :no_verify
    end
  end

  def send_password_reset(user, code \\ nil) do
    {code, email} = password_reset(user, code)
    response = Teiserver.Mailer.deliver_now(email, response: true)

    case response do
      {:ok, _email, _response} ->
        Teiserver.Telemetry.log_complex_server_event(user.id, "email.password_reset", %{
          result: "success"
        })

        :ok

      {:error, error} ->
        Teiserver.Telemetry.log_complex_server_event(user.id, "email.password_reset", %{
          result: "failure",
          error: error
        })

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

  defp password_reset(user, code) do
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

  defp do_new_user(user) do
    stats = Teiserver.Account.get_user_stat_data(user.id)
    host = Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]
    website_url = "https://#{host}"
    verification_code = stats["verification_code"]

    message_id = "<#{UUID.uuid4()}@#{host}>"

    game_name = Application.get_env(:teiserver, Teiserver)[:game_name]
    discord = Application.get_env(:teiserver, Teiserver)[:discord]

    html_body = """
    <p>Welcome to #{game_name}.</p>

    <p>To verify your account you will need this code: <span style="font-family: monospace">#{verification_code}</span><p>

    <p>To find out more about #{game_name} visit our <a href="#{website_url}">website</a> .<p>

    <p>Please also take time to read our <a href="#{website_url}/privacy_policy">privacy policy</a>.</p>

    <p>If you experience any issues with registration or have other questions please get in touch through our <a href="#{discord}">discord</a>.</p>
    """

    text_body = """
    Welcome to #{game_name}.

    You will be asked for a verification code, it is: #{verification_code}

    To find out more about #{game_name} visit our website at #{website_url}.

    Please also take time to read our privacy policy at #{website_url}/privacy_policy.

    If you experience any issues with registration or have other questions please get in touch through our  discord at #{discord}.
    """

    date = TimexHelper.date_to_str(Timex.now(), format: :email_date)

    Email.new_email()
    |> Email.to({user.name, user.email})
    |> Email.from({"BAR Teiserver", Mailer.noreply_address()})
    |> Email.subject("BAR - New account")
    |> Email.put_header("Date", date)
    |> Email.put_header("Message-Id", message_id)
    |> Email.html_body(html_body)
    |> Email.text_body(text_body)
    |> Teiserver.Mailer.deliver_now(response: true)
  end
end
