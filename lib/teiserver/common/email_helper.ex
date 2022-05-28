defmodule Teiserver.EmailHelper do
  @moduledoc false
  alias Central.Account
  alias Central.Mailer
  alias Bamboo.Email
  alias Central.Helpers.TimexHelper
  require Logger

  def new_user(user) do
    host = Application.get_env(:central, CentralWeb.Endpoint)[:url][:host]
    website_url = "https://#{host}"
    verification_code = user.data["verification_code"]

    {:ok, _code} =
      Account.create_code(%{
        value: UUID.uuid4(),
        purpose: "reset_password",
        expires: Timex.now() |> Timex.shift(hours: 24),
        user_id: user.id
      })

    message_id = UUID.uuid4()

    game_name = Application.get_env(:central, Teiserver)[:game_name]
    discord = Application.get_env(:central, Teiserver)[:discord]

    html_body = """
    <p>Welcome to #{game_name}.</p>

    <p>To verify your account you will need this code:: <span style="font-family: monospace">#{
      verification_code
    }</span><p>

    <p>This game also has a <a href="#{website_url}">website</a> component.<p>

    <p>Please also take time to read our <a href="#{website_url}/privacy_policy">privacy policy</a>.</p>

    <p>If you have any questions please get in touch through the <a href="#{discord}">discord</a>.</p>
    """

    text_body = """
    Welcome to #{game_name}.

    You will be asked for a verification code, it is: #{verification_code}

    This client also has a website component at #{website_url}.<p>

    Please also take time to read our privacy policy at #{website_url}/privacy_policy.

    If you have any questions please get in touch through the discord at #{discord}.
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
    |> Central.Mailer.deliver_now()
  end
end
