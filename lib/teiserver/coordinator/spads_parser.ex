defmodule Teiserver.Coordinator.SpadsParser do

  @spec handle_in(String.t()) :: {:host_update, Map.t()} | nil
  def handle_in(msg) do
    cond do
      (match = Regex.run(~r/teamSize=(\d)+/, msg)) ->
        [_, size] = match
        {:host_update, %{host_teamsize: String.to_integer(size)}}
      (match = Regex.run(~r/nbTeams=(\d)+/, msg)) ->
        [_, count] = match
        {:host_update, %{host_teamcount: String.to_integer(count)}}
      true -> nil
    end
  end
end
