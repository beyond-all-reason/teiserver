defmodule Teiserver.Account.AccountTestLib do
  @moduledoc false
  use TeiserverWeb, :library

  # alias Teiserver.Account
  alias Teiserver.Account.User

  def user_fixture(data \\ %{}) do
    r = :rand.uniform(999_999_999)

    User.changeset(
      %User{},
      %{
        name: data["name"] || "name_#{r}",
        email: data["email"] || "email_#{r}@test.local",
        colour: data["colour"] || "colour",
        icon: data["icon"] || "icon",
        password: data["password"] || Teiserver.Account.spring_md5_password("password"),
        last_login_timex: data["last_login_timex"] || Timex.now()
      },
      :script
    )
    |> Repo.insert!()
  end
end
