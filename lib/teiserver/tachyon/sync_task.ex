defmodule Teiserver.Tachyon.SyncTask do
  @moduledoc """
  A somewhat hackich way to run some code synchronously during the
  initialisation of the application
  """

  use GenServer, restart: :temporary

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    [m, f, a] = opts.mfa
    apply(m, f, a)
    :ignore
  end
end
