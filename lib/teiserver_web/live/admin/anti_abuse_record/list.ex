defmodule TeiserverWeb.Admin.AntiAbuseRecordLive.List do
  @moduledoc false
  alias Teiserver.Moderation
  alias Teiserver.Moderation.AntiAbuseRecordQueries
  alias Teiserver.Repo

  use TeiserverWeb, :live_view

  import Teiserver.Helper.StringHelper, only: [uuid_part: 1]

  @impl Phoenix.LiveView
  def mount(_params, _session, %{assigns: %{scope: scope}} = socket) when is_connected?(socket) do
    Moderation.log_anti_abuse_record_access(nil, scope, :list)

    records =
      AntiAbuseRecordQueries.anti_abuse_records()
      |> AntiAbuseRecordQueries.load_user()
      |> AntiAbuseRecordQueries.load_restorer()
      |> AntiAbuseRecordQueries.order_by_inserted_at(:desc)
      |> Repo.all()

    socket
    |> assign(records: records)
    |> ok()
  end

  def mount(_params, _session, socket) do
    records = []

    socket
    |> assign(records: records)
    |> ok()
  end
end
