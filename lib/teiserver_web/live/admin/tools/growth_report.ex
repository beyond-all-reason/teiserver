defmodule TeiserverWeb.AdminLive.Tools.GrowthReport do
  @moduledoc false

  alias Teiserver.Helper.DateHelper
  alias Teiserver.Helpers.LiveChartsHelper

  alias Teiserver.Account.GrowthReport

  alias TeiserverWeb.AdminLive.ToolsComponents
  use TeiserverWeb, :live_view
  import Ecto.Changeset

  @time_units [
    "Day",
    "Week",
    "Month",
    "Quarter",
    "Year"
  ]
  @chart_types LiveChartsHelper.get_chart_types()
  @form_types %{time_unit: :string, log_count: :integer, columns: :integer, type: :atom}

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:charts, %{unique: nil})}
  end

  @impl LiveView
  def handle_params(_params, _uri, socket) when is_connected?(socket) do
    form =
      {%{}, @form_types}
      |> validate(prep_params())

    {:noreply,
     socket
     |> assign(connected?: true, form: to_form(form, as: :growth_form), time_units: @time_units)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket |> assign(connected?: false, form: nil)}
  end

  @impl LiveView
  def handle_event(
        "update",
        %{"growth_form" => growth_form},
        socket
      ) do

    form =
      {%{}, @form_types}
      |> validate(growth_form)
      |> to_form(as: :growth_form)

    {:noreply, socket |> assign(:form, to_form(form, as: :growth_form))}
  end
  def handle_event("fetch", _params, socket) do
    form = socket.assigns.form
    if form.source.valid? do
      time_unit = get_field(form.source, :time_unit)
      log_count = get_field(form.source, :log_count)
      columns = get_field(form.source, :columns)



     case GrowthReport.build_charts(time_unit, log_count) do
       {:ok, charts} ->
          {:noreply, socket |> assign(charts: %{unique: charts})}
        {:error, _reason} ->
          {:noreply, socket |> assign(charts: %{unique: nil})}
     end

    else

      {:noreply, socket}
    end
  end

  defp prep_params() do
    %{"time_unit" => Enum.at(@time_units, 0), "log_count" => 31, "columns" => 1}
  end

  defp validate(form, attrs) do
    form
    |> cast(attrs, [:time_unit, :log_count, :columns])
    |> validate_required([:time_unit, :log_count, :columns])
    |> validate_number(:columns, greater_than: 0)
    |> validate_number(:log_count, greater_than: 0)
    |> Map.put(:action, :validate)
  end
end
