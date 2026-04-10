defmodule Teiserver.Plugins do
  @moduledoc false

  @doc """
  Looks for a plugin implementation for the given key and calls it with the
  provided options. If no plugin is found, it calls the fallback function.
  """
  @spec call_plugin(atom, map(), function()) :: any()
  def call_plugin(key, opts, fallback) do
    plugins = Application.get_env(:teiserver, Teiserver.Plugins, [])

    case Keyword.get(plugins, key) do
      nil ->
        fallback.()

      plugin_function ->
        plugin_function.(opts)
    end
  end
end
