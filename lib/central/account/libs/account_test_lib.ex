defmodule Central.Account.AccountTestLib do
  use CentralWeb, :library

  # alias Central.Account
  alias Central.Account.User
  alias Central.Account.Report

  def user_fixture(data \\ %{}) do
    r = :rand.uniform(999_999_999)

    User.changeset(%User{}, %{
      name: data["name"] || "name_#{r}",
      email: data["email"] || "email_#{r}",
      colour: data["colour"] || "colour",
      icon: data["icon"] || "icon",
    }, :script)
    |> Repo.insert!()
  end

  def report_fixture(data \\ %{}) do
    target_id = Map.get(data, "target_id", user_fixture().id)
    reporter_id = Map.get(data, "reporter_id", user_fixture().id)

    Report.create_changeset(%Report{}, %{
      name: data["name"] || "name",
      reason: data["reason"] || "reason",
      target_id: target_id,
      reporter_id: reporter_id,
    })
    |> Repo.insert!()
  end
end
