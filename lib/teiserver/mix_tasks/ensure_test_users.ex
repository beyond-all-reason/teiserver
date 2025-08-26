defmodule Mix.Tasks.Teiserver.EnsureTestUsers do
  @usage_str "Usage: `mix teiserver.ensure_test_users --host <host> <tok> <n>`\nExample: mix teiserver.ensure_test_users --host http://localhost:4000 <TOK> 10

  The token must have `admin.user` permission.
  "

  @moduledoc """
  Generate `n` random users based on predictible names.
  The goal is to end up with `n` users and access token ready to be used
  for load testing.

  #{@usage_str}
  """

  @shortdoc "blah"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    shell = Mix.shell()

    parsed =
      case parse_args(args) do
        {:ok, parsed} ->
          parsed

        {:error, err} ->
          shell.error(inspect(err))
          exit({:shutdown, 1})
      end

    HTTPoison.start()

    Task.async_stream(
      1..parsed.count,
      fn i ->
        ensure_user(i, parsed.host, parsed.token)
      end,
      max_concurrency: 20,
      ordered: false,
      timeout: :infinity
    )
    |> Enum.each(fn {:ok, res} ->
      IO.puts(Jason.encode!(res))
    end)
  end

  defp ensure_user(i, host, token) do
    url = "#{host}/teiserver/api/admin/users/refresh_token"
    user = "test_user_#{String.pad_leading(to_string(i), 7, "0")}"
    data = Jason.encode!(%{email: "#{user}@test.local"})

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{token}"}
    ]

    resp =
      HTTPoison.post!(url, data, headers)

    case resp.status_code do
      200 ->
        convert_response(resp.body)

      404 ->
        url = "#{host}/teiserver/api/admin/users/"

        data =
          Jason.encode!(%{
            name: user,
            email: "#{user}@test.local",
            password: "password",
            # roles and permissions are so confusing
            roles: ["Verified"],
            permissions: ["Verified"],
            data: %{
              roles: ["Verified"]
            }
          })

        resp = HTTPoison.post!(url, data, headers)
        200 = resp.status_code
        convert_response(resp.body)
    end
  end

  defp convert_response(body) do
    body = Jason.decode!(body)

    %{
      id: body["user"]["id"],
      name: body["user"]["name"],
      email: body["user"]["email"],
      access_token: body["credentials"]["access_token"],
      refresh_token: body["credentials"]["refresh_token"]
    }
  end

  defp parse_args(args) do
    with {parsed, _, []} <- OptionParser.parse(args, strict: [host: :string]),
         [raw_count, tok | _] <- Enum.reverse(args),
         {n, ""} <- Integer.parse(raw_count) do
      res = %{
        count: n,
        token: tok,
        host: Keyword.get(parsed, :host, "http://localhost:4000/")
      }

      {:ok, res}
    else
      {_, _, errs} -> {:error, errs}
      _ -> {:error, "Cannot parse arguments"}
    end
  end
end
