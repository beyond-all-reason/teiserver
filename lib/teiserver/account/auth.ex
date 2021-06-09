defmodule Teiserver.Account.Auth do
  @behaviour Bodyguard.Policy
  import Central.Account.AuthLib, only: [allow?: 2]

  def authorize(:index, conn, _), do: allow?(conn, "teiserver.moderator.account")
  def authorize(:search, conn, _), do: allow?(conn, "teiserver.moderator.account")
  def authorize(:show, conn, _), do: allow?(conn, "teiserver.moderator.account")
  def authorize(:perform_action, conn, _), do: allow?(conn, "teiserver.moderator.account")
  def authorize(:edit, conn, _), do: allow?(conn, "teiserver.moderator.account")
  def authorize(:update, conn, _), do: allow?(conn, "teiserver.moderator.account")
  def authorize(_, conn, _), do: allow?(conn, "teiserver.admin.account")
end

defmodule Teiserver.Admin do
  @behaviour Bodyguard.Policy
  import Central.Account.AuthLib, only: [allow?: 2]
  def authorize(_, conn, _), do: allow?(conn, "teiserver.admin")
end

defmodule Teiserver.Moderator do
  @behaviour Bodyguard.Policy
  import Central.Account.AuthLib, only: [allow?: 2]
  def authorize(_, conn, _), do: allow?(conn, "teiserver.moderator")
end

defmodule Teiserver.Auth do
  @behaviour Bodyguard.Policy
  import Central.Account.AuthLib, only: [allow?: 2]
  def authorize(_, conn, _), do: allow?(conn, "teiserver")
end
