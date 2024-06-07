defmodule Teiserver.AccountFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Teiserver.Microblog` context.
  """
  alias Teiserver.Account
  alias Teiserver.Account.AuthLib

  @doc """
  Generate a tag.
  """
  def user_fixture(attrs \\ %{}) do
    permissions =
      attrs
      |> Map.get(:permissions, [])
      |> AuthLib.split_permissions()

    {:ok, tag} =
      attrs
      |> Enum.into(%{
        name: "Test",
        email: "email@email#{:rand.uniform(999_999_999_999)}",
        colour: "#00AA00",
        icon: "fa-solid fa-user",
        permissions: permissions,
        password: "password",
        password_confirmation: "password",
        data: %{}
      })
      |> Account.create_user()

    tag
  end
end
