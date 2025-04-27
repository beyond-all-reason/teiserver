defmodule Teiserver.Helpers.MonitorCollection do
  @moduledoc """
  An opaque collection of monitor references with keys attached to them
  """

  alias Teiserver.Helpers.Bimap

  @opaque t :: Bimap.t()

  @spec new() :: t()
  def new(), do: Bimap.new()

  @doc """
  Start monitoring the given pid from the calling process. Same as
  `Process.Monitor`.
  Store the returned reference with the given value and return the updated
  collection
  """
  @spec monitor(t(), pid(), term()) :: t()
  def monitor(mc, pid, val) do
    ref = Process.monitor(pid)
    Bimap.put(mc, ref, val, nil)
  end

  @doc """
  Similar to `Process.demonitor` but uses the value associated with the reference.
  Has no effect if there is no reference for the given value, otherwise
  removes the ref and the value from the collection
  """
  @spec demonitor_by_val(t(), term(), options :: [:flush | :info]) :: t()
  def demonitor_by_val(mc, val, opts \\ []) do
    case Bimap.get_other_key(mc, val) do
      nil ->
        mc

      ref ->
        Process.demonitor(ref, opts)
        Bimap.delete(mc, ref)
    end
  end

  @doc """
  Return the stored reference for the given value
  """
  @spec get_ref(t(), term()) :: reference() | nil
  def get_ref(mc, v), do: Bimap.get_other_key(mc, v)

  @doc """
  Return the stored reference for the given reference
  """
  @spec get_val(t(), reference()) :: term()
  def get_val(mc, r), do: Bimap.get_other_key(mc, r)

  @doc """
  update the value without touching the associated reference. Raises if
  `old_val` is not in the collection
  """
  def replace_val!(mc, old_val, new_val) do
    case Bimap.get_other_key(mc, old_val) do
      nil -> raise "key to replace not found"
      ref -> Bimap.put(mc, ref, new_val, nil)
    end
  end
end
