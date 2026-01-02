# Taken from https://gitlab.com/code-stats/code-stats/-/blob/b1cf53462a3fa34369eaa06494754c7ae38aed2a/lib/code_stats/config_helpers.ex
defmodule Teiserver.ConfigHelpers do
  @type config_type :: :str | :int | :bool | :json

  @doc """
  Get value from environment variable, converting it to the given type if needed.

  If no default value is given, or `:no_default` is given as the default, an error is raised if the variable is not
  set.
  """
  @spec get_env(String.t(), :no_default | any(), config_type()) :: any()
  def get_env(var, default \\ :no_default, type \\ :str)

  def get_env(var, :no_default, type) do
    System.fetch_env!(var)
    |> get_with_type(type)
  end

  def get_env(var, default, type) do
    # credo:disable-for-next-line Credo.Check.Readability.WithSingleClause
    with {:ok, val} <- System.fetch_env(var) do
      get_with_type(val, type)
    else
      :error -> default
    end
  end

  @spec get_with_type(String.t(), config_type()) :: any()
  defp get_with_type(val, type)

  defp get_with_type(val, :str), do: val
  defp get_with_type(val, :int), do: String.to_integer(val)
  defp get_with_type("true", :bool), do: true
  defp get_with_type("false", :bool), do: false
  defp get_with_type(val, :json), do: Jason.decode!(val)
  defp get_with_type(val, type), do: raise("Cannot convert to #{inspect(type)}: #{inspect(val)}")
end
