defmodule Central.General.FileHelperTest do
  use Central.DataCase, async: true

  alias Central.Helpers.FileHelper

  @extensions ~w(url txt pdf jpeg jpg png gif doc docx csv xls xlsx ods ppt pptx mp3 wav mp4 avi mkv m4v sh py ex exs eex html sql php java xml json)

  test "icon_and_colour" do
    values =
      [
        "URL",
        "Plain text",
        "PDF",
        "Image",
        "Rich text",
        "Spreadsheet",
        "Presentation",
        "Audio",
        "Video",
        "Code",
        "type"
      ]
      |> Enum.map(&FileHelper.icon_and_colour/1)
      |> Enum.uniq()

    assert Enum.count(values) == 11
  end

  test "browser_viewer" do
    values =
      ["mp4", "ext"]
      |> Enum.map(&FileHelper.browser_viewer/1)
      |> Enum.uniq()

    assert Enum.count(values) == 2
  end

  test "file_type" do
    values =
      @extensions
      |> Enum.map(&FileHelper.file_type/1)
      |> Enum.uniq()

    assert Enum.count(values) == 10
  end

  test "ext_icon" do
    values =
      [100, 1_000, 10_000, 100_000, 1_000_000, 10_000_000, 100_000_000]
      |> Enum.map(fn size -> FileHelper.ext_icon(nil, size) end)
      |> Enum.uniq()

    assert Enum.count(values) == 7
  end

  test "mem_normalize" do
    values =
      [100, 1_000, 10_000, 100_000, 1_000_000, 10_000_000, 100_000_000]
      |> Enum.map(fn size -> FileHelper.mem_normalize(size) end)
      |> Enum.uniq()

    assert Enum.count(values) == 7
  end
end
