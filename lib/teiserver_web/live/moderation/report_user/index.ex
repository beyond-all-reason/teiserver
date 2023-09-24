defmodule TeiserverWeb.Moderation.ReportUserLive.Index do
  use TeiserverWeb, :live_view
  alias Teiserver.{Account, Battle, Moderation}
  alias Teiserver.Moderation.ReportLib
  alias Teiserver.Helper.TimexHelper

  @impl true
  def mount(_params, _session, socket) do
    socket = socket
      |> assign(:site_menu_active, "teiserver_account")
      |> assign(:view_colour, Moderation.colour())
      |> assign(:report, %{})
      |> assign(:user, nil)
      |> assign(:stage, :loading)
      |> add_breadcrumb(name: "Report user", url: ~p"/moderation/report_user")
      |> apply_structure

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    user = Account.get_user_by_id(id)

    socket = socket
      |> assign(:id_str, id)
      |> assign(:user, user)
      |> assign(:report, %{
        user_id: user.id
      })
      |> assign(:stage, :type)
      |> get_user_matches


    # socket = socket
    #   |> assign(:type, "chat")
    #   |> assign(:sub_type, "sub-chat")
    #   |> assign(:match_id, 123)
    #   |> assign(:stage, :extra_info)

    {:noreply, socket}
  end

  def handle_params(_params, _url, socket) do
    socket = socket
      |> assign(:stage, :user)

    {:noreply, socket}
  end

  @impl true
  def handle_event("submit-extra-info", _event, %{assigns: %{stage: :extra_info}} = socket) do
    IO.puts ""
    IO.inspect nil
    IO.puts ""

    result = :success

    {:noreply, socket
      |> assign(:result, result)
      |> assign(:stage, :completed)
    }
  end

  def handle_event("update-extra-info", %{"value" => value}, %{assigns: %{stage: :extra_info}} = socket) do
    {:noreply, socket
      |> assign(:extra_info, value)
    }
  end

  def handle_event("select-match-" <> match_id_str, _, %{assigns: %{stage: :match}} = socket) do
    {:noreply, socket
      |> assign(:match_id, match_id_str)
      |> assign(:stage, :extra_info)
    }
  end

  def handle_event("select-no-match", _, %{assigns: %{stage: :match}} = socket) do
    {:noreply, socket
      |> assign(:match_id, nil)
      |> assign(:stage, :extra_info)
    }
  end

  def handle_event("select-sub_type", %{"sub_type" => type}, %{assigns: %{stage: :sub_type}} = socket) do
    {:noreply, socket
      |> assign(:sub_type, type)
      |> assign(:stage, :match)
    }
  end

  def handle_event("select-type", %{"type" => type}, %{assigns: %{stage: :type}} = socket) do
    {:noreply, socket
      |> assign(:type, type)
      |> assign(:stage, :sub_type)
    }
  end

  def handle_event(_text, _event, socket) do
    {:noreply, socket}
  end

  defp apply_structure(socket) do
    socket
      |> assign(:types, ReportLib.types())
      |> assign(:sub_types, ReportLib.sub_types())
  end

  defp get_user_matches(%{assigns: %{user: user}} = socket) do
    cutoff = Timex.now() |> Timex.shift(hours: -36)

    matches =
      Battle.list_matches(
        search: [
          started_after: cutoff,
          user_id: user.id
        ],
        order_by: "Newest first",
        select: [:id, :game_type, :team_size, :team_count, :finished, :map]
      )
      |> Enum.map(fn match ->
        label = case match.game_type do
          "Team" -> "#{match.team_size} vs #{match.team_size} on #{match.map}"
          "FFA" -> "#{match.team_count} way FFA on #{match.map}"
          v -> v
        end

        time_ago = if match.finished do
          TimexHelper.date_to_str(match.finished, format: :hms_or_ymd, until: true)
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
end
