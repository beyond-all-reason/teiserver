defmodule Teiserver.Monitoring.StripedPeep do
  @moduledoc """
  "Striped" storage based on `PromEx.Storage.Peep`.
  """

  @behaviour PromEx.Storage

  alias Peep.Prometheus

  @impl PromEx.Storage
  def scrape(name) do
    name
    |> Peep.get_all_metrics()
    |> Prometheus.export()
    |> IO.iodata_to_binary()
  end

  @impl PromEx.Storage
  def child_spec(name, metrics) do
    opts = [
      name: name,
      metrics: metrics,
      storage: :striped
    ]

    Peep.child_spec(opts)
  end
end
