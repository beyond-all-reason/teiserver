defmodule Teiserver.EmailHelper do
  @moduledoc false
  alias Central.Mailer
  alias Bamboo.Email
  require Logger

  def new_user(user) do
    website_url = Application.get_env(:central, Teiserver)[:website][:url]
    verification_code = user.data["verification_code"]

    html_body = """
    <p>Welcome to Beyond All Reason.</p>

    <p>To verify your account you will need this code:: <span style="font-family: monospace">#{
      verification_code
    }</span>.<p>

    <p>You also have an account on <a href="#{website_url}">the website</a>. Due to the way passwords are stored differently between the lobby and the website your website password has had to be generated randomly. It is '#{
      user.web_password
    }', you are advised to change it at the first opportunity.<p>

    <p>If you have any questions please get in touch through the <a href="https://discord.gg/N968ddE">discord</a>.</p>
    """

    text_body = """
    Welcome to Beyond All Reason.

    You will be asked for a verification code, it is: #{verification_code}.

    You also have an account on the website (#{website_url}). Due to the way passwords are stored differently between the lobby and the website your website password has had to be generated randomly. It is '#{
      user.web_password
    }', you are advised to change it at the first opportunity.

    If you have any questions please get in touch through the discord (https://discord.gg/N968ddE).
    """

    Email.new_email()
    |> Email.to({user.name, user.email})
    |> Email.from({"BAR Teiserver", Mailer.noreply_address()})
    |> Email.subject("BAR - New account")
    |> Email.html_body(html_body)
    |> Email.text_body(text_body)
    |> Mailer.deliver_now()
  end

  def password_reset(_user, _plain_password) do
    Logger.error("password_reset not implemented at this time")
    # to = user.email
    # subject = "Password reset - Teiserver"

    # body = """
    #   Your code is XXX
    # """
  end
end
