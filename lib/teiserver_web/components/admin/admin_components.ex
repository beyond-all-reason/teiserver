defmodule TeiserverWeb.Admin.AdminComponents do
  @moduledoc false
  alias Teiserver.Account.Scope

  use TeiserverWeb, :component

  @doc """
  Places a very visible banner at the top of the page, the banner stickies to the top of
  the window and will remain visible even when scrolling. It displays the warning message,
  username, user_id and IP of connection.

  <TeiserverWeb.Admin.AdminComponents.sensitive_warning scope={@scope} />
  """
  attr :scope, Scope, required: true

  def sensitive_warning(assigns) do
    ip =
      assigns.scope.ip
      |> Tuple.to_list()
      |> Enum.join(".")

    assigns =
      assigns
      |> assign(ip: ip)

    ~H"""
    <div class="admin-sensitive-topbar">
      This is especially sensitive information, do not stream it ({@scope.user.name}/{@scope.user.id} - {@ip})
    </div>
    """
  end
end
