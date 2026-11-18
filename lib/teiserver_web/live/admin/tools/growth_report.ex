defmodule TeiserverWeb.AdminLive.Tools.GrowthReport do
  @moduledoc false

  alias Teiserver.Account.GrowthReport
  alias Teiserver.Helpers.LiveChartsHelper

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
  @cols_options [1, 2, 4, 6]
  @chart_types LiveChartsHelper.get_multi_series_maps_chart_types()
  @data_form_types %{time_unit: :string, log_count: :integer}
  @render_form_types %{columns: :integer, chart_type: :string}
  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       chart_series: [],
       chart_types: @chart_types,
       cols_options: @cols_options
     )}
  end

  @impl LiveView
  def handle_params(_params, _uri, socket) when is_connected?(socket) do
    data_form =
      {%{}, @data_form_types}
      |> validate_data(prep_data_params())
      |> to_form(as: :data_form)

    render_form =
      {%{}, @render_form_types}
      |> validate_render(prep_render_params())
      |> to_form(as: :render_form)

    {date_keys, chart_series} =
      GrowthReport.build_series(data_form[:time_unit].value, data_form[:log_count].value)

    {:noreply,
     socket
     |> assign(
       connected?: true,
       data_form: data_form,
       render_form: render_form,
       time_units: @time_units,
       chart_types: @chart_types,
       chart_series: chart_series,
       date_keys: date_keys
     )}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket |> assign(connected?: false, data_form: nil, render_form: nil)}
  end

  @impl LiveView
  def handle_event(
        "update_data",
        %{"data_form" => data_form},
        socket
      ) do
    data_form =
      {%{}, @data_form_types}
      |> validate_data(data_form)
      |> to_form(as: :data_form)

    {:noreply, socket |> assign(:data_form, to_form(data_form, as: :data_form))}
  end

  def handle_event(
        "update_render",
        %{"render_form" => render_form},
        socket
      ) do
    render_form =
      {%{}, @render_form_types}
      |> validate_render(render_form)
      |> to_form(as: :render_form)

    {:noreply, socket |> assign(:render_form, to_form(render_form, as: :render_form))}
  end

  def handle_event("fetch", _params, socket) do
    data_form = socket.assigns.data_form

    if data_form.source.valid? do
      time_unit = get_field(data_form.source, :time_unit)
      log_count = get_field(data_form.source, :log_count)

      {date_keys, chart_series} =
        GrowthReport.build_series(time_unit, log_count)

      IO.inspect(chart_series)
      {:noreply, socket |> assign(chart_series: chart_series, date_keys: date_keys)}
    else
      {:noreply, socket}
    end
  end

  defp prep_data_params do
    %{
      "time_unit" => Enum.at(@time_units, 0),
      "log_count" => 31
    }
  end

  defp prep_render_params do
    %{"columns" => 1, "chart_type" => "line"}
  end

  defp validate_data(form, attrs) do
    form
    |> cast(attrs, [:time_unit, :log_count])
    |> validate_required([:time_unit, :log_count])
    |> validate_number(:log_count, greater_than: 0)
    |> validate_inclusion(:time_unit, @time_units)
    |> Map.put(:action, :validate)
  end

  defp validate_render(form, attrs) do
    form
    |> cast(attrs, [:columns, :chart_type])
    |> validate_required([:columns, :chart_type])
    |> validate_number(:columns, greater_than: 0)
    |> validate_inclusion(:columns, @cols_options)
    |> Map.put(:action, :validate)
  end

  defp calc_cols(form) do
    if is_nil(form[:columns]) do
      "grid-cols-1"
    else
      case form[:columns].value do
        2 ->
          "grid-cols-2"

        4 ->
          "grid-cols-4"

        6 ->
          "grid-cols-6"

        _columns ->
          "grid-cols-1"
      end
    end
  end
end
