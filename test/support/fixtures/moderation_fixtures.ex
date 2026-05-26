defmodule Teiserver.ModerationFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Teiserver.Moderation` context.
  """

  alias Teiserver.Moderation

  @doc """
  Generate a banned_domain.
  """
  def banned_domain_fixture(attrs \\ %{}) do
    {:ok, banned_domain} =
      attrs
      |> Enum.into(%{
        domain: "some domain"
      })
      |> Moderation.create_banned_domain()

    banned_domain
  end

  @doc """
  Generate a banned_ip.
  """
  def banned_ip_fixture(attrs \\ %{}) do
    {:ok, banned_ip} =
      attrs
      |> Enum.into(%{
        cidr: "192.168.0.1/32"
      })
      |> Moderation.create_banned_ip()

    banned_ip
  end

  @doc """
  Generate a banned_phrase.
  """
  def banned_phrase_fixture(attrs \\ %{}) do
    {:ok, banned_phrase} =
      attrs
      |> Enum.into(%{
        phrase: "some phrase",
        score_threshold: 42,
        severity: :low,
        type: :raw
      })
      |> Moderation.create_banned_phrase()

    banned_phrase
  end
end
