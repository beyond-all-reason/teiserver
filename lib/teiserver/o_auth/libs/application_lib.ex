defmodule Teiserver.OAuth.ApplicationLib do
  @moduledoc false

  alias Teiserver.OAuth.Application

  @spec icon :: String.t()
  def icon, do: "fa-solid fa-passport"

  @spec colours :: atom
  def colours, do: :success2

  @doc """
  An app is considered confidential when it can keep a secret. For example not
  a web client.
  """
  @spec confidential?(Application.t()) :: boolean()
  def confidential?(%Application{} = app), do: app.secret != nil

  @spec verify_secret(String.t(), Application.t()) :: boolean()
  def verify_secret(secret, %Application{} = app), do: Argon2.verify_pass(secret, app.secret)
end
