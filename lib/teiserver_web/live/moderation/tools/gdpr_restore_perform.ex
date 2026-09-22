defmodule TeiserverWeb.ModerationLive.Tools.GDPRRestorePerform do
  @moduledoc false
  alias Teiserver.Account
  alias Teiserver.Account.RestoreAnonymisedUserTask
  alias Teiserver.Helpers.EnumHelper
  alias Teiserver.Moderation.ActionQueries
  alias Teiserver.Repo
  alias TeiserverWeb.ModerationLive.ToolsComponents

  use TeiserverWeb, :live_view

  import Teiserver.Logging.Helpers, only: [add_audit_log: 3]

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl LiveView
  def handle_params(_params, _url, socket) when is_connected?(socket) do
    add_audit_log(socket.assigns.scope, "GDPR Restore validation view", %{})
    record = nil

    socket
    |> assign(
      page_title: "GDPR account restoration",
      record: record,
      form:
        to_form(%{
          "discord_id" => nil,
          "email" => nil,
          "steam_id" => nil
        })
    )
    |> noreply()
  end

  def handle_params(_params, _url, socket) do
    socket
    |> assign(record: nil, user: nil, page_title: "User details")
    |> noreply()
  end

  @impl LiveView
  def handle_event("validate-form", _params, %Socket{} = socket) do
    socket
    |> noreply()
  end

  def handle_event("submit-form", params, %Socket{} = socket) do
    {type, identifier} =
      cond do
        params["email"] != "" ->
          {:email, params["email"]}

        params["discord_id"] != "" ->
          {:discord_id, params["discord_id"]}

        params["steam_id"] != "" ->
          {:steam_id, params["steam_id"]}

        true ->
          {nil, nil}
      end

    if type do
      record = RestoreAnonymisedUserTask.find_record_from_identifier(type, identifier)

      if record do
        add_audit_log(socket.assigns.scope, "GDPR Restore retrieve record", %{
          record_id: record.id,
          user_id: record.user_id
        })

        socket
        |> assign(record: record, identifier_type: type, identifier: identifier)
        |> load_record_details()
        |> noreply()
      else
        add_audit_log(socket.assigns.scope, "GDPR Restore validation failure", %{})

        socket
        |> put_flash(:error, "Unable to find a corresponding record")
        |> noreply()
      end
    else
      socket
      |> noreply()
    end
  end

  def handle_event("perform-restore", _params, %Socket{assigns: assigns} = socket) do
    %{
      scope: scope,
      record: record,
      identifier_type: identifier_type,
      identifier: identifier
    } = assigns

    add_audit_log(socket.assigns.scope, "GDPR Restore perform restore", %{
      record_id: record.id,
      user_id: record.user_id
    })

    restore_result =
      RestoreAnonymisedUserTask.restore_from_record(
        record,
        scope,
        identifier_type,
        identifier,
        true
      )

    case restore_result do
      {:ok, :success} ->
        socket
        |> redirect(to: ~p"/moderation/tools/gdpr_restore/success/#{record.user_id}")
        |> noreply()

      error ->
        # We specifically want the page to completely bork at this
        # stage so the moderator tells us about it
        raise inspect(error)
    end
  end

  defp load_record_details(%Socket{assigns: %{record: record}} = socket) do
    user = Account.get_user_by_id(record.user_id)

    actions =
      ActionQueries.actions()
      |> ActionQueries.where_target_id(user.id)
      |> Repo.all()

    restrictions =
      actions
      |> Enum.map(& &1.restrictions)
      |> Enum.reject(&is_nil/1)
      |> List.flatten()
      |> Enum.uniq()

    banned? = EnumHelper.intersects?(restrictions, ["Login", "Permanently banned", "All lobbies"])

    socket
    |> assign(
      user: user,
      actions: actions,
      restrictions: restrictions,
      banned?: banned?
    )
  end
end
