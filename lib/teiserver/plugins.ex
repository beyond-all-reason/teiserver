defmodule Teiserver.Plugins do
  @moduledoc false

  alias Decorator.Decorate.Context

  use Decorator.Define, plugin: 1

  @doc """
  Looks for a plugin implementation for the given key and calls it with the
  provided options. If no plugin is found, it calls the existing function.
  """
  def plugin(key, body, context) do
    %Context{args: args} = context

    quote do
      f =
        :teiserver
        |> Application.get_env(Teiserver.Plugins, [])
        |> Keyword.get(unquote(key))

      case f do
        nil ->
          unquote(body)

        plugin_function ->
          # Normally Credo has an issue with this but it's intentional to do it this way
          # credo:disable-for-next-line
          plugin_function.(unquote_splicing(args))
      end
    end
  end
end
