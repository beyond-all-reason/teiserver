defmodule Teiserver.IpCheck.IpInfo do
  @moduledoc """
  Various data about IP, obtained through 3rd party API
  """

  defstruct abuser?: false,
            bogon?: false,
            crawler?: false,
            datacenter?: false,
            proxy?: false,
            tor?: false,
            vpn?: false

  @type t() :: %__MODULE__{
          abuser?: boolean(),
          bogon?: boolean(),
          crawler?: boolean(),
          datacenter?: boolean(),
          proxy?: boolean(),
          tor?: boolean(),
          vpn?: boolean()
        }
end
