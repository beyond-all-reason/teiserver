defmodule Central.Admin.CoverageLib do
  @moduledoc false
  defp capture_parse(s) do
    ~r/(?<cov>[0-9\.]+)%\s+lib\/
      (?<file>[_a-zA-Z0-9\/\.\ ]+\/[_a-zA-Z0-9\/\.\ ]+?)\s+
      (?<lines>[0-9]+)\s+
      (?<relevant>[0-9]+)\s+
      (?<missed>[0-9]+)/xu
    |> Regex.named_captures(String.trim(s))
  end

  defp add_section(m) do
    [section | _] =
      m["trimmed_file"]
      # |> String.replace("web/", "")
      |> String.split("/")

    m |> Map.put("section", section)
  end

  defp sum_matches(match, acc) do
    s = Map.get(acc, match["section"])

    s =
      s
      |> Map.put(:lines, s[:lines] + String.to_integer(match["lines"]))
      |> Map.put(:relevant, s[:relevant] + String.to_integer(match["relevant"]))
      |> Map.put(:missed, s[:missed] + String.to_integer(match["missed"]))
      |> Map.put(:files, s[:files] + 1)

    Map.put(acc, match["section"], s)
  end

  defp sum_section({section, data}) do
    %{
      section: section,
      coverage: 100 * (1 - data[:missed] / data[:relevant]),
      lines: data[:lines],
      missed: data[:missed],
      relevant: data[:relevant],
      files: data[:files]
    }
  end

  defp headline_stats(parsed_data) do
    sections =
      parsed_data
      |> Enum.map(fn m -> m["section"] end)
      |> Enum.uniq()
      |> Map.new(fn s -> {s, %{lines: 0, relevant: 0, missed: 0, cov: 0, files: 0}} end)

    parsed_data
    |> Enum.reduce(sections, &sum_matches/2)
    |> Enum.map(&sum_section/1)
    |> Enum.sort_by(fn row -> row.section |> String.replace("/", "") end, &<=/2)
  end

  defp project_stats(parsed_data) do
    data =
      parsed_data
      |> Enum.reduce(
        %{lines: 0, relevant: 0, missed: 0, cov: 0, files: 0},
        fn match, acc ->
          %{
            lines: acc[:lines] + String.to_integer(match["lines"]),
            relevant: acc[:relevant] + String.to_integer(match["relevant"]),
            missed: acc[:missed] + String.to_integer(match["missed"]),
            files: acc[:files] + 1
          }
        end
      )

    Map.put(data, :coverage, 100 * (1 - data[:missed] / max(data[:relevant], 1)))
  end

  defp module_stats(parsed_data, file_path) do
    sections =
      parsed_data
      |> Enum.map(fn m -> m["section"] end)
      |> Enum.uniq()
      |> Enum.map(fn s ->
        section_data =
          parsed_data
          |> Enum.filter(fn f ->
            f["section"] == s and f["cov"] != "100.0" and f["missed"] != "0"
          end)
          |> Enum.map(fn f ->
            {f["file"] |> String.replace(file_path <> f["section"] <> "/", ""), String.to_float(f["cov"]), String.to_integer(f["missed"])}
          end)

        wp =
          section_data
          |> Enum.sort_by(fn {_, c, _} ->
            c
          end)
          |> Enum.take(10)

        mm =
          section_data
          |> Enum.sort_by(
            fn {_, _, m} ->
              m
            end,
            &>=/2
          )
          |> Enum.take(10)

        %{name: s, worst_percentage: wp, most_missed: mm}
      end)

    # Example line
    # %{"cov" => "100.0", "file" => "web/hindsight/models/template_tag.ex",
    #   "lines" => "17", "missed" => "0", "relevant" => "2",
    #   "section" => "hindsight"}

    sections
  end

  @doc """
  data: The raw output from coveralls
  file_path: The file path we require a file to have to be considered, allowing us to filter
  """
  def parse_coverage(data, file_path) do
    parsed_data =
      data
      |> String.split("\n")
      |> Enum.map(&capture_parse/1)
      |> Enum.filter(fn m ->
        cond do
          m == nil -> false
          m["relevant"] == "0" -> false
          String.contains?(m["file"], ["/channels/"]) -> false
          not String.contains?(m["file"], file_path) -> false
          true -> true
        end
      end)
      |> Enum.map(fn m ->
        trimmed_file = m["file"] |> String.replace(file_path, "")
        Map.put(m, "trimmed_file", trimmed_file)
      end)
      |> Enum.map(&add_section/1)

    [
      headline: headline_stats(parsed_data),
      project: project_stats(parsed_data),
      module: module_stats(parsed_data, file_path)
    ]
  end

  def get_overall_stats(results) do
    starting = %{
      files: 0,
      lines: 0,
      missed: 0,
      relevant: 0
    }

    results[:headline]
    |> Enum.reduce(starting, fn row, acc ->
      %{
        files: row.files + acc.files,
        lines: row.lines + acc.lines,
        missed: row.missed + acc.missed,
        relevant: row.relevant + acc.relevant
      }
    end)
  end
end
