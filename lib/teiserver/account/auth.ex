defmodule Teiserver.Account.Auth do
  @behaviour Bodyguard.Policy
  import Central.Account.AuthLib, only: [allow?: 2]

  def authorize(:index, conn, _), do: allow?(conn, "teiserver.moderator.account")
  def authorize(:search, conn, _), do: allow?(conn, "teiserver.moderator.account")
  def authorize(:show, conn, _), do: allow?(conn, "teiserver.moderator.account")
  def authorize(:perform_action, conn, _), do: allow?(conn, "teiserver.moderator.account")
  def authorize(:reset_password, conn, _), do: allow?(conn, "teiserver.moderator.account")
  def authorize(:respond_form, conn, _), do: allow?(conn, "teiserver.moderator.account")
  def authorize(:respond_post, conn, _), do: allow?(conn, "teiserver.moderator.account")
  def authorize(:smurf_search, conn, _), do: allow?(conn, "teiserver.moderator.account")
  def authorize(:automod_form, conn, _), do: allow?(conn, "teiserver.moderator.account")
  def authorize(:set_stat, conn, _), do: allow?(conn, "teiserver.moderator.account")
  def authorize(:edit, conn, _), do: allow?(conn, "teiserver.moderator.account")
  def authorize(:full_chat, conn, _), do: allow?(conn, "teiserver.moderator")
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
