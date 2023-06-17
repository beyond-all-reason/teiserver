defmodule Teiserver.Tachyon.Responses.Lobby.JoinResponse do
  @moduledoc """

  """

  alias Teiserver.Data.Types, as: T

  @spec generate({:error, String.t()} | T.lobby()) :: {T.tachyon_command, :success, T.tachyon_object} | {T.tachyon_command, T.error_pair}
  def generate({:error, reason}) do
    {"system/error/response", {:error, reason}}
  end

  def generate({:failure, reason}) do
    {"lobby/join/response", :success, %{"result" => "failure", "reason" => reason}}
  end

  def generate({:waiting_on_host, _script_password}) do
    {"lobby/join/response", :success, %{"result" => "waiting_on_host"}}
  end
end
