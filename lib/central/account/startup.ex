defmodule Central.Account.Startup do
  @moduledoc false
  use CentralWeb, :startup

  def startup do
    QuickAction.add_items([
      %{label: "Logout", icons: ["far fa-sign-out"], url: "/logout"},
      %{label: "Edit account", icons: ["far fa-lock", :edit], url: "/account/edit"}
    ])

    add_audit_types([
      "Account:User password reset",
      "Account:Failed login",
      "Account:Created user",
      "Account:Updated user",
      "Account:Updated user permissions",
      "Account:User registration",
      "Account:Updated report",
      "Site config:Update value",
    ])
  end
end
