defmodule Teiserver.OAuth.Tasks.Cleanup do
  alias Teiserver.OAuth

  use Oban.Worker, queue: :cleanup

  require Logger

  @impl Oban.Worker
  def perform(_) do
    code_count = OAuth.delete_expired_codes()
    Logger.info("Deleted #{code_count} expired oauth codes")

    token_count = OAuth.delete_expired_tokens()
    Logger.info("Deleted #{token_count} expired oauth tokens")
  end
end
