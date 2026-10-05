defmodule Teiserver.Cluster.DistributedGenStatemTest do
  alias Teiserver.Support.SumStatem
  use Teiserver.DataCase

  test "basic wrapper test" do
    SumStatem.setup()
    {:ok, _pid} = SumStatem.start(:sumid, 42)

    :ok = SumStatem.add(:sumid, 1)
    :ok = SumStatem.add(:sumid, 1)
    assert 44 == SumStatem.get(:sumid)
  end
end
