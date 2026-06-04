defmodule Teiserver.ChatFixtures do
  @moduledoc """
  Test helpers for creating chat message entities.
  """

  alias Teiserver.Chat

  def lobby_message_fixture(attrs \\ %{}) do
    {:ok, msg} =
      Map.merge(
        %{
          content: "some message",
          inserted_at: DateTime.utc_now()
        },
        attrs
      )
      |> Chat.create_lobby_message()

    msg
  end
end
