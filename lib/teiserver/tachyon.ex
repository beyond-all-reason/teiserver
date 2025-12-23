defmodule Teiserver.Tachyon do
  defdelegate restart_system(), to: Teiserver.Tachyon.System, as: :restart
end
