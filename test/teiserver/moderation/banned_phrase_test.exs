defmodule Teiserver.Moderation.BannedPhraseTest do
  alias Teiserver.Moderation
  alias Teiserver.Moderation.BannedPhrase
  alias Teiserver.Moderation.LoadBannedPhrasesTask

  use Teiserver.DataCase, async: true

  import Teiserver.ModerationFixtures

  describe "banned_phrase standard utility functions" do
    @invalid_attrs %{type: nil, phrase: nil, score_threshold: nil}

    test "list_banned_phrases/0 returns all banned_phrases" do
      banned_phrase = banned_phrase_fixture()
      assert Moderation.list_banned_phrases() == [banned_phrase]
    end

    test "get_banned_phrase!/1 returns the banned_phrase with given id" do
      banned_phrase = banned_phrase_fixture()
      assert Moderation.get_banned_phrase!(banned_phrase.id) == banned_phrase
    end

    test "create_banned_phrase/1 with valid data creates a banned_phrase" do
      valid_attrs = %{
        type: "raw",
        phrase: "some phrase",
        score_threshold: 42
      }

      assert {:ok, %BannedPhrase{} = banned_phrase} = Moderation.create_banned_phrase(valid_attrs)
      assert banned_phrase.type == :raw
      assert banned_phrase.phrase == "some phrase"
      assert banned_phrase.score_threshold == 42
    end

    test "create_banned_phrase/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Moderation.create_banned_phrase(@invalid_attrs)
    end

    test "update_banned_phrase/2 with valid data updates the banned_phrase" do
      banned_phrase = banned_phrase_fixture()

      update_attrs = %{
        type: "raw",
        phrase: "some updated phrase",
        score_threshold: 43
      }

      assert {:ok, %BannedPhrase{} = banned_phrase} =
               Moderation.update_banned_phrase(banned_phrase, update_attrs)

      assert banned_phrase.type == :raw
      assert banned_phrase.phrase == "some updated phrase"
      assert banned_phrase.score_threshold == 43
    end

    test "update_banned_phrase/2 with invalid data returns error changeset" do
      banned_phrase = banned_phrase_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Moderation.update_banned_phrase(banned_phrase, @invalid_attrs)

      assert banned_phrase == Moderation.get_banned_phrase!(banned_phrase.id)
    end

    test "delete_banned_phrase/1 deletes the banned_phrase" do
      banned_phrase = banned_phrase_fixture()
      assert {:ok, %BannedPhrase{}} = Moderation.delete_banned_phrase(banned_phrase)
      assert_raise Ecto.NoResultsError, fn -> Moderation.get_banned_phrase!(banned_phrase.id) end
    end
  end

  describe "banned_phrase changeset validation checks" do
    test "create raw banned phrase" do
      {:ok, phrase} =
        Moderation.create_banned_phrase(%{
          phrase: "abc",
          type: :raw,
          score_threshold: 0
        })

      loaded = BannedPhrase.load_phrase(phrase)
      assert loaded.loaded_phrase
    end

    test "create fuzzy banned phrase" do
      {:ok, phrase} =
        Moderation.create_banned_phrase(%{
          phrase: "abc*",
          type: :fuzzy,
          score_threshold: 0
        })

      loaded = BannedPhrase.load_phrase(phrase)
      assert loaded.loaded_phrase
    end

    test "fuzzy banned phrase - no wildcard" do
      {:error, changeset} =
        Moderation.create_banned_phrase(%{
          phrase: "abc",
          type: :fuzzy,
          score_threshold: 0
        })

      assert {_msg, _opts} = Keyword.get(changeset.errors, :phrase)
    end

    test "create regex banned phrase" do
      {:ok, phrase} =
        Moderation.create_banned_phrase(%{
          phrase: "[abc]*",
          type: :regex,
          score_threshold: 0
        })

      loaded = BannedPhrase.load_phrase(phrase)
      assert loaded.loaded_phrase
    end

    test "regex banned phrase - bad regex" do
      {:error, changeset} =
        Moderation.create_banned_phrase(%{
          phrase: "(abc",
          type: :regex,
          score_threshold: 0
        })

      assert {_msg, _opts} = Keyword.get(changeset.errors, :phrase)
    end
  end

  describe "test banned_phrase matches" do
    test "raw" do
      phrase =
        banned_phrase_fixture(%{
          phrase: "abc",
          type: :raw
        })
        |> BannedPhrase.load_phrase()

      refute BannedPhrase.phrase_match?(phrase, "the quick brown fox")
      assert BannedPhrase.phrase_match?(phrase, "the quick Abc fox")
      assert BannedPhrase.phrase_match?(phrase, "the quick ABC fox")
      assert BannedPhrase.phrase_match?(phrase, "the quick abc fox")
      refute BannedPhrase.phrase_match?(phrase, "the quick def fox")
    end

    test "raw csv" do
      phrase =
        banned_phrase_fixture(%{
          phrase: "abc,def",
          type: :raw
        })
        |> BannedPhrase.load_phrase()

      refute BannedPhrase.phrase_match?(phrase, "the quick brown fox")
      assert BannedPhrase.phrase_match?(phrase, "the quick Abc fox")
      assert BannedPhrase.phrase_match?(phrase, "the quick ABC fox")
      assert BannedPhrase.phrase_match?(phrase, "the quick abc fox")
      assert BannedPhrase.phrase_match?(phrase, "the quick def fox")
    end

    test "fuzzy" do
      phrase =
        banned_phrase_fixture(%{
          phrase: "abc*e",
          type: :fuzzy
        })
        |> BannedPhrase.load_phrase()

      refute BannedPhrase.phrase_match?(phrase, "the quick brown fox")
      refute BannedPhrase.phrase_match?(phrase, "the quick abcdd fox")
      assert BannedPhrase.phrase_match?(phrase, "the quick abcde fox")
      assert BannedPhrase.phrase_match?(phrase, "the quick ABCDE fox")
      assert BannedPhrase.phrase_match?(phrase, "the quick abcd-de fox")
    end

    test "regex" do
      phrase =
        banned_phrase_fixture(%{
          phrase: "[abc]{3}",
          type: :regex
        })
        |> BannedPhrase.load_phrase()

      refute BannedPhrase.phrase_match?(phrase, "the quick brown fox")
      assert BannedPhrase.phrase_match?(phrase, "the quick Abc fox")
      assert BannedPhrase.phrase_match?(phrase, "the quick abc fox")
    end
  end

  describe "load task" do
    test "task loads messages" do
      banned_phrase_fixture(%{
        phrase: "Phrase 1"
      })

      banned_phrase_fixture(%{
        phrase: "Phrase 2"
      })

      banned_phrase_fixture(%{
        phrase: "Phrase 3"
      })

      LoadBannedPhrasesTask.perform()

      phrases =
        Moderation.list_banned_phrases_cache(nil)
        |> Enum.map(& &1.phrase)
        |> Enum.sort()

      assert phrases == ["Phrase 1", "Phrase 2", "Phrase 3"]
    end
  end

  describe "use_case" do
    test "use cases" do
      banned_phrase_fixture(%{
        phrase: "bad_name/chat",
        use_cases: ["username", "chat"],
        type: :raw
      })

      banned_phrase_fixture(%{
        phrase: "bad_chat",
        use_cases: ["chat"],
        type: :raw
      })

      banned_phrase_fixture(%{
        phrase: "bad_lobby",
        use_cases: ["lobby"],
        type: :raw
      })

      LoadBannedPhrasesTask.perform()

      # Correctly matches the messages
      assert BannedPhrase.message_is_banned?("bad_name/chat", "chat")
      assert BannedPhrase.message_is_banned?("bad_name/chat", "username")
      assert BannedPhrase.message_is_banned?("bad_chat", "chat")

      # Does not match the message because the usecase is wrong
      refute BannedPhrase.message_is_banned?("bad_chat", "username")
      refute BannedPhrase.message_is_banned?("bad_name/chat", "lobby")
      refute BannedPhrase.message_is_banned?("bad_chat", "lobby")

      # And we correctly handle use cases that don't exist
      refute BannedPhrase.message_is_banned?("bad_chat", "not a use case")
    end
  end
end
