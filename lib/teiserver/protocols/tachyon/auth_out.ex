defmodule Teiserver.Protocols.Tachyon.AuthOut do
  alias Teiserver.Protocols.Tachyon

  @spec do_reply(atom(), any) :: Map.t()

  ###########
  # Tokens
  def do_reply(:user_token, {:success, token}) do
    %{
      "cmd" => "s.auth.get_token",
      "result" => "success",
      "token" => token
    }
  end

  def do_reply(:user_token, {:failure, reason}) do
    %{
      "cmd" => "s.auth.get_token",
      "result" => "failure",
      "reason" => reason
    }
  end

  ###########
  # Agreement
  def do_reply(:user_agreement, nil) do
    %{
      "cmd" => "s.auth.login",
      "result" => "unverified",
      "agreement" => Application.get_env(:central, Teiserver)[:user_agreement]
    }
  end

  ###########
  # Verify
  def do_reply(:verify, {:failure, reason}) do
    %{
      "cmd" => "s.auth.verify",
      "result" => "failure",
      "reason" => reason
    }
  end

  def do_reply(:verify, {:success, user}) do
    %{
      "cmd" => "s.auth.verify",
      "result" => "success",
      "user" => Tachyon.convert_object(:user_extended, user)
    }
  end

  ###########
  # Login
  def do_reply(:login, {:failure, reason}) do
    %{
      "cmd" => "s.auth.login",
      "result" => "failure",
      "reason" => reason
    }
  end

  def do_reply(:login, {:success, user}) do
    %{
      "cmd" => "s.auth.login",
      "result" => "success",
      "user" => Tachyon.convert_object(:user_extended, user)
    }
  end
end
