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
          enabled: true,
          icon: "some icon",
          colour: "some colour"
        },
        attrs
      )
      |> Communication.create_text_callback()

    text_callback
  end
end
