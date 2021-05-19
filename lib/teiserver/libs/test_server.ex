defmodule Teiserver.Libs.TestServer do
  use GenServer
  alias Teiserver.TeiserverTestLib

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, @table_name, opts)
  end

  def init(_) do
    table = :ets.new(@table_name, [:named_table, read_concurrency: true])
    {:ok, table}
  end
end
