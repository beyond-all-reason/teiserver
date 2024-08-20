defmodule Teiserver.Coordinator.WeclomeHelperTest do
  use ExUnit.Case
  alias Teiserver.Coordinator.WelcomeHelper

  test 'combine welcome message' do
    result = WelcomeHelper.combine_welcome_message([], [], [])
    assert result == []

    result = WelcomeHelper.combine_welcome_message(nil, nil, nil)
    assert result == []

    welcome_text = "Welcome Text"
    restrictions_text = "Restrictions Text"
    balance_text = "Balance Text"

    result = WelcomeHelper.combine_welcome_message(welcome_text, nil, balance_text)
    assert result == ["Welcome Text", "", "Balance Text"]

    result = WelcomeHelper.combine_welcome_message(welcome_text, restrictions_text, balance_text)
    assert result == ["Welcome Text", "", "Restrictions Text", "", "Balance Text"]
  end
end
