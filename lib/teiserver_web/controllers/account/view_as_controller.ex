defmodule TeiserverWeb.Account.ViewAsController do
  @moduledoc """
  Starts and stops "view as" sessions, see `Teiserver.Account.ViewAs`.
  """

  alias Teiserver.Account
  alias Teiserver.Account.ViewAs

  use TeiserverWeb, :controller

  def start(conn, %{"user_id" => user_id}) do
    # Authorise against the *real* user, never an already swapped one
    real_user = conn.assigns[:real_user] || conn.assigns[:current_user]

    target =
      case Integer.parse(user_id) do
        {id, ""} -> Account.get_user(id)
        _any -> nil
      end

    if ViewAs.can_view_as?(real_user, target) do
      conn
      |> put_session(ViewAs.session_key(), target.id)
      |> put_flash(:info, "Now viewing the site as #{target.name}")
      |> redirect(to: ~p"/")
    else
      conn
      |> put_flash(:error, "You cannot view the site as that user")
      |> redirect(to: ~p"/")
    end
  end

  def stop(conn, _params) do
    conn
    |> delete_session(ViewAs.session_key())
    |> put_flash(:info, "Stopped viewing as another user")
    |> redirect(to: ~p"/")
  end
end
