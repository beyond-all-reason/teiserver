defmodule TeiserverWeb.AdminLive.Tools.Population do
  @moduledoc false

  alias Teiserver.Account.PopulationReport
  alias Teiserver.Account.UserQueries
  alias Teiserver.Helper.DatePresets
  alias TeiserverWeb.AdminLive.ToolsComponents
  use TeiserverWeb, :live_view

  @metric_options [
    "Client name",
    "Country code",
    "Rank",
    "Hardware: CPU info",
    "Hardware: display max",
    "Hardware: GPU info",
    "Hardware: OS info"
  ]
  @date_presets ["Ignore" | DatePresets.presets()]
  @impl LiveView
  def mount(_params, _session, %Socket{} = socket) do
    socket
    |> assign(:page_title, "Population")
    |> ok()
  end

  @impl LiveView
  def handle_params(_params, _uri, socket) when is_connected?(socket) do
    search = default_search()
    form = to_form(search)

    {total, user_data} = get_data(form.params)

    socket
    |> assign(
      connected?: true,
      search: search,
      form: form,
      metric_options: @metric_options,
      login_presets: @date_presets,
      register_presets: @date_presets,
      user_data: user_data,
      user_count: total
    )
    |> noreply()
  end

  def handle_params(_params, _uri, socket) do
    socket
    |> assign(:user_count, 0)
    |> assign(:connected?, false)
    |> noreply()
  end

  @impl LiveView
  def handle_event("update", params, socket) do
    new_presets = reject_presets_after(params["registered"])

    form =
      if params["last_login"] in new_presets do
        to_form(params)
      else
        Map.put(params, "last_login", "This week")
        |> to_form()
      end

    {total, user_data} = get_data(form.params)

    {:noreply,
     socket
     |> assign(form: form, login_presets: new_presets, user_data: user_data, user_count: total)}
  end

  defp default_search do
    %{
      "metric" => "Client name",
      "last_login" => "This week",
      "registered" => "All time",
      "exclude_bots" => "true"
    }
  end

  defp reject_presets_after(selected_preset) do
    if selected_preset == "Ignore" do
      @date_presets
    else
      case Enum.find_index(@date_presets, &(&1 == selected_preset)) do
        nil ->
          @date_presets

        index ->
          Enum.take(@date_presets, index + 1)
      end
    end
  end

  defp get_data(
         %{
           "exclude_bots" => exclude_bots,
           "last_login" => last_login,
           "registered" => registered,
           "metric" => metric
         } = _params
       ) do
    case get_metric(metric) do
      nil ->
        {0, []}

      metric_field ->
        query =
          UserQueries.users()
          |> maybe_pass_registered(registered)
          |> maybe_pass_last_login(last_login)
          |> maybe_exclude_bots(exclude_bots)

        PopulationReport.count_by_field(query, metric_field)
    end
  end

  defp get_metric("Client name"), do: "lobby_client"
  defp get_metric("Country code"), do: "country"
  defp get_metric("Rank"), do: "rank"
  defp get_metric("Hardware: CPU info"), do: "hardware:cpuinfo"
  defp get_metric("Hardware: display max"), do: "hardware:display_max"
  defp get_metric("Hardware: GPU info"), do: "hardware:gpuinfo"
  defp get_metric("Hardware: OS info"), do: "osinfo"

  defp get_metric(_metric), do: nil

  defp maybe_mark_as_na(nil), do: "N/A"
  defp maybe_mark_as_na(value), do: value

  defp maybe_pass_last_login(query, "Ignore"), do: query

  defp maybe_pass_last_login(query, last_login) do
    {last_login_after, last_login_before} = DatePresets.parse(last_login, "", "")

    query
    |> UserQueries.where_logged_in_after(last_login_after)
    |> UserQueries.where_logged_in_before(last_login_before)
  end

  defp maybe_pass_registered(query, "Ignore"), do: query

  defp maybe_pass_registered(query, registered) do
    {registered_after, registered_before} = DatePresets.parse(registered, "", "")

    query
    |> UserQueries.where_registered_before(
      DateTime.new!(registered_before, ~T"00:00:00", "Etc/UTC")
    )
    |> UserQueries.where_registered_after(
      DateTime.new!(registered_after, ~T"00:00:00", "Etc/UTC")
    )
  end

  defp maybe_exclude_bots(query, "true") do
    query
    |> UserQueries.where_not_has_role("Bot")
  end

  defp maybe_exclude_bots(query, "false") do
    query
  end

  defp maybe_exclude_bots(query, _value), do: query
end
