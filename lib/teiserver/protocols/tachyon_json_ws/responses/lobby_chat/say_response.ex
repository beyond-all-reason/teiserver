defmodule Barserver.Tachyon.Responses.LobbyChat.SayResponse do
  @moduledoc """

  """

  alias Barserver.Data.Types, as: T

  @spec generate(true | false | :no_lobby) ::
          {T.tachyon_command(), :success, T.tachyon_object()}
          | {T.tachyon_command(), T.error_pair()}
  def generate(:no_lobby) do
    {"system/error/response", {:error, "Not a member of a lobby"}}
  end

  def generate(false) do
    {"system/error/response", {:error, "Not allowed to chat in this lobby"}}
  end

  def generate(true) do
    {"lobbyChat/say/response", :success, %{}}
  end
end
