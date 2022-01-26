defmodule Teiserver.Chat.WordLibTest do
  use Central.DataCase
  alias Teiserver.Chat.WordLib

  test "bad words" do
    assert WordLib.flagged_words("") == 0
    assert WordLib.flagged_words("beherith smells funny") == 0
    assert WordLib.flagged_words("nigger cunty") == 2
    assert WordLib.flagged_words("he is a tard") == 1
    assert WordLib.flagged_words("he is a r3tard") == 1
    assert WordLib.flagged_words("he is a agtard") == 0
  end
end
