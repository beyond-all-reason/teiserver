defmodule Teiserver.Monitoring.BucketsTest do
  use Teiserver.DataCase, async: true

  alias Teiserver.Monitoring.Buckets
  alias Telemetry.Metrics.Distribution

  test "return correct bucket for ints" do
    config = Buckets.config(%Distribution{reporter_options: [buckets: [1, 2, 3]]})
    assert 0 == Buckets.bucket_for(0, config)
    assert 3 == Buckets.bucket_for(100, config)
  end

  test "return correct bucket for floats" do
    config = Buckets.config(%Distribution{reporter_options: [buckets: [1, 2, 3]]})
    assert 0 == Buckets.bucket_for(0.8, config)
    assert 1 == Buckets.bucket_for(1.1, config)
    assert 3 == Buckets.bucket_for(100, config)
  end

  test "upper bound is inclusive" do
    config = Buckets.config(%Distribution{reporter_options: [buckets: [1, 2, 3]]})
    assert 0 == Buckets.bucket_for(1, config)
  end

  test "return upper bound as float" do
    config = Buckets.config(%Distribution{reporter_options: [buckets: [1, 2, 3]]})
    assert Buckets.upper_bound(0, config) == "1.0"
    assert Buckets.upper_bound(1, config) == "2.0"
    assert Buckets.upper_bound(2, config) == "3.0"
  end

  test "+Inf upper bound for excess bucket index" do
    config = Buckets.config(%Distribution{reporter_options: [buckets: [1, 2, 3]]})
    assert Buckets.upper_bound(3, config) == "+Inf"
  end
end
