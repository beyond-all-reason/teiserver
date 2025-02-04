defmodule Mix.Tasks.Teiserver.GenToken do
  @usage_str "Usage: `mix teiserver.gen_token --user <username/email> [--app <app_uid>]`"

  @moduledoc """
  Creates an oauth token for the given username or email.
  This is a convenience task to help developping anything requiring an
  oauth token like tachyon.

  #{@usage_str}
  """

  @shortdoc "generate an oauth token for testing"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    shell = Mix.shell()
    shell.info("raw args: #{inspect(args)}")
    {parsed, _, _errors} = OptionParser.parse(args, strict: [user: :string, app: :string])
    shell.info("parsed args: #{inspect(parsed)}")

    Application.ensure_all_started([:ecto, :ecto_sql, :tzdata])
    Teiserver.Repo.start_link()

    case parsed[:user] do
      nil ->
        shell.error("Missing username or email. #{@usage_str}")
        exit({:shutdown, 1})

      user ->
        case Teiserver.OAuth.Tasks.GenToken.create_token(user, parsed[:app]) do
          {:ok, token} ->
            shell.info("Generated token (id=#{token.id}) - #{token.value}")
            :ok

          {:error, msg} ->
            shell.error("#{msg} -- #{@usage_str}")
            exit({:shutdown, 1})
        end
    end
  end
end
