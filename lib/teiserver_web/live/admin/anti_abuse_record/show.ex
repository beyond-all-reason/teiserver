defmodule TeiserverWeb.Admin.AntiAbuseRecordLive.Show do
  @moduledoc false
  alias Teiserver.Moderation
  alias Teiserver.Moderation.AntiAbuseRecord
  alias Teiserver.Moderation.AntiAbuseRecordQueries
  alias Teiserver.Repo

  use TeiserverWeb, :live_view

  import Teiserver.Helper.StringHelper, only: [uuid_part: 1]

  @impl Phoenix.LiveView
  def mount(%{"id" => record_id}, _session, %{assigns: %{scope: scope}} = socket)
      when is_connected?(socket) do
    record =
      AntiAbuseRecordQueries.anti_abuse_records()
      |> AntiAbuseRecordQueries.where_id(record_id)
      |> AntiAbuseRecordQueries.load_user()
      |> AntiAbuseRecordQueries.load_restorer()
      |> AntiAbuseRecordQueries.order_by_inserted_at(:desc)
      |> Repo.one()

    Moderation.log_anti_abuse_record_access(record, scope, :show)

    if record do
      socket
      |> assign(record: record)
      |> ok()
    else
      socket
      |> redirect(to: ~p"/admin/anti-abuse-records/list")
      |> put_flash(:info, "No record found")
      |> ok()
    end
  end

  def mount(_params, _session, socket) do
    record = %AntiAbuseRecord{
      expires_at: DateTime.utc_now(),
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    socket
    |> assign(record: record)
    |> ok()
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _url, socket) do
    socket
    |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_event(_event_text, _event_data, %{assigns: _assigns} = socket) do
    socket
    |> noreply()
  end
end
