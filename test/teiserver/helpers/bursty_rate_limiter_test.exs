defmodule Teiserver.Helpers.BurstyRateLimiterTest do
  use ExUnit.Case, async: true

  alias Teiserver.Helpers.BurstyRateLimiter, as: BRL

  test "must provide positive max_permits" do
    assert_raise ArgumentError, fn ->
      BRL.new(0, 1)
    end
  end

  test "per_second burst rate" do
    rl = BRL.per_second(2)
    {:error, :request_too_big} = BRL.try_acquire(rl, 3)
  end

  test "full by default" do
    {:ok, _} = BRL.per_second(2) |> BRL.try_acquire(1)
  end

  test "cannot acquire when empty" do
    now = :erlang.monotonic_time(:millisecond)
    {:error, time_to_wait} = BRL.per_second(2, now) |> BRL.set_empty() |> BRL.try_acquire(1, now)
    assert time_to_wait == 500
  end

  test "aquiring many times is the same as one big request" do
    now = :erlang.monotonic_time(:millisecond)
    rl = BRL.per_second(2, now)
    {:ok, rl2} = BRL.try_acquire(rl, 1, now)
    {:ok, rl2} = BRL.try_acquire(rl2, 1, now)
    {:ok, rl3} = BRL.try_acquire(rl, 2, now)
    assert rl2 == rl3
  end

  test "can go in the negative" do
    now = :erlang.monotonic_time(:millisecond)
    rl = BRL.per_second(1, now) |> BRL.with_burst(5)
    {:ok, rl} = BRL.try_acquire(rl, 3, now)
    # the rate limiter is at -2 permits, so in order to be able to issue one
    # full permit at a replenishment rate of 1 permit per second, need to
    # wait 3 seconds
    {:error, time_to_wait} = BRL.try_acquire(rl, 1, now)
    assert time_to_wait == 3_000
  end

  test "cannot exceed max_permits" do
    now = :erlang.monotonic_time(:millisecond)
    rl = BRL.per_second(1, now)
    # even if waiting 1s after creation, the max capacity of 1 cannot be exceeded
    {:ok, rl} = BRL.try_acquire(rl, 1, now + 1_000)
    {:error, 1_000.0} = BRL.try_acquire(rl, 1, now + 1_000)
  end

  test "correctly adjust with time" do
    now = :erlang.monotonic_time(:millisecond)
    rl = BRL.per_second(1, now)
    {:ok, rl} = BRL.try_acquire(rl, 1, now)
    {:ok, rl} = BRL.try_acquire(rl, 1, now + 300)

    # 700ms to get back to 0, then 1s to get a full permit
    expected_time = 700 + 1_000.0

    {:error, time_to_wait} = BRL.try_acquire(rl, 1, now + 300)
    assert time_to_wait == expected_time
  end
end
