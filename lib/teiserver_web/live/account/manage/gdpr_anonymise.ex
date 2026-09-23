defmodule TeiserverWeb.AccountLive.Manage.GDPRAnonymise do
  @moduledoc false
  alias Teiserver.Account.UserLib

  use TeiserverWeb, :live_view

  require Logger

  @impl Phoenix.LiveView
  def mount(_params, _session, %Socket{assigns: assigns} = socket) when is_connected?(socket) do
    days_since_change = UserLib.days_since_last_email_change(assigns.current_user)

    if is_nil(days_since_change) or days_since_change > 14 do
      socket
      |> assign(stage: :warning)
      |> load_stage()
      |> ok()
    else
      socket
      |> assign(stage: :error)
      |> assign(
        error: [
          "The email address on this account was changed within the last 14 days, so account deletion cannot be requested here. This protects accounts that have been taken over.",
          "Please open a discord ticket and our moderation team will handle your request. You can also request deletion at any time by writing to delete@beyondallreason.info from your registered email address."
        ]
      )
      |> load_stage()
      |> ok()
    end
  end

  def mount(_params, _session, socket) do
    socket
    |> assign(stage: :loading)
    |> load_stage()
    |> ok()
  end

  @impl Phoenix.LiveView
  def handle_event("continue", _event_data, %Socket{assigns: %{stage: :warning}} = socket) do
    socket
    |> assign(stage: :confirmation)
    |> load_stage()
    |> noreply()
  end

  def handle_event(
        "confirm-deletion",
        data,
        %Socket{assigns: %{stage: :confirmation, current_user: user}} = socket
      ) do
    if data["name"] == user.name do
      socket
      |> assign(stage: :perform)
      |> load_stage()
      |> noreply()
    else
      socket
      |> put_flash(:error, "That is not your username")
      |> noreply()
    end
  end

  defp load_stage(%Socket{assigns: %{stage: :confirmation}} = socket) do
    form = to_form(%{"name" => ""})

    socket
    |> assign(form: form)
  end

  defp load_stage(%Socket{assigns: %{stage: :perform, current_user: user, scope: scope}} = socket) do
    case UserLib.set_gdpr_forget(user, scope) do
      {:ok, updated_user} ->
        socket
        |> assign(current_user: nil, scope: nil, updated_user: updated_user)

      error ->
        Logger.error("Error performing set self-service GDPR anonymisation: #{inspect(error)}")

        socket
        |> assign(
          error: [
            "There was an error marking your account to be forgotten. We have logged the error but please also open a support ticket."
          ]
        )
    end
  end

  defp load_stage(%Socket{assigns: %{stage: _any}} = socket) do
    socket
  end
end
