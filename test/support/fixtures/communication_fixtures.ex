defmodule Teiserver.CommunicationFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Teiserver.Communication` context.
  """

  alias Teiserver.Communication

  @doc """
  Generate a text_callback.
  """
  def text_callback_fixture(attrs \\ %{}) do
    {:ok, text_callback} =
      Map.merge(
        %{
          name: "some name #{:rand.uniform(999_999)}",
          category: "some category",
          response: "some response",
          enabled: true
        },
        attrs
      )
      |> Communication.create_text_callback()

    text_callback
  end

  @doc """
  Generate a discord_channel.
  """
  def discord_channel_fixture(attrs \\ %{}) do
    {:ok, discord_channel} =
      Map.merge(
        %{
          name: "some name #{:rand.uniform(999_999)}",
          channel_id: :rand.uniform(999_999)
        },
        attrs
      )
      |> Communication.create_discord_channel()

    discord_channel
  end
end
