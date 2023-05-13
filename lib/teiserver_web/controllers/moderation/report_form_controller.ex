defmodule TeiserverWeb.Moderation.ReportFormController do
  @moduledoc false
  use CentralWeb, :controller

  alias Teiserver.{Account, Battle, Moderation}
  alias Moderation.ReportLib
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  require Logger

  plug(AssignPlug,
    site_menu_active: "moderation",
    sub_menu_active: "moderation"
  )

  plug Bodyguard.Plug.Authorize,
    policy: Teiserver.Auth,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}

  @spec index(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def index(conn, %{"id" => id}) do
    target_id = int_parse(id)

    if conn.assigns.current_user.id == target_id do
      conn
      |> put_status(:unprocessable_entity)
      |> render("self_report.html")
    else
      case Account.get_user(target_id) do
        nil ->
          render(conn, "no_user.html")

        target ->
          cutoff = Timex.now() |> Timex.shift(hours: -36)

          matches =
            Battle.list_matches(
              search: [
                finished_after: cutoff,
                user_id: target.id
              ],
              order_by: "Newest first"
            )

          conn
          |> assign(:sections, ReportLib.sections())
          |> assign(:sub_sections, ReportLib.sub_sections())
          |> assign(:matches, matches)
          |> assign(:target, target)
          |> render("index.html")
      end
    end
  end

  @spec create(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def create(conn, %{"report" => report}) do
    target_id = report["target_id"] |> int_parse

    if conn.assigns.current_user.id == target_id do
      conn
      |> put_status(:unprocessable_entity)
      |> render("self_report.html")
    else
      {match_id, relationship} =
        case report["match_id"] do
          "none" ->
            {nil, nil}

          match_id_str ->
            case Battle.get_match(match_id_str, preload: [:members]) do
              nil ->
                {nil, nil}

              match ->
                target_member =
                  match.members
                  |> Enum.find(fn member -> member.user_id == target_id end)

                reporter_member =
                  match.members
                  |> Enum.find(fn member -> member.user_id == conn.assigns.current_user.id end)

                relationship =
                  cond do
                    reporter_member == nil -> nil
                    target_member.team_id == reporter_member.team_id -> "Allies"
                    target_member.team_id != reporter_member.team_id -> "Opponents"
                  end

                {match.id, relationship}
            end
        end
      result =
        Moderation.create_report(%{
          reporter_id: conn.assigns.current_user.id,
          target_id: report["target_id"],
          type: report["type"],
          sub_type: report["sub_type"],
          extra_text: report["extra_text"],
          match_id: match_id,
          relationship: relationship
        })

      case result do
        {:ok, _report} ->
          conn
          |> redirect(to: Routes.moderation_report_form_path(conn, :success))

        {:error, changeset} ->
          Logger.error(Kernel.inspect(changeset))
          raise "Error submitting report"

          conn
          |> render("index.html")
      end
  end

  @spec success(Plug.Conn.t(), Map.t()) :: Plug.Conn.t()
  def success(conn, _params) do
    conn
    |> render("success.html")
  end
end
