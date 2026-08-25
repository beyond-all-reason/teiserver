defmodule Teiserver.EmailHelper do
  @moduledoc false
  alias Swoosh.Email
  alias Teiserver.Account
  alias Teiserver.Account.User
  alias Teiserver.Config
  alias Teiserver.Helper.DateHelper
  alias Teiserver.Mailer
  alias Teiserver.Telemetry

  require Logger

  defp host, do: Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]

  defp privacy_email, do: Application.get_env(:teiserver, Teiserver)[:privacy_email]

  def new_user(user) do
    case Config.get_site_config_cache("teiserver.Require email verification") do
      true ->
        case do_new_user(user) do
          {:ok, _resp} ->
            Telemetry.log_complex_server_event(user.id, "email.verification", %{
              result: "success"
            })

            :ok

          {:error, error} ->
            Telemetry.log_complex_server_event(user.id, "email.verification", %{
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
    response = Mailer.deliver(email, response: true)

    case response do
      {:ok, _resp} ->
        Telemetry.log_complex_server_event(user.id, "email.password_reset", %{
          result: "success"
        })

        :ok

      {:error, error} ->
        Telemetry.log_complex_server_event(user.id, "email.password_reset", %{
          result: "failure",
          error: inspect(error)
        })

        case Account.delete_code(code) do
          # the cursed path
          {:error, err} ->
            Logger.error(
              "Failed to delete code #{inspect(code)} for user at #{user.email}: #{inspect(err)}"
            )

          _result ->
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
          Account.create_code(%{
            value: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false),
            purpose: "reset_password",
            expires: DateTime.shift(DateTime.utc_now(), hour: 24),
            user_id: user.id
          })

        code
      end

    url = "https://#{host()}/password_reset/#{code.value}"

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

    date = DateHelper.date_to_str(DateTime.utc_now(), format: :email_date)
    message_id = "<#{UUID.uuid1()}@#{Application.get_env(:teiserver, Teiserver)[:host]}>"
    subject = Application.get_env(:teiserver, Teiserver)[:game_name] <> " - Password reset"

    email =
      Email.new()
      |> Email.to({user.name, user.email})
      |> Email.from(
        {Application.get_env(:teiserver, Teiserver.Mailer)[:noreply_name],
         Mailer.noreply_address()}
      )
      |> Email.subject(subject)
      |> Email.header("Date", date)
      |> Email.header("Message-Id", message_id)
      |> Email.html_body(html_body)
      |> Email.text_body(text_body)

    {code, email}
  end

  defp do_new_user(user) do
    stats = Account.get_user_stat_data(user.id)
    website_url = Application.get_env(:teiserver, Teiserver)[:main_website]
    verification_code = stats["verification_code"]

    message_id = "<#{UUID.uuid4()}@#{host()}>"

    game_name = Application.get_env(:teiserver, Teiserver)[:game_name]
    discord = Application.get_env(:teiserver, Teiserver)[:discord]

    html_body = """
    <p>Welcome to #{game_name}.</p>

    <p>To verify your account you will need this code: <span style="font-family: monospace">#{verification_code}</span><p>

    <p>To find out more about #{game_name} visit our <a href="#{website_url}">website</a> .<p>

    <p>Please also take time to read our <a href="#{website_url}privacy">privacy policy</a>.</p>

    <p>If you experience any issues with registration or have other questions please get in touch through our <a href="#{discord}">discord</a>.</p>
    """

    text_body = """
    Welcome to #{game_name}.

    You will be asked for a verification code, it is: #{verification_code}

    To find out more about #{game_name} visit our website at #{website_url}.

    Please also take time to read our privacy policy at #{website_url}privacy.

    If you experience any issues with registration or have other questions please get in touch through our  discord at #{discord}.
    """

    date = DateHelper.date_to_str(DateTime.utc_now(), format: :email_date)

    Email.new()
    |> Email.to({user.name, user.email})
    |> Email.from({"BAR Teiserver", Mailer.noreply_address()})
    |> Email.subject("BAR - New account")
    |> Email.header("Date", date)
    |> Email.header("Message-Id", message_id)
    |> Email.html_body(html_body)
    |> Email.text_body(text_body)
    |> Mailer.deliver(response: true)
  end

  def email_changed(%User{} = user) do
    # We specifically send to the old address first to ensure if something goes wrong we
    # do not send anything to the new address
    {:ok, _success} = email_changed_old_address(user)
    {:ok, _success} = email_changed_new_address(user)
  end

  defp email_changed_old_address(%User{} = user) do
    now = Calendar.strftime(DateTime.utc_now(), "%a, %d %b %Y %H:%M:%S %z")

    # The email to privacy@beyondallreason.info used as a link is intended to be replaced by a
    # link to the support ticketing system we will later make use of
    html_body = """
    Hello,

    The email address on the Beyond All Reason account #{user.name} was changed on #{now}. This address will no longer receive messages about that account.

    If this was you, nothing further is needed.

    If this was not you, act now: someone may have access to your account. Open a ticket with us immediately at <a href="mailto:#{privacy_email()}">#{privacy_email()}</a>, replying from this address, and we will help you recover it. Do not reply with your password; we will never ask for it.

    For security, account deletion cannot be requested through our self-service page for 14 days after an email change.

    Beyond All Reason <a href="mailto:#{privacy_email()}">#{privacy_email()}</a>
    """

    text_body = """
    Hello,

    The email address on the Beyond All Reason account #{user.name} was changed on #{now}. This address will no longer receive messages about that account.

    If this was you, nothing further is needed.

    If this was not you, act now: someone may have access to your account. Open a ticket with us immediately at #{privacy_email()}, replying from this address, and we will help you recover it. Do not reply with your password; we will never ask for it.

    For security, account deletion cannot be requested through our self-service page for 14 days after an email change.

    Beyond All Reason: #{privacy_email()}
    """

    message_id = "<#{UUID.uuid4()}@#{host()}>"
    date = DateHelper.date_to_str(DateTime.utc_now(), format: :email_date)

    old_email = hd(user.previous_emails)

    Email.new()
    |> Email.to({user.name, old_email})
    |> Email.from({"BAR Teiserver", Mailer.noreply_address()})
    |> Email.subject("BAR - Your Beyond All Reason email address was changed")
    |> Email.header("Date", date)
    |> Email.header("Message-Id", message_id)
    |> Email.html_body(html_body)
    |> Email.text_body(text_body)
    |> Mailer.deliver(response: true)
  end

  defp email_changed_new_address(%User{} = user) do
    now = Calendar.strftime(DateTime.utc_now(), "%a, %d %b %Y %H:%M:%S %z")

    # The email to #{privacy_email()} used as a link is intended to be replaced by a
    # link to the support ticketing system we will later make use of
    html_body = """
    Hello,

    This address is now the email address for the Beyond All Reason account #{user.name} was changed on #{now}. The previous address has been notified as well.

    If you did not make this change, open a ticket with us at <a href="mailto:#{privacy_email()}">#{privacy_email()}</a> straight away. Do not reply with your password; we will never ask for it.

    For security, account deletion cannot be requested through our self-service page for 14 days after an email change.

    Beyond All Reason <a href="mailto:#{privacy_email()}">#{privacy_email()}</a>
    """

    text_body = """
    Hello,

    This address is now the email address for the Beyond All Reason account #{user.name} was changed on #{now}. The previous address has been notified as well.

    If you did not make this change, open a ticket with us at #{privacy_email()} straight away. Do not reply with your password; we will never ask for it.

    For security, account deletion cannot be requested through our self-service page for 14 days after an email change.

    Beyond All Reason #{privacy_email()}
    """

    message_id = "<#{UUID.uuid4()}@#{host()}>"
    date = DateHelper.date_to_str(DateTime.utc_now(), format: :email_date)

    Email.new()
    |> Email.to({user.name, user.email})
    |> Email.from({"BAR Teiserver", Mailer.noreply_address()})
    |> Email.subject("BAR - Your Beyond All Reason email address was changed")
    |> Email.header("Date", date)
    |> Email.header("Message-Id", message_id)
    |> Email.html_body(html_body)
    |> Email.text_body(text_body)
    |> Mailer.deliver(response: true)
  end
end
