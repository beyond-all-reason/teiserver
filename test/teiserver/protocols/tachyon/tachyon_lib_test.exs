defmodule Teiserver.Protocols.TachyonLibTest do
  use Central.ServerCase, async: true
  alias Teiserver.Protocols.TachyonLib

  test "get_modules" do
    # Basically we just want to test it returns stuff in the right format
    assert match?({_, _}, TachyonLib.get_modules())
    assert match?({_, _}, TachyonLib.get_modules("dev"))
    assert match?({_, _}, TachyonLib.get_modules("v1"))
  end

  test "format_log" do
    assert TachyonLib.format_log([1,2,3]) == "[1, 2, 3]"
    assert TachyonLib.format_log(%{key: "value"}) == "%{key: \"value\"}"
  end

  test "encode decode" do
    data = %{"key" => "value", "lkey" => [1,2,3]}
    r = TachyonLib.encode(data)

    assert {:ok, data} == TachyonLib.decode(r)
    assert data == TachyonLib.decode!(r)

    assert {:ok, nil} == TachyonLib.decode(:timeout)
    assert {:ok, nil} == TachyonLib.decode("")
    assert {:error, :base64_decode} == TachyonLib.decode("invalid base64")
    assert {:error, :gzip_decompress} == TachyonLib.decode("YSA9IDE=")

    assert_raise RuntimeError, fn -> TachyonLib.decode!("invalid base64") end
    assert_raise RuntimeError, fn -> TachyonLib.decode!("YSA9IDE=") end
  end
end
