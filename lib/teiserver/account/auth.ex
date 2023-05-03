defmodule Teiserver.Account.Auth do
  @behaviour Bodyguard.Policy
  import Central.Account.AuthLib, only: [allow?: 2]

  def authorize(:index, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:search, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:show, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:new, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:perform_action, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:rename_form, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:rename_post, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:reset_password, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:respond_form, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:respond_post, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:smurf_search, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:smurf_merge_form, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:smurf_merge_post, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:delete_smurf_key, conn, _), do: allow?(conn, "admin.dev")
  def authorize(:automod_form, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:ratings, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:ratings_form, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:ratings_post, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:set_stat, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:edit, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:full_chat, conn, _), do: allow?(conn, "teiserver.staff.reviewer")
  def authorize(:update, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:applying, conn, _), do: allow?(conn, "teiserver.staff.moderator")
  def authorize(:data_search, conn, _), do: allow?(conn, "teiserver.staff.admin")
  def authorize(_, conn, _), do: allow?(conn, "admin.dev")
end

defmodule Teiserver.Staff.Admin do
  @behaviour Bodyguard.Policy
  import Central.Account.AuthLib, only: [allow?: 2]
  def authorize(_, conn, _), do: allow?(conn, "teiserver.staff.admin")
end

defmodule Teiserver.Staff.Moderator do
  @behaviour Bodyguard.Policy
  import Central.Account.AuthLib, only: [allow?: 2]
  def authorize(_, conn, _), do: allow?(conn, "teiserver.staff.moderator")
end

defmodule Teiserver.Staff.Reviewer do
  @behaviour Bodyguard.Policy
  import Central.Account.AuthLib, only: [allow?: 2]
  def authorize(_, conn, _), do: allow?(conn, "teiserver.staff.reviewer")
end

defmodule Teiserver.Staff.MatchAdmin do
  @behaviour Bodyguard.Policy
  import Central.Account.AuthLib, only: [allow?: 2]
  def authorize(:show, conn, _), do: allow?(conn, "teiserver.staff.overwatch")
  def authorize(_, conn, _), do: allow?(conn, "teiserver.staff.moderator")
end

defmodule Teiserver.Staff do
  @behaviour Bodyguard.Policy
  import Central.Account.AuthLib, only: [allow?: 2]
  def authorize(_, conn, _), do: allow?(conn, "teiserver.staff")
end

defmodule Teiserver.Auth do
  @behaviour Bodyguard.Policy
  import Central.Account.AuthLib, only: [allow?: 2]
  def authorize(_, conn, _), do: allow?(conn, "teiserver")
end
