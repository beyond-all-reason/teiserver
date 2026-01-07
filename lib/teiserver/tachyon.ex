defmodule Teiserver.Tachyon do
  alias Teiserver.Tachyon.Config

  defdelegate restart_system(), to: Teiserver.Tachyon.System, as: :restart

  defdelegate setup_site_configs(), to: Config

  defdelegate enable_state_restoration(), to: Config

  defdelegate disable_state_restoration(), to: Config

  @spec should_restore_state?() :: boolean()
  defdelegate should_restore_state?(), to: Config

  @spec get_restoration_timeout() :: non_neg_integer()
  defdelegate get_restoration_timeout(), to: Config

  @spec set_restoration_timeout(non_neg_integer()) :: :ok
  defdelegate set_restoration_timeout(t), to: Config

  @spec reset_restoration_timeout() :: :ok
  defdelegate reset_restoration_timeout(), to: Config
end
