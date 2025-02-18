defmodule Teiserver.Helpers.BoundedQueue do
  @moduledoc """
  A thin wrapper around the queue module from the standard lib that also
  keep the queue to a maximum length
  """

  @enforce_keys [:q, :max_len, :len, :dropped?]
  defstruct [:q, :max_len, :len, :dropped?]

  @opaque t() :: t(term())
  @opaque t(item) :: %__MODULE__{
            q: :queue.queue(item),
            max_len: non_neg_integer(),
            len: non_neg_integer(),
            dropped?: boolean()
          }

  @spec new(non_neg_integer()) :: t()
  def new(max_len) do
    from_list([], max_len)
  end

  def from_list(list, max_len) do
    if max_len <= 0,
      do: raise(ArgumentError, message: "max_len must be a strictly positive integer")

    len = length(list)

    list =
      if len > max_len do
        Enum.drop(list, len - max_len)
      else
        list
      end

    %__MODULE__{
      q: :queue.from_list(list),
      max_len: max_len,
      len: len,
      dropped?: len > max_len
    }
  end

  @spec is_empty(t()) :: boolean()
  def is_empty(bq), do: bq.len == 0

  @spec len(t()) :: non_neg_integer()
  def len(bq), do: bq.len

  @doc """
  How many items can be added to this queue without spillover
  """
  @spec remaining(t()) :: non_neg_integer()
  def remaining(bq), do: bq.max_len - bq.len

  @doc """
  returns true if the last `in` caused the queue to exceed its maximum capacity
  and an item was dropped.
  Calling `out` will reset this flag
  """
  @spec dropped?(t()) :: boolean()
  def dropped?(bq), do: bq.dropped?

  @spec out(t(term())) :: {{:value, term()}, t(term())} | {:empty, t(term())}
  def out(bq) do
    case :queue.out(bq.q) do
      {{:value, val}, q2} -> {{:value, val}, %{bq | q: q2, len: bq.len - 1, dropped?: false}}
      {:empty, q2} -> {:empty, %{bq | q: q2}}
    end
  end

  @doc """
  Similar to :queue.in with a different name because `in` is a reserved keyword.
  Also swapped the arguments to work better with the |> operator
  If the addition of this message causes the length of the bounded queue to
  exceed its maximum length, the oldest item is dropped and the flag dropped?
  is set to true
  """
  @spec put(t(term()), term()) :: t(term())
  def put(bq, item) do
    q2 = :queue.in(item, bq.q)

    if bq.len == bq.max_len do
      {{:value, _}, q3} = :queue.out(q2)
      %{bq | q: q3, dropped?: true}
    else
      %{bq | q: q2, len: bq.len + 1}
    end
  end

  @spec to_list(t()) :: [term()]
  def to_list(bq), do: :queue.to_list(bq.q)

  @spec to_queue(t(term())) :: :queue.queue(term())
  def to_queue(bq), do: bq.q

  @doc """
  Set a new max length for the bounded queue.
  If the new max length is greater or equal to the length of the given queue,
  the second element of the returned tuple is empty. The flag dropped? is left untouched.

  If it is lower, the messages now in excess capacity (if any) will be removed and
  returned in their own list as the second element.
  The flag dropped? is *not* set, since the spilled messages are returned
  """
  @spec resize(t(), new_max_len :: non_neg_integer()) :: {t(), spilled_messages :: [term()]}
  def resize(bq, new_max_len) do
    if new_max_len <= 0,
      do: raise(ArgumentError, message: "max_len must be a strictly positive integer")

    if new_max_len >= bq.max_len or new_max_len >= bq.len do
      {%{bq | max_len: new_max_len}, []}
    else
      {spilled_q, rest} = :queue.split(bq.len - new_max_len, bq.q)

      {%{bq | q: rest, max_len: new_max_len, len: new_max_len, dropped?: false},
       :queue.to_list(spilled_q)}
    end
  end

  @doc """
  Split the bounded queue in two. The first contains all the elements until
  the predicate returns true (inclusive). The second contains all the remaining
  elements, or nil if the predicate didn't match anything in the queue
  This function isn't too efficient.
  """
  @spec split_when(t(), pred :: (term() -> as_boolean(term()))) :: {t(), t() | nil}
  def split_when(bq, pred) do
    l = :queue.to_list(bq.q)

    {a, b} = split_when_lists(pred, [], l)

    before = from_list(Enum.reverse(a), bq.max_len)
    rest = if b == nil, do: nil, else: from_list(b, bq.max_len)

    {before, rest}
  end

  defp split_when_lists(pred, checked_so_far, l) do
    case l do
      # got to the end of the list without finding anything
      [] ->
        {checked_so_far, nil}

      [el | rest] ->
        if pred.(el) do
          {[el | checked_so_far], rest}
        else
          split_when_lists(pred, [el | checked_so_far], rest)
        end
    end
  end
end
