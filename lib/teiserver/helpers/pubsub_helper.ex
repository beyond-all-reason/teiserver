defmodule Teiserver.Helpers.PubSubHelper do
  @moduledoc false
  alias Phoenix.PubSub

  @doc false
  @spec broadcast(String.t(), map()) :: :ok
  def broadcast(topic, %{event: _} = message) do
    PubSub.broadcast(
      Teiserver.PubSub,
      topic,
      Map.put(message, :topic, topic)
    )
  end

  @doc """
  Used to broadcast a message based on the successful completion of a function and then
  pass through the successful result.

  Has three main ways of calling:

    # String as topic
    insert_object()
    |> broadcast_on_ok("MyTopicString", :object, %{event: :created_object})

    # Function as topic, by default will pass in the id of the success object to the topic function
    insert_object()
    |> broadcast_on_ok(&topic_func/1, :object, %{event: :created_object})

    # Function as topic with an explicit key to pass to the topic function
    insert_object()
    |> broadcast_on_ok({&topic_func/1, :foreign_key_id}, :object, %{event: :created_object})
  """
  @spec broadcast_on_ok(
          {:ok, any} | {:error, any},
          String.t() | function() | {function(), atom()},
          atom(),
          map()
        ) :: {:ok, any()}
  def broadcast_on_ok({:ok, result}, topic, result_key, message) do
    topic_string =
      case topic do
        {topic_function, topic_key} ->
          topic_function.(Map.get(result, topic_key))

        _ ->
          if is_function(topic) do
            topic.(result.id)
          else
            topic
          end
      end

    broadcast(topic_string, Map.put(message, result_key, result))
    {:ok, result}
  end

  def broadcast_on_ok(result, _topic, _result_key, _message), do: result

  @spec subscribe(String.t()) :: :ok
  def subscribe(topic) do
    PubSub.subscribe(
      Teiserver.PubSub,
      topic
    )
  end

  @spec unsubscribe(String.t()) :: :ok
  def unsubscribe(topic) do
    PubSub.unsubscribe(
      Teiserver.PubSub,
      topic
    )
  end
end
