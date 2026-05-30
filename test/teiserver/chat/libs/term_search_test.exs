defmodule Teiserver.Chat.TermSearchTest do
  @moduledoc """
  Exercises the `:term` search options (case sensitive / whole word) through
  the lobby message query path. The same `TermSearch.content_filter/2` logic
  backs the room, party and direct message libs.
  """

  alias Teiserver.Chat

  use Teiserver.DataCase, async: true

  import Teiserver.AccountFixtures

  defp message(user, content) do
    {:ok, msg} =
      Chat.create_lobby_message(%{
        content: content,
        user_id: user.id,
        inserted_at: DateTime.utc_now()
      })

    msg
  end

  defp contents(search) do
    Chat.list_lobby_messages(search: search, limit: 100)
    |> Enum.map(& &1.content)
    |> Enum.sort()
  end

  setup do
    user = user_fixture()

    message(user, "the cat sat")
    message(user, "the Cat purred")
    message(user, "concatenate the list")

    {:ok, user: user}
  end

  describe "term search options" do
    test "default is case insensitive substring (back-compatible)" do
      assert contents(term: "cat") ==
               ["concatenate the list", "the Cat purred", "the cat sat"]

      # plain string term keeps working for other callers
      assert contents(term: {"cat", []}) ==
               ["concatenate the list", "the Cat purred", "the cat sat"]
    end

    test "case sensitive matches only the matching casing" do
      assert contents(term: {"Cat", case_sensitive: true}) == ["the Cat purred"]

      assert contents(term: {"cat", case_sensitive: true}) == [
               "concatenate the list",
               "the cat sat"
             ]
    end

    test "whole word excludes substrings inside larger words" do
      assert contents(term: {"cat", whole_word: true}) ==
               ["the Cat purred", "the cat sat"]
    end

    test "whole word combined with case sensitive" do
      assert contents(term: {"cat", whole_word: true, case_sensitive: true}) ==
               ["the cat sat"]
    end

    test "blank term applies no content filter" do
      assert length(contents(term: {"", case_sensitive: true, whole_word: true})) == 3
    end

    test "wildcard is preserved" do
      assert contents(term: {"con*ate", []}) == ["concatenate the list"]
    end
  end
end
