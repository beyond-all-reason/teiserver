defmodule Central.Helpers.FileHelper do
  @moduledoc false
  import Phoenix.HTML, only: [raw: 1]

  def icon_and_colour(type) do
    case type do
      "URL" -> {"fa-solid fa-link", "success2"}
      "Plain text" -> {"fa-solid fa-file-alt", "info2"}
      "PDF" -> {"fa-solid fa-file-pdf", "danger"}
      "Image" -> {"fa-solid fa-file-image", "primary2"}
      "Rich text" -> {"fa-solid fa-file-word", "primary"}
      "Spreadsheet" -> {"fa-solid fa-file-excel", "success"}
      "Presentation" -> {"fa-solid fa-file-powerpoint", "warning"}
      "Audio" -> {"fa-solid fa-file-audio", "info"}
      "Video" -> {"fa-solid fa-file-video", "info2"}
      "Code" -> {"fa-solid fa-file-code", "default"}
      _type -> {"fa-solid fa-file", "default"}
    end
  end

  def browser_viewer(ext) do
    case ext do
      "mp4" -> "video"
      "webm" -> "video"
      _ -> false
    end
  end

  def file_type(ext) do
    cond do
      Enum.member?(~w(url), ext) -> "URL"
      Enum.member?(~w(txt), ext) -> "Plain text"
      Enum.member?(~w(pdf), ext) -> "PDF"
      Enum.member?(~w(jpeg jpg png gif), ext) -> "Image"
      Enum.member?(~w(doc docx), ext) -> "Rich text"
      Enum.member?(~w(csv xls xlsx ods), ext) -> "Spreadsheet"
      Enum.member?(~w(ppt pptx), ext) -> "Presentation"
      Enum.member?(~w(mp3 wav), ext) -> "Audio"
      Enum.member?(~w(mp4 avi mkv m4v webm), ext) -> "Video"
      Enum.member?(~w(sh py ex exs eex html sql php java xml json), ext) -> "Code"
      true -> "No type"
    end
  end

  def type_icon(file_type, size \\ "") do
    {icon, colour} =
      file_type
      |> icon_and_colour

    raw("<i class='fa-fw #{icon} #{size} text-#{colour}'></i>")
  end

  def ext_icon(ext, size \\ "") do
    ext
    |> file_type
    |> type_icon(size)
  end

  def mem_normalize(v) when is_integer(v), do: _mem_normalize(v)
  def mem_normalize(v), do: v

  defp _mem_normalize(v) when v < 1_024, do: "#{v} bytes"
  defp _mem_normalize(v) when v < 1_048_576, do: "#{Float.round(v / 1024, 2)} KB"
  defp _mem_normalize(v) when v < 1_073_741_824, do: "#{Float.round(v / 1_048_576, 2)} MB"
  defp _mem_normalize(v), do: "#{Float.round(v / 1_073_741_824, 2)} GB"
end
