defmodule Teiserver.Tachyon.SchemaTest do
  alias Teiserver.Tachyon.Schema
  alias TeiserverWeb.Tachyon.Versioning

  use ExUnit.Case

  describe "parse_envelope" do
    test "correct object" do
      obj = %{
        "messageId" => "123",
        "type" => "request",
        "commandId" => "ns/cmd"
      }

      {:ok, "ns/cmd", "request", "123"} = Schema.parse_envelope(obj)
    end

    test "correct object with data" do
      obj = %{
        "messageId" => "123",
        "type" => "request",
        "commandId" => "ns/cmd",
        "data" => %{"foo" => "bar"}
      }

      {:ok, "ns/cmd", "request", "123"} = Schema.parse_envelope(obj)
    end

    test "must pass an object" do
      {:error, _msg} = Schema.parse_envelope("not an object")
      {:error, _msg} = Schema.parse_envelope(["also", "not", "an", "object"])
      {:error, _msg} = Schema.parse_envelope(2)
    end

    test "messageId required" do
      obj = %{"type" => "request", "commandId" => "ns/cmd"}
      {:error, _msg} = Schema.parse_envelope(obj)
    end

    test "messageId must be a string" do
      obj = %{"type" => "request", "commandId" => "ns/cmd", "messageId" => 2}
      {:error, _msg} = Schema.parse_envelope(obj)
    end

    test "type required" do
      obj = %{"commandId" => "ns/cmd", "messageId" => "123"}
      {:error, _msg} = Schema.parse_envelope(obj)
    end

    test "type must be a string" do
      obj = %{"type" => 123, "commandId" => "ns/cmd", "messageId" => "123"}
      {:error, _msg} = Schema.parse_envelope(obj)
    end

    test "type must be one of event/request/response" do
      obj = %{"type" => "wat?", "commandId" => "ns/cmd", "messageId" => "123"}
      {:error, _msg} = Schema.parse_envelope(obj)
    end

    test "commandId required" do
      obj = %{"type" => "request", "messageId" => "123"}
      {:error, _msg} = Schema.parse_envelope(obj)
    end

    test "commandId must be a string" do
      obj = %{"type" => "request", "commandId" => 123, "messageId" => "123"}
      {:error, _msg} = Schema.parse_envelope(obj)
    end
  end

  describe "parse_message" do
    # Test only version in priv/tachyon/v999/schema
    @test_major_version 999

    test "versioning" do
      # testId is only defined in the test version
      assert :ok =
               Schema.parse_message(
                 @test_major_version,
                 "user/info",
                 "request",
                 user_info_request(%{"testId" => "1"})
               )

      # There is no userId in test version
      assert {:error, %JSV.ValidationError{}} =
               Schema.parse_message(
                 @test_major_version,
                 "user/info",
                 "request",
                 user_info_request(%{"userId" => "1"})
               )

      latest_major_version = Versioning.server_supported_versions() |> List.last()

      # Last major version still supports userId but not testId
      assert :ok =
               Schema.parse_message(
                 latest_major_version,
                 "user/info",
                 "request",
                 user_info_request(%{"userId" => "1"})
               )

      assert {:error, %JSV.ValidationError{}} =
               Schema.parse_message(
                 latest_major_version,
                 "user/info",
                 "request",
                 user_info_request(%{"testId" => "1"})
               )
    end
  end

  defp user_info_request(data) do
    %{
      "type" => "request",
      "messageId" => "123",
      "commandId" => "user/info",
      "data" => data
    }
  end
end
