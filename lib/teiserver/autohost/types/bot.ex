defmodule Teiserver.Autohost.Types.Bot do
  @moduledoc """
  Representation of a bot for the start script given to autohost
  """
  alias Teiserver.Account.User

  @enforce_keys [:host_user_id, :name, :ai_short_name, :ai_version]
  defstruct [:host_user_id, :name, :ai_short_name, :ai_version, ai_options: %{}]

  @type t() :: %__MODULE__{
          host_user_id: User.id(),
          name: String.t(),
          ai_short_name: String.t(),
          ai_version: String.t(),
          ai_options: %{String.t() => term()}
        }
end
