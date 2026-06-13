defmodule Teiserver.Tachyon.SchemaTest do
  alias Teiserver.Tachyon.Schema
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
end
