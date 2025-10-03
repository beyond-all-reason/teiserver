defmodule TeiserverWeb.Moderation.ReportUserLive.Index do
  use TeiserverWeb, :live_view
  alias Teiserver.{Account, Battle, Moderation}
  alias Teiserver.Moderation.ReportLib
  alias Teiserver.Helper.TimexHelper

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:site_menu_active, "teiserver_account")
      |> assign(:view_colour, Moderation.colour())
      |> assign(:report, %{})
      |> assign(:user, nil)
      |> assign(:stage, :loading)
      |> assign(:extra_text, "")
      |> add_breadcrumb(name: "Report user", url: ~p"/moderation/report_user")
      |> apply_structure

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    user = Account.get_user_by_id(id)

    socket =
      socket
      |> assign(:id_str, id)
      |> assign(:user, user)
      |> assign(:report, %{
        user_id: user.id
      })
      |> assign(:stage, :type)
      |> allowed_to_use_form
      |> get_user_matches
      |> get_relationship

    {:noreply, socket}
  end

  def handle_params(_params, _url, socket) do
    socket =
      socket
      |> assign(:stage, :user)

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "submit-extra-text",
        _event,
        %{assigns: %{stage: :extra_text} = assigns} = socket
      ) do
    report_params = %{
      reporter_id: assigns.current_user.id,
      target_id: assigns.user.id,
      type: assigns.type,
      sub_type: assigns.sub_type,
      extra_text: assigns.extra_text,
      match_id: assigns.match_id
    }

    case Moderation.create_report_group_and_report(report_params) do
      {:ok, _report_group, _report} ->
        {:noreply,
         socket
         |> assign(:result, :success)
         |> assign(:stage, :completed)}

      v ->
        raise v
        {:noreply, socket}
    end
  end

  def handle_event(
        "update-extra-text",
        %{"value" => value},
        %{assigns: %{stage: :extra_text}} = socket
      ) do
    {:noreply,
     socket
     |> assign(:extra_text, value)}
  end

  def handle_event("select-match-" <> match_id_str, _, %{assigns: %{stage: :match}} = socket) do
    {:noreply,
     socket
     |> assign(:match_id, String.to_integer(match_id_str))
     |> assign(:stage, :extra_text)}
  end

  def handle_event("select-no-match", _, %{assigns: %{stage: :match}} = socket) do
    {:noreply,
     socket
     |> assign(:match_id, nil)
     |> assign(:stage, :extra_text)}
  end

  def handle_event(
        "select-sub_type",
        %{"sub_type" => type},
        %{assigns: %{stage: :sub_type}} = socket
      ) do
    {:noreply,
     socket
     |> assign(:sub_type, type)
     |> assign(:stage, :match)}
  end

  def handle_event("select-type", %{"type" => type}, %{assigns: %{stage: :type}} = socket) do
    {:noreply,
     socket
     |> assign(:type, type)
     |> assign(:stage, :sub_type)}
  end

  def handle_event(
        "ignore-user",
        _event,
        %{assigns: %{current_user: current_user, user: user}} = socket
      ) do
    socket =
      case Account.ignore_user(current_user.id, user.id) do
        {:ok, _} ->
          socket
          |> put_flash(:success, "You are now ignoring #{user.name}")
          |> get_relationship()

        {:error, reason} ->
          socket
          |> put_flash(:warning, "Failed to ignore user: #{reason}")
          |> get_relationship()
      end

    {:noreply, socket}
  end

  def handle_event(
        "avoid-user",
        _event,
        %{assigns: %{current_user: current_user, user: user}} = socket
      ) do
    socket =
      case Account.avoid_user(current_user.id, user.id) do
        {:ok, _} ->
          socket
          |> put_flash(:success, "You are now avoiding #{user.name}")
          |> get_relationship()

        {:error, reason} ->
          socket
          |> put_flash(:warning, "Failed to avoid user: #{reason}")
          |> get_relationship()
      end

    {:noreply, socket}
  end

  def handle_event(
        "block-user",
        _event,
        %{assigns: %{current_user: current_user, user: user}} = socket
      ) do
    socket =
      case Account.block_user(current_user.id, user.id) do
        {:ok, _} ->
          socket
          |> put_flash(:success, "You are now blocking #{user.name}")
          |> get_relationship()

        {:error, reason} ->
          socket
          |> put_flash(:warning, "Failed to block user: #{reason}")
          |> get_relationship()
      end

    {:noreply, socket}
  end

  def handle_event(_text, _event, socket) do
    {:noreply, socket}
  end

  defp apply_structure(socket) do
    socket
    |> assign(:types, ReportLib.types())
    |> assign(:sub_types, ReportLib.sub_types())
  end

  defp get_user_matches(%{assigns: %{stage: :not_allowed}} = socket) do
    socket
  end

  defp get_user_matches(%{assigns: %{user: user}} = socket) do
    # For testing, change the days to a large number to see more matches
    cutoff = Timex.now() |> Timex.shift(days: -1, hours: -12)
    tz = socket.assigns[:tz]

    matches =
      Battle.list_matches(
        search: [
          started_after: cutoff,
          user_id: user.id
        ],
        order_by: "Newest first",
        select: [:id, :game_type, :team_size, :team_count, :finished, :map, :game_duration]
      )
      |> Enum.map(fn match ->
        label =
          case match.game_type do
            type when type in ["Small Team", "Large Team"] ->
              "#{match.team_size} vs #{match.team_size} on #{match.map}"

            "FFA" ->
              "#{match.team_count} way FFA on #{match.map}"

            v ->
              v
          end

        time_ago =
          if match.finished do
            TimexHelper.date_to_str(match.finished, format: :hms_or_ymd, until: true, tz: tz)
          else
            "In progress now"
          end

        Map.merge(match, %{
          label: label,
          time_ago: time_ago
        })
      end)

    socket
    |> assign(:matches, matches)
  end

  defp allowed_to_use_form(%{assigns: %{current_user: current_user, user: target_user}} = socket) do
    {allowed, failure_reason} =
      cond do
        current_user == nil ->
          {false, "You must be logged in to report someone"}

        current_user.id == target_user.id ->
          {false, "You cannot report yourself"}

        Account.is_restricted?(current_user, "Reporting") ->
          {false, "You are currently restricted from submitting new reports"}

        true ->
          {true, nil}
      end

    if allowed do
      socket
    else
      socket
      |> assign(:failure_reason, failure_reason)
      |> assign(:stage, :not_allowed)
    end
  end

  defp get_relationship(%{assigns: %{stage: :not_allowed}} = socket) do
    socket
  end

  defp get_relationship(%{assigns: %{current_user: current_user, user: user}} = socket) do
    relationship = Account.get_relationship(current_user.id, user.id)

    socket
    |> assign(:relationship, relationship)
  end
end
