defmodule Teiserver.Moderation.ActionLibTest do
  alias Teiserver.Account.User
  alias Teiserver.Helper.DateHelper
  alias Teiserver.Moderation.Action
  alias Teiserver.Moderation.ActionLib

  use ExUnit.Case, async: true

  describe "format_reason_for_coordinator/1" do
    test "keeps multiline reasons in a single message line" do
      for newline <- ["\n", "\r\n", "\r", "\u0085", "\u2028", "\u2029", "\n\n"] do
        reason =
          "CoC A1 - Respect is mandatory.#{newline}CoC B5 - Do not provide advice as a spectator."

        assert ActionLib.format_reason_for_coordinator(reason) ==
                 "CoC A1 - Respect is mandatory. CoC B5 - Do not provide advice as a spectator."
      end
    end

    test "preserves non-ASCII characters while replacing newlines" do
      reason = "Polish: \u0105\nCyrillic: \u0445"
      result = ActionLib.format_reason_for_coordinator(reason)

      assert result == "Polish: \u0105 Cyrillic: \u0445"
      assert String.valid?(result)
    end

    test "leaves single-line reasons unchanged" do
      for reason <- ["Please follow the rules", "Polish: \u0105, Cyrillic: \u0445", ""] do
        assert ActionLib.format_reason_for_coordinator(reason) == reason
      end
    end
  end

  describe "generate_discord_message_text/1" do
    test "warnings omit expiry information" do
      for expires <- [~N[2026-10-24 12:00:00], nil] do
        action = %Action{
          target: %User{name: "Test user"},
          reason: "Please follow the rules",
          restrictions: ["Warning reminder"],
          expires: expires
        }

        assert ActionLib.generate_discord_message_text(action) ==
                 Enum.join(
                   [
                     "--------------------------------------------",
                     "`Test user` has been moderated.",
                     "**Reason:** Please follow the rules",
                     "**Restriction:** Warning reminder"
                   ],
                   "\n"
                 )
      end
    end

    test "temporary restrictions retain their expiry" do
      for restrictions <- [
            ["All chat"],
            ["Login"],
            ["Warning reminder", "All chat"],
            ["Login", "Warning reminder"]
          ] do
        action = %Action{
          target: %User{name: "Test user"},
          reason: "Please follow the rules",
          restrictions: restrictions,
          expires: ~N[2026-10-24 12:00:00]
        }

        message = ActionLib.generate_discord_message_text(action)

        assert message =~ "**Until:** " <> DateHelper.date_to_discord_str(action.expires)
        refute message =~ "**Permanent**"
      end
    end

    test "permanent restrictions retain their duration label" do
      for restrictions <- [["Login"], ["Warning reminder", "Login"]] do
        action = %Action{
          target: %User{name: "Test user"},
          reason: "Please follow the rules",
          restrictions: restrictions,
          expires: nil
        }

        message = ActionLib.generate_discord_message_text(action)

        assert message =~ "**Permanent**"
        refute message =~ "**Until:**"
      end
    end
  end
end
