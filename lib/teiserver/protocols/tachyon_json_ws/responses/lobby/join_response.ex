defmodule Teiserver.Tachyon.Responses.Lobby.JoinResponse do
  @moduledoc """

  """

  alias Teiserver.Data.Types, as: T

  @spec execute({:error, String.t()} | T.lobby()) :: {T.tachyon_command(), T.tachyon_object()}
  def execute({:error, reason}) do
    {"system/error/response", :error, reason}
  end

  def execute({:failure, reason}) do
    {"lobby/join/response", :success, %{"result" => "failure", "reason" => reason}}
  end

  def execute({:waiting_on_host, _script_password}) do
    {"lobby/join/response", :success, %{"result" => "waiting_on_host"}}
  end
end
