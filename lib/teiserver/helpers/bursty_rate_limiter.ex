defmodule Teiserver.Helpers.BurstyRateLimiter do
  @moduledoc """
  A bursty rate limiter that can grants permits that replenish over time.
  This rate limiter favours utilization, which means that even if it only
  has partially enough permit to grant a request, it will still grant it
  and delay further requests.

  `max_permits`: the maximum permits the rate limiter can store. Any request for more
  than this amount will always be denied.
  `stored_permits`: how many permits are currently available
  `replenish_interval_ms`: How many ms to replenish a permit. 1_000 would be 1 permit per second
  `last_granted_ts`: a monotonic timestamp in millisecond to track when the last request
  for permit(s) was granted

  The design is inspired from the guava SmoothRateLimiter
  https://github.com/google/guava/blob/master/guava/src/com/google/common/util/concurrent/SmoothRateLimiter.java
  but with a simplification around the utilisation function.
  """

  defstruct [:max_permits, :stored_permits, :replenish_interval_ms, :last_granted_ts]

  @type ms :: non_neg_integer()
  @type t :: %__MODULE__{
          max_permits: non_neg_integer(),
          stored_permits: number(),
          replenish_interval_ms: ms(),
          last_granted_ts: ms()
        }

  @type acquire_result ::
          {:ok, updated_rate_limiter :: t()}
          | {:error, :request_too_big}
          | {:error, wait_at_least :: ms()}

  def new(
        max_permits,
        replenish_interval_ms,
        stored_permits \\ nil,
        now \\ :erlang.monotonic_time(:millisecond)
      ) do
    if max_permits < 1,
      do:
        raise(%ArgumentError{message: "max_permit must be at least 1 per ms, got #{max_permits}"})

    stored_permits = if is_nil(stored_permits), do: max_permits, else: stored_permits

    %__MODULE__{
      max_permits: max_permits,
      stored_permits: stored_permits,
      replenish_interval_ms: replenish_interval_ms,
      last_granted_ts: now
    }
  end

  @doc """
  create a rate limiter that replenish `max_burst` permit per seconds.
  It holds `max_burst` permit in total.
  So `per_second(2)` would allow 2 requests per seconds
  """
  @spec per_second(non_neg_integer(), ms()) :: t()
  def per_second(max_burst, now \\ :erlang.monotonic_time(:millisecond)) do
    new(max_burst, 1_000 / max_burst, max_burst, now)
  end

  @doc """
  create a rate limiter that replenish `max_burst` permit per seconds.
  It holds `max_burst` permit in total.

  `per_second(1)` and `per_minute(60)` have the same replineshment rate, but
  the max_permit is higher with `per_minute`.
  """
  @spec per_minute(non_neg_integer(), ms()) :: t()
  def per_minute(max_burst, now \\ :erlang.monotonic_time(:millisecond)) do
    new(max_burst, 60_000 / max_burst, max_burst, now)
  end

  def set_full(%__MODULE__{} = rl), do: %{rl | stored_permits: rl.max_permits}
  def set_empty(%__MODULE__{} = rl), do: %{rl | stored_permits: 0}
  def with_burst(%__MODULE__{} = rl, burst), do: %{rl | max_permits: burst}

  @doc """
  Attempt to acquire `n` permits from the rate limiter.
  If `n` is greater than `rl.max_permits` then the request fails with {:error, :request_too_big}
  If there are some permits are available, the request succeed and returns the updated rate limiter
  Even if there is less than `n` permits stored, the request will still succeed to avoid
  having to wait while there is capacity in store.

  Otherwise, the rate limiter is unchanged and it returns the number of ms to wait
  until a permit is available.
  """
  @spec try_acquire(t(), non_neg_integer(), ms()) :: acquire_result()
  def try_acquire(%__MODULE__{} = rl, n \\ 1, now \\ :erlang.monotonic_time(:millisecond)) do
    if n > rl.max_permits do
      {:error, :request_too_big}
    else
      available_permits =
        min(
          rl.stored_permits + (now - rl.last_granted_ts) / rl.replenish_interval_ms,
          rl.max_permits
        )

      if available_permits > 0 do
        {:ok, %{rl | stored_permits: available_permits - n, last_granted_ts: now}}
      else
        time_to_wait_ms = (n - available_permits) * rl.replenish_interval_ms
        {:error, time_to_wait_ms}
      end
    end
  end
end
