defmodule WraftDoc.Utils.MarkDownToProseMirror do
  @moduledoc """
  Module for converting Markdown to ProseMirror Node JSON using MDEx parser
  """

  @doc """
  Converts Markdown text to ProseMirror Node JSON format.

  ## Parameters
    - markdown: String containing markdown content
    - opts: Keyword list of options (optional)

  ## Examples
      iex> WraftDoc.Utils.MarkDown.to_prosemirror("# Hello\\nWorld")
      %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "heading",
            "attrs" => %{"level" => 1},
            "content" => [%{"type" => "text", "text" => "Hello"}]
          },
          %{
            "type" => "paragraph",
            "content" => [%{"type" => "text", "text" => "World"}]
          }
        ]
      }
  """
  def to_prosemirror(markdown, opts \\ []) when is_binary(markdown) do
    # Parse markdown using MDEx
    ast = MDEx.parse_document!(markdown)

    # Convert AST to ProseMirror JSON structure
    doc = %{
      "type" => "doc",
      "content" => convert_blocks(ast.nodes, opts)
    }

    doc
  end

  # Convert MDEx AST blocks to ProseMirror nodes
  defp convert_blocks(blocks, opts) do
    Enum.map(blocks, &convert_block(&1, opts))
  end

  # Convert heading block
  defp convert_block(%MDEx.Heading{level: level, nodes: content}, opts) do
    %{
      "type" => "heading",
      "attrs" => %{"level" => level},
      "content" => convert_inline(content, opts)
    }
  end

  # Convert paragraph block
  defp convert_block(%MDEx.Paragraph{nodes: content}, opts) do
    %{
      "type" => "paragraph",
      "content" => convert_inline(content, opts)
    }
  end

  # Convert code block
  defp convert_block(%MDEx.CodeBlock{info: language, literal: content}, _opts) do
    %{
      "type" => "codeBlock",
      "attrs" => %{"language" => language || ""},
      "content" => [%{"type" => "text", "text" => content}]
    }
  end

  # Convert HTML block
  defp convert_block(%MDEx.HtmlBlock{literal: content}, _opts) do
    %{
      "type" => "paragraph",
      "content" => [%{"type" => "text", "text" => content}]
    }
  end

  # Convert blockquote
  defp convert_block(%MDEx.BlockQuote{nodes: content}, opts) do
    %{
      "type" => "blockquote",
      "content" => convert_blocks(content, opts)
    }
  end

  # Convert lists
  defp convert_block(%MDEx.List{list_type: type, nodes: items}, opts) do
    %{
      "type" => "list",
      "attrs" => %{"type" => if(type == :ordered, do: "ordered", else: "bullet")},
      "content" =>
        Enum.map(items, fn item ->
          %{
            "type" => "list",
            # "type" => "listItem",
            "content" => convert_blocks(item.nodes, opts)
          }
        end)
    }
  end

  # Convert table
  defp convert_block(%MDEx.Table{nodes: rows}, opts) do
    %{
      "type" => "table",
      "content" => convert_table_rows(rows, opts)
    }
  end

  # Convert horizontal rule
  defp convert_block(%MDEx.ThematicBreak{}, _opts) do
    %{"type" => "horizontalRule"}
  end

  # Convert inline nodes to ProseMirror format
  defp convert_inline(nodes, opts) when is_list(nodes) do
    Enum.map(nodes, &convert_inline_node(&1, opts))
  end

  # Convert text node
  defp convert_inline_node(%MDEx.Text{literal: text}, _opts) do
    %{"type" => "text", "text" => text}
  end

  # Convert strong/bold text
  defp convert_inline_node(%MDEx.Strong{nodes: content}, _opts) do
    node = %{"type" => "text", "text" => get_text_content(content)}
    Map.put(node, "marks", [%{"type" => "bold"}])
  end

  # Convert emphasis/italic
  defp convert_inline_node(%MDEx.Emph{nodes: content}, _opts) do
    node = %{"type" => "text", "text" => get_text_content(content)}
    Map.put(node, "marks", [%{"type" => "italic"}])
  end

  # Convert code span
  defp convert_inline_node(%MDEx.Code{literal: content}, _opts) do
    %{
      "type" => "text",
      "text" => content,
      "marks" => [%{"type" => "code"}]
    }
  end

  # Convert link
  defp convert_inline_node(%MDEx.Link{url: url, title: title, nodes: content}, _opts) do
    %{
      "type" => "text",
      "text" => get_text_content(content),
      "marks" => [
        %{
          "type" => "link",
          "attrs" => %{"href" => url, "title" => title || ""}
        }
      ]
    }
  end

  # Convert image
  defp convert_inline_node(%MDEx.Image{url: url, title: title}, _opts) do
    %{
      "type" => "image",
      "attrs" => %{
        "src" => url,
        # "alt" => alt || "",
        "title" => title || ""
      }
    }
  end

  # Convert line break
  defp convert_inline_node(%MDEx.LineBreak{}, _opts) do
    %{"type" => "hardBreak"}
  end

  # Convert soft break
  defp convert_inline_node(%MDEx.SoftBreak{}, _opts) do
    %{"type" => "paragraph"}
  end

  # Helper to get text content from nodes
  defp get_text_content(nodes) when is_list(nodes) do
    Enum.map_join(nodes, "", fn
      %MDEx.Text{literal: text} -> text
      %MDEx.SoftBreak{} -> " "
      node -> get_text_content(node.nodes)
    end)
  end

  defp get_text_content(text), do: text

  # Table helper functions
  defp convert_table_rows(rows, opts) do
    Enum.map(rows, fn row ->
      %{
        "type" => "tableRow",
        "content" =>
          Enum.map(row.nodes, fn cell ->
            %{
              "type" => "tableCell",
              "content" => convert_blocks(cell.nodes, opts)
            }
          end)
      }
    end)
  end
end

defmodule InvalidMakdownError do
  defexception [:message]
end
