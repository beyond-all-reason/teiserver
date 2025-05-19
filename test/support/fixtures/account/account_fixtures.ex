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
        password: Account.spring_md5_password("password"),
        data: %{}
      })
      |> Account.create_user()

    tag
  end

  @doc """
  Make the two given users friends
  """
  def create_friend(%{id: id1}, user2), do: create_friend(id1, user2)
  def create_friend(user1, %{id: id}), do: create_friend(user1, id)

  def create_friend(user_id1, user_id2) do
    {:ok, friend} = Account.create_friend(user_id1, user_id2)
    friend
  end
end
