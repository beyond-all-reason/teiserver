defmodule Teiserver.Helper.ChartHelper do
  @moduledoc """
  Used for building chart data for c3 charts. Below is a suggested method using dates
  as the key.

  ##### Elixir code
  keys = ChartHelper.extract_keys(logs, :date, "x")

  data1 = ChartHelper.build_lines(logs, [
    %{
      name: "Unique users",
      paths: [~w"aggregates stats unique_users"]
    },
    %{
      name: "Unique players",
      paths: [~w"aggregates stats unique_players"]
    }
  ])

  data2 = ChartHelper.build_lines(logs, [
    %{
      name: "Peak users",
      paths: [~w"aggregates stats peak_user_counts total"]
    },
    %{
      name: "Peak players",
      paths: [~w"aggregates stats peak_user_counts player"]
    },
    %{
      name: "Accounts created",
      paths: [~w"aggregates stats accounts_created"]
    }
  ])

  ##### HTML code
  <script>
    function generate_chart (elem_id, json) {
      var chart = c3.generate({
        bindto: elem_id,
        data: {
          x: 'x',
          columns: json
        },
        axis: {
          x: {
            type: 'timeseries',
            tick: {format: '%Y-%m-%d'}
          },
          y: {
            min: 0,
            padding: {top: 15, bottom: 0}
          }
        }
      });
    }

    $(function() {
      generate_chart("#chart1", <%= raw Jason.encode!([@keys | @data1]) %>);
      generate_chart("#chart2", <%= raw Jason.encode!([@keys | @data2]) %>);
    });
  </script>
  """

  alias Teiserver.Helper.TimexHelper

  @doc """
  Takes a list of log-data and then outputs line-chart
  data based on rules supplied in the fields argument.

  Each log should be a struct/map either of the data or an object containing the data in the :data key.

  Each field is a map
    name: A string which if set will be prepended to the list of results
    paths: A list of paths which will be sent to `get_in/2`
    mapper: A function applied to the value extracted, defaults to `fn id -> id end`
    aggregator: A function used to aggregate the paths, defaults to `Enum.sum/1`
    post_processor: A function used to apply any final changes, defaults to `fn id -> id end`

  Example call:
  # This will produce 3 sets of data
  perform(logs, [
    # Basic example
    %{
      name: "Players",
      paths: [
        [:data, "players", "count"]
      ],
    },

    # Combining data from two paths
    %{
      name: "Total users",
      paths: [
        [:data, "players", "count"],
        [:data, "spectators", "count"]
      ]
    }},

    # Applying a different mapper and post_process function
    %{
      name: "Average load time",
      paths: [
        [:data, "players", "load_time"],
        [:data, "spectators", "load_time"]
      ],
      mapper: (fn vs -> Enum.sum(vs) / Enum.count(vs) end),
      post_processor: &round/1
    }
  ])

  Output should be in the form:
  [
    ["Players", 1, 2, 3],
    ["Total users", 5, 6, 7],
    ["Average load time", 9, 8, 7]
  ]
  """
  @spec build_lines(list, [{String.t(), map()}]) :: list()
  def build_lines(logs, field_list) do
    field_list
    |> Enum.map(fn field_instructions ->
      data =
        logs
        |> get_field_data(field_instructions)
        |> aggregate_data(field_instructions)
        |> post_process_data(field_instructions)

      if field_instructions[:name] do
        [field_instructions[:name] | data]
      else
        data
      end
    end)
  end

  # Takes the paths
  defp get_field_data(logs, %{paths: paths} = field_instructions) do
    paths
    |> Enum.map(fn path ->
      logs
      |> get_data_from_path(path)
      |> map_raw_data(field_instructions)
    end)
    |> Enum.zip()
  end

  defp get_data_from_path(logs, path) do
    logs
    |> Enum.map(fn
      %{data: log_data} ->
        get_in(log_data, path)

      log_data ->
        get_in(log_data, path)
    end)
  end

  # In case we want to do any post-processing (e.g rounding)
  defp map_raw_data(data, %{mapper: mapper}) do
    data
    |> Enum.map(mapper)
  end

  defp map_raw_data(data, _no_mapper), do: data

  # Take our path(s) of data and turn them into a single combined path of data
  defp aggregate_data(data, %{aggregator: aggregator}) do
    data
    |> Enum.map(&Tuple.to_list/1)
    |> Enum.map(aggregator)
  end

  defp aggregate_data(data, _no_aggregator) do
    aggregate_data(data, %{aggregator: &Enum.sum/1})
  end

  # In case we want to do any post-processing (e.g rounding)
  defp post_process_data(data, %{post_processor: post_processor}) do
    data
    |> Enum.map(post_processor)
  end

  defp post_process_data(data, _no_post_process), do: data

  @spec extract_keys(list, atom, String.t() | nil) :: list
  def extract_keys(logs, :date, prepend_value) do
    result =
      logs
      |> Enum.map(fn log -> log.date |> TimexHelper.date_to_str(format: :ymd) end)

    if prepend_value do
      [prepend_value | result]
    else
      result
    end
  end
end
