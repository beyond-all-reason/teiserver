defmodule Teiserver.Auth.Server do
  @moduledoc false

  import Teiserver.Account.AuthLib, only: [allow?: 2]
  @behaviour Bodyguard.Policy
  def authorize(_action, conn, _data), do: allow?(conn, "Server")
end

defmodule Teiserver.Staff.Admin do
  @moduledoc false

  import Teiserver.Account.AuthLib, only: [allow?: 2]
  @behaviour Bodyguard.Policy
  def authorize(_action, conn, _data), do: allow?(conn, "Admin")
end

defmodule Teiserver.Staff.Moderator do
  @moduledoc false

  import Teiserver.Account.AuthLib, only: [allow?: 2]
  @behaviour Bodyguard.Policy
  def authorize(_action, conn, _data), do: allow?(conn, "Moderator")
end

defmodule Teiserver.Staff.Reviewer do
  @moduledoc false

  import Teiserver.Account.AuthLib, only: [allow?: 2]
  @behaviour Bodyguard.Policy
  def authorize(_action, conn, _data), do: allow?(conn, "Reviewer")
end

defmodule Teiserver.Staff.Overwatch do
  @moduledoc false

  import Teiserver.Account.AuthLib, only: [allow?: 2]
  @behaviour Bodyguard.Policy
  def authorize(_action, conn, _data), do: allow?(conn, "Overwatch")
end

defmodule Teiserver.Staff.MatchAdmin do
  @moduledoc false

  import Teiserver.Account.AuthLib, only: [allow?: 2]
  @behaviour Bodyguard.Policy
  def authorize(:show, conn, _data), do: allow?(conn, "Overwatch")
  def authorize(_action, conn, _data), do: allow?(conn, "Moderator")
end

defmodule Teiserver.Auth.Telemetry do
  @moduledoc false

  import Teiserver.Account.AuthLib, only: [allow_any?: 2]
  @behaviour Bodyguard.Policy
  def authorize(_action, conn, _data), do: allow_any?(conn, ~w(Server Engine))
end

defmodule Teiserver.Staff do
  @moduledoc false

  import Teiserver.Account.AuthLib, only: [allow?: 2]
  @behaviour Bodyguard.Policy
  def authorize(_action, conn, _data), do: allow?(conn, "Contributor")
end

defmodule Teiserver.Auth do
  @moduledoc false

  import Teiserver.Account.AuthLib, only: [allow?: 2]
  @behaviour Bodyguard.Policy
  def authorize(_action, conn, _data), do: allow?(conn, "account")
end
