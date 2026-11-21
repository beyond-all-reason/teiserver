defmodule TeiserverWeb.ModerationLive.User.Relationships do
  @moduledoc false
  alias Teiserver.Account
  alias Teiserver.Account.UserLib
  alias Teiserver.Account.UserQueries
  alias TeiserverWeb.ModerationLive.UserComponents

  use TeiserverWeb, :live_view

  import Teiserver.Logging.Helpers, only: [add_audit_log: 3]

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl LiveView
  def handle_params(%{"id" => id}, _url, socket) when is_connected?(socket) do
    %{scope: scope} = socket.assigns

    user =
      UserQueries.users()
      |> UserQueries.where_id(id)
      |> Repo.one()

    if UserLib.can_access_user?(user, scope) do
      relationships = %{
        friends: Account.list_friend_ids_of_user(user.id),
        friend_requests: Account.list_incoming_friend_requests_of_userid(user.id),
        followed: Account.list_userids_followed_by_userid(user.id),
        ignored: Account.list_userids_ignored_by_userid(user.id),
        avoided: Account.list_userids_avoided_by_userid(user.id),
        avoiding: Account.list_userids_avoiding_this_userid(user.id),
        blocked: Account.list_userids_blocked_by_userid(user.id),
        blocking: Account.list_userids_blocking_this_userid(user.id)
      }

      user_ids =
        relationships
        |> Map.values()
        |> List.flatten()
        |> Enum.uniq()

      lookup =
        UserQueries.users()
        |> UserQueries.where_id_in(user_ids)
        |> Repo.all()
        |> Map.new(fn u -> {u.id, u} end)

      socket
      |> assign(user: user, lookup: lookup, relationships: relationships)
      |> noreply()
    else
      if user do
        add_audit_log(scope, "User access attempt", %{
          user_id: user && user.id,
          page: "moderation/users/#{user.id}/relationships"
        })
      end

      socket
      |> put_flash(:error, "Unable to access this user")
      |> redirect(to: ~p"/moderation/users/#{user.id}/relationships")
      |> noreply()
    end
  end

  def handle_params(%{"id" => id}, _url, socket) do
    socket
    |> assign(
      user: nil,
      user_id: id
    )
    |> noreply()
  end
end
