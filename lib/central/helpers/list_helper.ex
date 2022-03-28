defmodule Central.Helpers.ListHelper do

  @doc """
  Given two lists will return:
    :asub - a is a subset of b
    :bsub - b is a subset of a
    :eq - a and b are equal
    :neither - neither is a subset of the other
  """
  @spec which_is_sublist(list, list) :: :asub | :bsub | :eq | :neither
  def which_is_sublist(lista, listb) do
    lista = Enum.sort(lista)
    listb = Enum.sort(listb)

    suba = lista
      |> Enum.map(fn item -> Enum.member?(listb, item) end)
      |> Enum.all?

    subb = listb
      |> Enum.map(fn item -> Enum.member?(lista, item) end)
      |> Enum.all?

    cond do
      lista == listb -> :eq
      suba -> :asub
      subb -> :bsub
      true -> :neither
    end
  end
end
