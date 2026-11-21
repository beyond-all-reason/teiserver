defmodule TeiserverWeb.AdminLive.Tools.RetentionReport do
  @moduledoc false
  alias Teiserver.Account.RetentionReport
  alias Teiserver.Helper.DatePresets
  alias Teiserver.Helpers.DateValidations
  alias TeiserverWeb.AdminLive.ToolsComponents
  use TeiserverWeb, :live_view
  import Ecto.Changeset
  @range_max 365
  @dates DatePresets.long_presets() |> Enum.reverse() |> Enum.drop(1) |> Enum.reverse()
  @form_types %{start_date: :date, end_date: :date, skip0: :string, date_range: :string}

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Retention report",
       max_key: 0,
       play_retention_grouping: %{},
       user_count: 0
     )}
  end

  @impl LiveView
  def handle_params(_params, _uri, socket) when is_connected?(socket) do
    changeset =
      {%{}, @form_types}
      |> validate(prep_params())

    form = to_form(changeset, as: :retention_form)

    {:noreply,
     socket
     |> assign(connected?: true, form: form, dates: @dates, retention_chart: nil)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket |> assign(connected?: false, retention_chart: nil)}
  end

  @impl LiveView
  def handle_event("update", %{"retention_form" => retention_form} = _params, socket) do
    changeset =
      {%{}, @form_types}
      |> validate(retention_form)

    form = to_form(changeset, as: :retention_form)

    {:noreply, socket |> assign(form: form)}
  end

  def handle_event("update_range", %{"retention_form" => %{"date_range" => date_range}}, socket) do
    form = socket.assigns.form
    {start_date, end_date} = DatePresets.parse(date_range, "", "")

    params = %{form.params | "start_date" => start_date, "end_date" => end_date}

    changeset =
      {%{}, @form_types}
      |> validate(params)

    {:noreply, socket |> assign(form: to_form(changeset, as: :retention_form))}
  end

  def handle_event("fetch", _params, socket) do
    form = socket.assigns.form

    if form.source.valid? do
      start_date = get_field(form.source, :start_date)
      end_date = get_field(form.source, :end_date)
      skip0 = form[:skip0].value
      {chart, user_count} = RetentionReport.build_chart(start_date, end_date, skip0)
      {:noreply, socket |> assign(user_count: user_count, retention_chart: chart, form: form)}
    else
      {:noreply, socket}
    end
  end

  defp prep_params do
    date_range = "This month"
    {start_date, end_date} = DatePresets.parse(date_range, "", "")

    %{
      "date_range" => date_range,
      "start_date" => start_date,
      "end_date" => end_date,
      "skip0" => "true"
    }
  end

  defp validate(form, attrs) do
    form
    |> cast(attrs, [:start_date, :end_date])
    |> validate_required([:start_date, :end_date], message: "Invalid date.")
    |> DateValidations.validate_date_not_in_future(:start_date)
    |> DateValidations.validate_date_order()
    |> DateValidations.validate_max_range(@range_max)
    |> Map.put(:action, :validate)
  end
end
