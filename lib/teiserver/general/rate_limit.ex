defmodule Teiserver.General.RateLimit do
  @moduledoc """
  Uses the [Hammer](https://hex.pm/packages/hammer) library to enable
  rate limiting
  """

  use Hammer, backend: :ets
end
