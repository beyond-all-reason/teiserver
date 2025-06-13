defmodule Teiserver.Account.Auth do
  @moduledoc false
  @behaviour Bodyguard.Policy
  import Teiserver.Account.AuthLib, only: [allow?: 2]

  def authorize(:index, conn, _), do: allow?(conn, "Moderator")
  def authorize(:search, conn, _), do: allow?(conn, "Moderator")
  def authorize(:show, conn, _), do: allow?(conn, "Moderator")
  def authorize(:new, conn, _), do: allow?(conn, "Moderator")
  def authorize(:perform_action, conn, _), do: allow?(conn, "Moderator")
  def authorize(:rename_form, conn, _), do: allow?(conn, "Moderator")
  def authorize(:rename_post, conn, _), do: allow?(conn, "Moderator")
  def authorize(:reset_password, conn, _), do: allow?(conn, "Moderator")
  def authorize(:respond_form, conn, _), do: allow?(conn, "Moderator")
  def authorize(:respond_post, conn, _), do: allow?(conn, "Moderator")
  def authorize(:smurf_search, conn, _), do: allow?(conn, "Moderator")
  def authorize(:smurf_merge_form, conn, _), do: allow?(conn, "Moderator")
  def authorize(:smurf_merge_post, conn, _), do: allow?(conn, "Moderator")
  def authorize(:cancel_smurf_mark, conn, _), do: allow?(conn, "Moderator")
  def authorize(:mark_as_smurf_of, conn, _), do: allow?(conn, "Moderator")
  def authorize(:delete_smurf_key, conn, _), do: allow?(conn, "admin.dev")
  def authorize(:automod_form, conn, _), do: allow?(conn, "Moderator")
  def authorize(:ratings, conn, _), do: allow?(conn, "Moderator")
  def authorize(:ratings_form, conn, _), do: allow?(conn, "Moderator")
  def authorize(:ratings_post, conn, _), do: allow?(conn, "Moderator")
  def authorize(:set_stat, conn, _), do: allow?(conn, "Moderator")
  def authorize(:edit, conn, _), do: allow?(conn, "Moderator")
  def authorize(:full_chat, conn, _), do: allow?(conn, "Reviewer")
  def authorize(:update, conn, _), do: allow?(conn, "Moderator")
  def authorize(:applying, conn, _), do: allow?(conn, "Moderator")
  def authorize(:data_search, conn, _), do: allow?(conn, "Server")
  def authorize(:relationships, conn, _), do: allow?(conn, "Moderator")
  def authorize(:gdpr_clean, conn, _), do: allow?(conn, "Moderator")
  def authorize(_, conn, _), do: allow?(conn, "admin.dev")
end

defmodule Teiserver.Auth.Server do
  @moduledoc false
  @behaviour Bodyguard.Policy
  import Teiserver.Account.AuthLib, only: [allow?: 2]
  def authorize(_, conn, _), do: allow?(conn, "Server")
end

defmodule Teiserver.Staff.Admin do
  @moduledoc false
  @behaviour Bodyguard.Policy
  import Teiserver.Account.AuthLib, only: [allow?: 2]
  def authorize(_, conn, _), do: allow?(conn, "Admin")
end

defmodule Teiserver.Staff.Moderator do
  @moduledoc false
  @behaviour Bodyguard.Policy
  import Teiserver.Account.AuthLib, only: [allow?: 2]
  def authorize(_, conn, _), do: allow?(conn, "Moderator")
end

defmodule Teiserver.Staff.Reviewer do
  @moduledoc false
  @behaviour Bodyguard.Policy
  import Teiserver.Account.AuthLib, only: [allow?: 2]
  def authorize(_, conn, _), do: allow?(conn, "Reviewer")
end

defmodule Teiserver.Staff.Overwatch do
  @moduledoc false
  @behaviour Bodyguard.Policy
  import Teiserver.Account.AuthLib, only: [allow?: 2]
  def authorize(_, conn, _), do: allow?(conn, "Overwatch")
end

defmodule Teiserver.Staff.MatchAdmin do
  @moduledoc false
  @behaviour Bodyguard.Policy
  import Teiserver.Account.AuthLib, only: [allow?: 2]
  def authorize(:show, conn, _), do: allow?(conn, "Overwatch")
  def authorize(_, conn, _), do: allow?(conn, "Moderator")
end

defmodule Teiserver.Auth.Telemetry do
  @moduledoc false
  @behaviour Bodyguard.Policy
  import Teiserver.Account.AuthLib, only: [allow_any?: 2]
  def authorize(_, conn, _), do: allow_any?(conn, ~w(Server Engine))
end

defmodule Teiserver.Staff do
  @moduledoc false
  @behaviour Bodyguard.Policy
  import Teiserver.Account.AuthLib, only: [allow?: 2]
  def authorize(_, conn, _), do: allow?(conn, "Contributor")
end

defmodule Teiserver.Auth do
  @moduledoc false
  @behaviour Bodyguard.Policy
  import Teiserver.Account.AuthLib, only: [allow?: 2]
  def authorize(_, conn, _), do: allow?(conn, "account")
end
