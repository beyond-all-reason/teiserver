defmodule Teiserver.Tachyon do
  alias Teiserver.Tachyon.Config

  defdelegate restart_system(), to: Teiserver.Tachyon.System, as: :restart

  defdelegate setup_site_configs(), to: Config

  defdelegate enable_state_restoration(), to: Config

  defdelegate disable_state_restoration(), to: Config

  @spec should_restore_state?() :: boolean()
  defdelegate should_restore_state?(), to: Config
end
