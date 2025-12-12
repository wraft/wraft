defmodule WraftDoc.TokenEngineTest do
  use ExUnit.Case
  alias WraftDoc.TokenEngine

  describe "Markdown Adapter" do
    test "replaces SMART_TABLE token" do
      input = "Here is a table: [SMART_TABLE:id=1]"
      output = TokenEngine.replace(input, :markdown)

      assert output == "Here is a table: "
    end

    test "replaces SIGNATURE_FIELD token" do
      input = "Sign here: [SIGNATURE_FIELD:width=300 height=150]"
      output = TokenEngine.replace(input, :markdown)

      assert output =~ "[SIGNATURE_FIELD width=200 height=100]"
    end

    test "ignores unknown tokens" do
      input = "Unknown: [UNKNOWN_TOKEN:foo=bar]"
      output = TokenEngine.replace(input, :markdown)

      assert output == input
    end
  end

  describe "ProseMirror Adapter" do
    test "replaces smartTableWrapper node" do
      input = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "smartTableWrapper",
            "attrs" => %{"tableName" => "test-table"},
            "content" => []
          }
        ]
      }

      output = TokenEngine.replace(input, :prosemirror)

      table_node = List.first(output["content"])
      assert table_node["type"] == "smartTableWrapper"
      assert Enum.empty?(table_node["content"])
    end

    test "replaces signature node" do
      input = %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "signature",
            "attrs" => %{"width" => "300", "height" => "150"}
          }
        ]
      }

      output = TokenEngine.replace(input, :prosemirror)

      signature_node = List.first(output["content"])
      assert signature_node["type"] == "signature"
      assert signature_node["attrs"]["width"] == "300"
    end
  end
end
