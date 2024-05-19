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
        do_new_user(user)

      false ->
        :no_verify
    end
  end

  def do_new_user(user) do
    stats = Teiserver.Account.get_user_stat_data(user.id)
    host = Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]
    website_url = "https://#{host}"
    verification_code = stats["verification_code"]

    {:ok, _code} =
      Teiserver.Account.create_code(%{
        value: UUID.uuid4(),
        purpose: "reset_password",
        expires: Timex.now() |> Timex.shift(hours: 24),
        user_id: user.id
      })

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
