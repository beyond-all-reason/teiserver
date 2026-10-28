defmodule Teiserver.Party.Types.Aggregate do
  @moduledoc """
  An aggregate used when processing events related to parties
  """

  alias Teiserver.Party.Types, as: PT

  @enforce_keys [:data]
  defstruct [:data, side_effects: [], actions: []]

  @type t() :: %__MODULE__{
          data: PT.Data.t(),
          side_effects: list(),
          actions: list(:gen_statem.action())
        }

  @doc """
  helper to add nested data in the aggregate, similar to `Kernel.put_in/3`
  """
  def put_in_data(aggregate, keys, datum) do
    put_in(aggregate, [Access.key!(:data)] ++ keys, datum)
  end

  @doc """
  helper to modify data in the aggregate, similar to `Kernel.update_in/3`
  """
  def update_in_data(aggregate, keys, fun) do
    update_in(aggregate.data, fn data ->
      update_in(data, keys, fun)
    end)
  end

  @doc """
  helper to append a new side effect to the aggregate
  """
  @spec add_side_effect(t(), term()) :: t()
  def add_side_effect(aggregate, effect) do
    update_in(aggregate, [Access.key!(:side_effects)], fn side_effects ->
      side_effects ++ [effect]
    end)
  end

  @doc """
  helper to append a new action to the aggregate
  """
  @spec add_side_action(t(), :gen_statem.action()) :: t()
  def add_side_action(aggregate, action) do
    update_in(aggregate, [Access.key!(:actions)], fn actions ->
      actions ++ [action]
    end)
  end
end
