defmodule Teiserver.Tachyon do
  @moduledoc false

  defdelegate restart_system(), to: Teiserver.Tachyon.System, as: :restart
end
