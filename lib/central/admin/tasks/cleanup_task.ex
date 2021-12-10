defmodule Central.Admin.CleanupTask do
  @moduledoc false
  use Oban.Worker, queue: :cleanup

  alias Central.Account

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    # First, find and remove all expired codes
    Account.list_codes(search: [expired: true])
    |> Enum.each(fn c ->
      Account.delete_code(c)
    end)

    :ok
  end
end
