defmodule Central.Account.AccountTestLib do
  @moduledoc false
  use CentralWeb, :library

  # alias Central.Account
  alias Central.Account.User

  def user_fixture(data \\ %{}) do
    r = :rand.uniform(999_999_999)

    User.changeset(
      %User{},
      %{
        name: data["name"] || "name_#{r}",
        email: data["email"] || "email_#{r}",
        colour: data["colour"] || "colour",
        icon: data["icon"] || "icon"
      },
      :script
    )
    |> Repo.insert!()
  end
end
