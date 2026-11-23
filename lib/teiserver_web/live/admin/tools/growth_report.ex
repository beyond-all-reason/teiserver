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

  @chart_types LiveChartsHelper.get_multi_series_maps_chart_types()
  @data_form_types %{time_unit: :string, log_count: :integer}
  @render_form_types %{chart_type: :string}
  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       charts: nil,
       page_title: "Growth report"
     )}
  end

  @impl LiveView
  def handle_params(_params, _uri, socket) when is_connected?(socket) do
    {data_form, render_form} = prep_initial()

    {date_keys, chart_series} =
      GrowthReport.build_series(data_form[:time_unit].value, data_form[:log_count].value)

    charts =
      Enum.map(chart_series, fn %{title: title, series: series} ->
        LiveChartsHelper.generate_multi_series_maps_chart(
          series,
          date_keys,
          LiveChartsHelper.to_chart_type(render_form[:chart_type].value),
          title
        )
      end)

    {:noreply,
     socket
     |> assign(
       connected?: true,
       data_form: data_form,
       render_form: render_form,
       time_units: @time_units,
       chart_types: @chart_types,
       charts: charts
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
    %{data_form: data_form, render_form: render_form} = socket.assigns

    if data_form.source.valid? do
      time_unit = get_field(data_form.source, :time_unit)
      log_count = get_field(data_form.source, :log_count)

      {date_keys, chart_series} =
        GrowthReport.build_series(time_unit, log_count)

      charts =
        Enum.map(chart_series, fn %{title: title, series: series} ->
          LiveChartsHelper.generate_multi_series_maps_chart(
            series,
            date_keys,
            LiveChartsHelper.to_chart_type(render_form[:chart_type].value),
            title
          )
        end)

      {:noreply, socket |> assign(charts: charts)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("reset-search", _unsigned_params, socket) do
    {data_form, render_form} = prep_initial()
    {:noreply, socket |> assign(data_form: data_form, render_form: render_form)}
  end

  defp prep_data_params do
    %{
      "time_unit" => Enum.at(@time_units, 0),
      "log_count" => 31
    }
  end

  defp prep_render_params do
    %{"chart_type" => "line"}
  end

  defp prep_initial do
    data_form =
      {%{}, @data_form_types}
      |> validate_data(prep_data_params())
      |> to_form(as: :data_form)

    render_form =
      {%{}, @render_form_types}
      |> validate_render(prep_render_params())
      |> to_form(as: :render_form)

    {data_form, render_form}
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
    |> cast(attrs, [:chart_type])
    |> validate_required([:chart_type])
    |> validate_inclusion(:chart_type, Enum.map(@chart_types, &Atom.to_string/1))
    |> Map.put(:action, :validate)
  end
end
