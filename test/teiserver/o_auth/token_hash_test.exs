defmodule Teiserver.OAuth.TokenHashTest do
  use Teiserver.DataCase, async: true
  alias Teiserver.OAuth.TokenHash

  describe "generate_token/0" do
    test "generates token with correct format" do
      {selector, hashed_verifier, full_token} = TokenHash.generate_token()

      assert String.length(selector) == 32
      assert String.match?(selector, ~r/^[0-9a-f]+$/)
      assert String.length(hashed_verifier) == 64
      assert String.match?(hashed_verifier, ~r/^[0-9a-f]+$/)
      assert String.starts_with?(full_token, selector <> ".")
    end

    test "generates unique tokens" do
      {selector1, _, _} = TokenHash.generate_token()
      {selector2, _, _} = TokenHash.generate_token()
      refute selector1 == selector2
    end
  end

  describe "hash_verifier/1" do
    test "returns SHA-256 hex hash" do
      hash = TokenHash.hash_verifier("test_verifier")
      assert String.length(hash) == 64
      assert String.match?(hash, ~r/^[0-9a-f]+$/)
    end

    test "is deterministic" do
      hash1 = TokenHash.hash_verifier("same_value")
      hash2 = TokenHash.hash_verifier("same_value")
      assert hash1 == hash2
    end

    test "different inputs produce different hashes" do
      hash1 = TokenHash.hash_verifier("value1")
      hash2 = TokenHash.hash_verifier("value2")
      refute hash1 == hash2
    end
  end

  describe "verify_verifier/2" do
    test "returns true for matching verifier" do
      {_selector, verifier, hashed_verifier, _full} = TokenHash.generate_token_for_test()
      assert TokenHash.verify_verifier(verifier, hashed_verifier)
    end

    test "returns false for non-matching verifier" do
      {_selector, _verifier, hashed_verifier, _full} = TokenHash.generate_token_for_test()
      refute TokenHash.verify_verifier("wrong_verifier", hashed_verifier)
    end

    test "returns false for empty verifier" do
      {_selector, _verifier, hashed_verifier, _full} = TokenHash.generate_token_for_test()
      refute TokenHash.verify_verifier("", hashed_verifier)
    end
  end

  describe "parse_token/1" do
    test "parses valid token" do
      assert {:ok, {"selector", "verifier"}} = TokenHash.parse_token("selector.verifier")
    end

    test "parses token with dots in verifier" do
      assert {:ok, {"selector", "verifier.with.dots"}} =
               TokenHash.parse_token("selector.verifier.with.dots")
    end

    test "returns error for token without dot" do
      assert :error = TokenHash.parse_token("nodot")
    end

    test "returns error for empty selector" do
      assert :error = TokenHash.parse_token(".verifier")
    end

    test "returns error for empty verifier" do
      assert :error = TokenHash.parse_token("selector.")
    end

    test "returns error for nil" do
      assert :error = TokenHash.parse_token(nil)
    end

    test "returns error for non-string" do
      assert :error = TokenHash.parse_token(123)
    end
  end
end
