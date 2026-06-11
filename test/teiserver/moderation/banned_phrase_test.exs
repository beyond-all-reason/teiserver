defmodule Teiserver.Moderation.BannedPhraseTest do
  alias Teiserver.Moderation
  alias Teiserver.Moderation.BannedPhrase
  alias Teiserver.Moderation.LoadBannedPhrasesTask

  use Teiserver.DataCase, async: true

  import Teiserver.ModerationFixtures

  describe "banned_phrase standard utility functions" do
    @invalid_attrs %{type: nil, severity: nil, phrase: nil, score_threshold: nil}

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
        severity: "medium",
        phrase: "some phrase",
        score_threshold: 42
      }

      assert {:ok, %BannedPhrase{} = banned_phrase} = Moderation.create_banned_phrase(valid_attrs)
      assert banned_phrase.type == :raw
      assert banned_phrase.severity == :medium
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
        severity: "medium",
        phrase: "some updated phrase",
        score_threshold: 43
      }

      assert {:ok, %BannedPhrase{} = banned_phrase} =
               Moderation.update_banned_phrase(banned_phrase, update_attrs)

      assert banned_phrase.type == :raw
      assert banned_phrase.severity == :medium
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
          severity: :low,
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
          severity: :low,
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
          severity: :low,
          score_threshold: 0
        })

      assert {_msg, _opts} = Keyword.get(changeset.errors, :phrase)
    end

    test "create regex banned phrase" do
      {:ok, phrase} =
        Moderation.create_banned_phrase(%{
          phrase: "[abc]*",
          type: :regex,
          severity: :low,
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
          severity: :low,
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
    test "task loads messages in correct order" do
      banned_phrase_fixture(%{
        phrase: "low severity",
        severity: :low
      })

      banned_phrase_fixture(%{
        phrase: "low severity",
        severity: :high
      })

      banned_phrase_fixture(%{
        phrase: "low severity",
        severity: :medium
      })

      LoadBannedPhrasesTask.perform()

      [p1, p2, p3] = Moderation.list_banned_phrases_cache()
      assert p1.severity == :high
      assert p2.severity == :medium
      assert p3.severity == :low
    end
  end

  describe "message_severity" do
    setup do
      low =
        banned_phrase_fixture(%{
          phrase: "low severity",
          severity: :low,
          type: :raw
        })
        |> BannedPhrase.load_phrase()

      medium =
        banned_phrase_fixture(%{
          phrase: "medium severity",
          severity: :medium,
          type: :raw
        })
        |> BannedPhrase.load_phrase()

      high =
        banned_phrase_fixture(%{
          phrase: "high severity",
          severity: :high,
          type: :raw
        })
        |> BannedPhrase.load_phrase()

      Teiserver.cache_put(:application_metadata_cache, "banned_phrases", [high, medium, low])

      :ok
    end

    test "low phrase, check all" do
      assert BannedPhrase.message_severity("low severity", :low) == :low
    end

    test "low phrase, check high" do
      assert BannedPhrase.message_severity("low severity", :high) == nil
    end

    test "medium phrase, check all" do
      assert BannedPhrase.message_severity("medium severity", :low) == :medium
    end

    test "medium phrase, check high" do
      assert BannedPhrase.message_severity("medium severity", :high) == nil
    end

    test "high phrase, check all" do
      assert BannedPhrase.message_severity("high severity", :low) == :high
    end

    test "high phrase, check high" do
      assert BannedPhrase.message_severity("high severity", :high) == :high
    end
  end
end
