defmodule Central.Account.Startup do
  @moduledoc false
  use CentralWeb, :startup

  def startup do
    add_audit_types([
      "Account:User password reset",
      "Account:Failed login",
      "Account:Created user",
      "Account:Updated user",
      "Account:Updated user permissions",
      "Account:User registration",
      "Account:Updated report",
      "Site config:Update value"
    ])
  end
end
