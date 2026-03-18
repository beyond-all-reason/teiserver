#!/usr/bin/env elixir

# Script to expand multi-module aliases like:
#   alias Teiserver.Mod.{A, B, C}
# into:
#   alias Teiserver.Mod.A
#   alias Teiserver.Mod.B
#   alias Teiserver.Mod.C

defmodule ExpandAliases do
  @multi_alias_regex ~r/^(\s*)(alias\s+)([\w.]+)\.{([^}]+)}/

  def run(args) do
    dry_run = "--dry-run" in args

    "lib/**/*.ex"
    |> Path.wildcard()
    |> Kernel.++(Path.wildcard("test/**/*.{ex,exs}"))
    |> Enum.each(&process_file(&1, dry_run))
  end

  defp process_file(path, dry_run) do
    content = File.read!(path)
    new_content = expand_aliases(content)

    if content != new_content do
      IO.puts("#{if dry_run, do: "[DRY RUN] ", else: ""}Updating: #{path}")

      if dry_run do
        show_diff(content, new_content)
      else
        File.write!(path, new_content)
      end
    end
  end

  defp expand_aliases(content) do
    content
    |> String.split("\n")
    |> Enum.flat_map(&expand_line/1)
    |> Enum.join("\n")
  end

  defp expand_line(line) do
    case Regex.run(@multi_alias_regex, line) do
      [_full, indent, alias_keyword, base_module, modules_str] ->
        modules_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(fn mod ->
          "#{indent}#{alias_keyword}#{base_module}.#{mod}"
        end)

      nil ->
        [line]
    end
  end

  defp show_diff(old, _new) do
    old
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.each(fn {line, idx} ->
      case Regex.run(@multi_alias_regex, line) do
        [_full, indent, alias_keyword, base_module, modules_str] ->
          IO.puts("  Line #{idx}:")
          IO.puts("    - #{String.trim(line)}")

          modules_str
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.each(fn mod ->
            IO.puts("    + #{alias_keyword}#{base_module}.#{mod}")
          end)

        nil ->
          :ok
      end
    end)

    IO.puts("")
  end
end

ExpandAliases.run(System.argv())
