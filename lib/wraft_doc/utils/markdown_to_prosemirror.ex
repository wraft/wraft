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
    ast =
      MDEx.parse_document!(markdown,
        extension: [
          strikethrough: true,
          table: true,
          shortcodes: true,
          footnotes: true,
          autolink: true,
          tagfilter: true,
          tasklists: true
        ],
        parse: [
          smart: true,
          relaxed_tasklist_matching: true,
          relaxed_autolinks: true
        ],
        render: [
          github_pre_lang: true,
          escape: true
        ]
      )

    # Convert AST to ProseMirror JSON structure
    doc = %{
      "type" => "doc",
      "content" => convert_blocks(ast.nodes, opts)
    }

    # Completely remove any blockquotes from the document structure
    doc = filter_blockquotes(doc)

    doc
  end

  # Filter out any blockquotes and convert them to paragraphs
  defp filter_blockquotes(doc) do
    new_content = filter_blockquotes_content(doc["content"])
    Map.put(doc, "content", new_content)
  end

  # Process content to replace any blockquotes with their inner content
  defp filter_blockquotes_content(content) when is_list(content) do
    Enum.flat_map(content, fn node ->
      case node do
        # If we encounter a blockquote, extract its content
        %{"type" => "blockquote", "content" => blockquote_content} ->
          # Extract the blockquote content
          filter_blockquotes_content(blockquote_content)

        # Handle nodes with content recursively
        %{"content" => node_content} = node when is_list(node_content) ->
          [%{node | "content" => filter_blockquotes_content(node_content)}]

        # Return other nodes unchanged
        node ->
          [node]
      end
    end)
  end

  # Handle the case where content is not a list
  defp filter_blockquotes_content(content), do: content

  # Convert MDEx AST blocks to ProseMirror nodes
  defp convert_blocks(blocks, opts) do
    Enum.map(blocks, &convert_block(&1, opts))
  end

  # Convert heading blocks
  defp convert_block({"h" <> level_str, _attrs, content, _meta}, opts)
       when level_str in ["1", "2", "3", "4", "5", "6"] do
    level = String.to_integer(level_str)

    %{
      "type" => "heading",
      "attrs" => %{"level" => level},
      "content" => convert_inline(content, opts)
    }
  end

  # Convert paragraph blocks
  defp convert_block({"p", _attrs, content, _meta}, opts) do
    %{
      "type" => "paragraph",
      "content" => convert_inline(content, opts)
    }
  end

  # Convert code blocks
  defp convert_block(
         {"pre", _pre_attrs, [{"code", code_attrs, [content], _code_meta}], _pre_meta},
         _opts
       ) do
    language = get_language_from_attrs(code_attrs)

    %{
      "type" => "codeBlock",
      "attrs" => %{"language" => language || ""},
      "content" => [%{"type" => "text", "text" => content}]
    }
  end

  # Convert blockquote
  defp convert_block({"blockquote", _attrs, content, _meta}, opts) do
    # Instead of creating a blockquote, create a regular paragraph
    %{
      "type" => "paragraph",
      "content" => convert_inline(content, opts)
    }
  end

  # Convert unordered list
  defp convert_block({"ul", _attrs, items, _meta}, opts) do
    %{
      "type" => "list",
      "attrs" => %{"type" => "bullet"},
      "content" => Enum.map(items, fn item -> convert_list_item(item, opts) end)
    }
  end

  # Convert ordered list
  defp convert_block({"ol", _attrs, items, _meta}, opts) do
    %{
      "type" => "list",
      "attrs" => %{"type" => "ordered"},
      "content" => Enum.map(items, fn item -> convert_list_item(item, opts) end)
    }
  end

  # Convert table
  defp convert_block({"table", _table_attrs, table_content, _table_meta}, opts) do
    %{
      "type" => "table",
      "attrs" => %{
        "columnWidths" => nil,
        "cellMinWidth" => 100,
        "resizable" => true
      },
      "content" => convert_table_rows(table_content, opts)
    }
  end

  # Convert horizontal rule
  defp convert_block({"hr", _attrs, _content, _meta}, _opts) do
    %{"type" => "horizontalRule"}
  end

  # Handle HTML blocks
  defp convert_block({"div", _attrs, content, _meta}, opts) do
    %{
      "type" => "paragraph",
      "content" => convert_inline(content, opts)
    }
  end

  # Handle MDEx.Paragraph struct
  defp convert_block(%MDEx.Paragraph{nodes: content}, opts) do
    %{
      "type" => "paragraph",
      "content" => Enum.map(content, &convert_mdex_node(&1, opts))
    }
  end

  # Handle MDEx.Heading struct
  defp convert_block(%MDEx.Heading{level: level, nodes: content}, opts) do
    %{
      "type" => "heading",
      "attrs" => %{"level" => level},
      "content" => Enum.map(content, &convert_mdex_node(&1, opts))
    }
  end

  # Handle MDEx.List struct (bullet/unordered)
  defp convert_block(%MDEx.List{list_type: :bullet, nodes: items}, opts) do
    %{
      "type" => "list",
      "attrs" => %{"type" => "bullet"},
      "content" => Enum.map(items, &convert_mdex_list_item(&1, opts))
    }
  end

  # Handle MDEx.List struct (ordered)
  defp convert_block(%MDEx.List{list_type: :ordered, nodes: items}, opts) do
    %{
      "type" => "list",
      "attrs" => %{"type" => "ordered"},
      "content" => Enum.map(items, &convert_mdex_list_item(&1, opts))
    }
  end

  # Handle MDEx.CodeBlock struct
  defp convert_block(%MDEx.CodeBlock{info: language, literal: content}, _opts) do
    %{
      "type" => "codeBlock",
      "attrs" => %{"language" => language || ""},
      "content" => [%{"type" => "text", "text" => content}]
    }
  end

  # Handle MDEx.BlockQuote struct
  defp convert_block(%MDEx.BlockQuote{nodes: content}, opts) do
    # Instead of creating a blockquote node, convert content to paragraphs
    # Extract the content and convert each node separately
    converted_content = Enum.map(content, &convert_block(&1, opts))

    # If there's only one node, return it directly
    if length(converted_content) == 1 do
      hd(converted_content)
    else
      # If multiple nodes, create a paragraph container
      %{
        "type" => "paragraph",
        "content" =>
          Enum.flat_map(converted_content, fn node ->
            case node do
              %{"type" => "paragraph", "content" => para_content} -> para_content
              other -> [other]
            end
          end)
      }
    end
  end

  # Handle MDEx.ThematicBreak struct (horizontal rule)
  defp convert_block(%MDEx.ThematicBreak{}, _opts) do
    %{"type" => "horizontalRule"}
  end

  # Handle MDEx.HtmlBlock struct
  defp convert_block(%MDEx.HtmlBlock{literal: content}, opts) do
    # Remove any blockquote tags first
    content_without_blockquotes =
      String.replace(content, ~r/<blockquote>(.*?)<\/blockquote>/si, "\\1")

    # Try to identify common HTML structures
    cond do
      # Check if this is a table block (simplified detection)
      String.contains?(content_without_blockquotes, "<table") &&
          String.contains?(content_without_blockquotes, "</table>") ->
        # Try to parse the table
        try do
          parse_html_table(content_without_blockquotes, opts)
        rescue
          _ ->
            # Fallback to text extraction if parsing fails
            %{
              "type" => "paragraph",
              "content" => [
                %{
                  "type" => "text",
                  "text" => extract_text_from_html(content_without_blockquotes)
                }
              ]
            }
        end

      # Check for div with alignment
      String.match?(
        content_without_blockquotes,
        ~r/<div\s+style="text-align:\s*(left|center|right|justify)/
      ) ->
        align_match =
          Regex.run(~r/text-align:\s*(left|center|right|justify)/, content_without_blockquotes)

        alignment = if align_match, do: Enum.at(align_match, 1, "left"), else: "left"

        %{
          "type" => "paragraph",
          "attrs" => %{"alignment" => alignment},
          "content" => [
            %{
              "type" => "text",
              "text" => extract_text_from_html(content_without_blockquotes)
            }
          ]
        }

      true ->
        # Default HTML block handling - just extract text
        %{
          "type" => "paragraph",
          "content" => [
            %{
              "type" => "text",
              "text" => extract_text_from_html(content_without_blockquotes)
            }
          ]
        }
    end
  end

  # Handle MDEx.Table struct directly
  defp convert_block(%MDEx.Table{nodes: rows, alignments: alignments}, opts) do
    %{
      "type" => "table",
      "attrs" => %{
        "columnWidths" => nil,
        "cellMinWidth" => 100,
        "resizable" => true
      },
      "content" => Enum.map(rows, fn row -> convert_table_row(row, alignments, opts) end)
    }
  end

  # Helper to extract language from code block attributes
  defp get_language_from_attrs(attrs) do
    class = attrs |> Enum.find(fn {key, _} -> key == "class" end)

    if class do
      {_, class_value} = class

      if String.starts_with?(class_value, "language-") do
        String.replace_prefix(class_value, "language-", "")
      else
        nil
      end
    else
      nil
    end
  end

  # Convert list items
  defp convert_list_item({"li", _attrs, content, _meta}, opts) do
    %{
      "type" => "listItem",
      "content" => convert_blocks(content, opts)
    }
  end

  # Convert table rows
  defp convert_table_rows(rows, opts) do
    Enum.map(rows, fn
      {"thead", _thead_attrs, thead_content, _thead_meta} ->
        convert_table_rows(thead_content, opts)

      {"tbody", _tbody_attrs, tbody_content, _tbody_meta} ->
        convert_table_rows(tbody_content, opts)

      {"tr", _tr_attrs, tr_content, _tr_meta} ->
        %{
          "type" => "tableRow",
          "content" => Enum.map(tr_content, &convert_table_cell(&1, opts))
        }

      _ ->
        []
    end)
    |> List.flatten()
  end

  # Convert table cells
  defp convert_table_cell({"th", _th_attrs, th_content, _th_meta}, opts) do
    %{
      "type" => "tableCell",
      "attrs" => %{
        "colspan" => 1,
        "rowspan" => 1,
        "alignment" => nil
      },
      "content" => convert_blocks(th_content, opts)
    }
  end

  defp convert_table_cell({"td", _td_attrs, td_content, _td_meta}, opts) do
    %{
      "type" => "tableCell",
      "attrs" => %{
        "colspan" => 1,
        "rowspan" => 1,
        "alignment" => nil
      },
      "content" => convert_blocks(td_content, opts)
    }
  end

  # Handle MDEx.ListItem struct
  defp convert_mdex_list_item(%MDEx.ListItem{nodes: content}, opts) do
    %{
      "type" => "listItem",
      "content" => Enum.map(content, &convert_block(&1, opts))
    }
  end

  # Convert MDEx.TableRow to ProseMirror tableRow
  defp convert_table_row(%MDEx.TableRow{nodes: cells}, alignments, opts) do
    %{
      "type" => "tableRow",
      "content" =>
        Enum.with_index(cells)
        |> Enum.map(fn {cell, index} ->
          alignment = Enum.at(alignments, index, :none)
          convert_table_cell(cell, alignment, opts)
        end)
    }
  end

  # Convert MDEx.TableCell to ProseMirror tableCell
  defp convert_table_cell(%MDEx.TableCell{nodes: content}, alignment, opts) do
    align_value =
      case alignment do
        :left -> "left"
        :center -> "center"
        :right -> "right"
        _ -> nil
      end

    %{
      "type" => "tableCell",
      "attrs" => %{
        "colspan" => 1,
        "rowspan" => 1,
        "alignment" => align_value
      },
      "content" => content |> Enum.map(&convert_mdex_node(&1, opts)) |> maybe_wrap_in_paragraph()
    }
  end

  # Helper to parse HTML tables into ProseMirror table structures
  defp parse_html_table(html_table, opts) do
    # This is a simplified parser - a real application might use a proper HTML parser like Floki

    # Extract table rows using regex
    thead_regex = ~r/<thead>(.*?)<\/thead>/s
    tbody_regex = ~r/<tbody>(.*?)<\/tbody>/s
    tr_regex = ~r/<tr>(.*?)<\/tr>/s

    # Extract thead content
    thead_content =
      case Regex.run(thead_regex, html_table) do
        [_, thead] -> thead
        _ -> ""
      end

    # Extract tbody content
    tbody_content =
      case Regex.run(tbody_regex, html_table) do
        [_, tbody] -> tbody
        _ -> ""
      end

    # If no tbody, try to parse the whole table
    table_content =
      if thead_content == "" && tbody_content == "" do
        html_table
      else
        thead_content <> tbody_content
      end

    # Extract rows
    rows =
      Regex.scan(tr_regex, table_content)
      |> Enum.map(fn [_, row] -> parse_table_row(row, opts) end)

    # Create ProseMirror table
    %{
      "type" => "table",
      "attrs" => %{
        "columnWidths" => nil,
        "cellMinWidth" => 100,
        "resizable" => true
      },
      "content" => rows
    }
  end

  # Parse a table row from HTML
  defp parse_table_row(row_html, opts) do
    # Extract cells using regex
    th_regex = ~r/<th(?:\s+[^>]*)?>(.*?)<\/th>/s
    td_regex = ~r/<td(?:\s+[^>]*)?>(.*?)<\/td>/s

    # Extract all th and td cells
    th_cells =
      Regex.scan(th_regex, row_html)
      |> Enum.map(fn [_, content] -> parse_table_cell(content, opts, true) end)

    td_cells =
      Regex.scan(td_regex, row_html)
      |> Enum.map(fn [_, content] -> parse_table_cell(content, opts, false) end)

    # Combine cells (th first, then td)
    cells = th_cells ++ td_cells

    # Create ProseMirror tableRow
    %{
      "type" => "tableRow",
      "content" => cells
    }
  end

  # Parse a table cell from HTML
  defp parse_table_cell(cell_html, _opts, _is_header) do
    # Extract alignment from style attribute if present
    align_match = Regex.run(~r/text-align:\s*(left|center|right|justify)/, cell_html)
    alignment = if align_match, do: Enum.at(align_match, 1), else: nil

    # Extract colspan if present
    colspan_match = Regex.run(~r/colspan=["']?(\d+)["']?/, cell_html)
    colspan = if colspan_match, do: String.to_integer(Enum.at(colspan_match, 1)), else: 1

    # Extract rowspan if present
    rowspan_match = Regex.run(~r/rowspan=["']?(\d+)["']?/, cell_html)
    rowspan = if rowspan_match, do: String.to_integer(Enum.at(rowspan_match, 1)), else: 1

    # Create cell content by parsing the HTML within
    content =
      if String.contains?(cell_html, "<blockquote>") do
        # We're not supporting blockquotes inside table cells, extracting just the text
        [
          %{
            "type" => "paragraph",
            "content" => [%{"type" => "text", "text" => extract_text_from_html(cell_html)}]
          }
        ]
      else
        # Simple paragraph with text
        [
          %{
            "type" => "paragraph",
            "content" => [%{"type" => "text", "text" => extract_text_from_html(cell_html)}]
          }
        ]
      end

    # Create ProseMirror tableCell
    %{
      "type" => "tableCell",
      "attrs" => %{
        "colspan" => colspan,
        "rowspan" => rowspan,
        "alignment" => alignment
      },
      "content" => content
    }
  end

  # Convert MDEx nodes
  defp convert_mdex_node(%MDEx.Text{literal: text}, _opts) do
    create_text_node(text)
  end

  defp convert_mdex_node(%MDEx.Strong{nodes: content}, _opts) do
    text = get_mdex_text_content(content)
    # Clean any HTML tags from the text content
    text_content = clean_html_tags(text)

    %{
      "type" => "text",
      "text" => text_content,
      "marks" => [%{"type" => "bold"}]
    }
  end

  defp convert_mdex_node(%MDEx.Emph{nodes: content}, _opts) do
    text = get_mdex_text_content(content)
    # Clean any HTML tags from the text content
    text_content = clean_html_tags(text)

    %{
      "type" => "text",
      "text" => text_content,
      "marks" => [%{"type" => "italic"}]
    }
  end

  defp convert_mdex_node(%MDEx.Code{literal: content}, _opts) do
    # Clean any HTML tags from the code content
    text_content = clean_html_tags(content)

    %{
      "type" => "text",
      "text" => text_content,
      "marks" => [%{"type" => "code"}]
    }
  end

  defp convert_mdex_node(%MDEx.Link{url: href, title: title, nodes: content}, _opts) do
    text = get_mdex_text_content(content)
    # Clean any HTML tags from the link text
    text_content = clean_html_tags(text)

    %{
      "type" => "text",
      "text" => text_content,
      "marks" => [
        %{
          "type" => "link",
          "attrs" => %{"href" => href, "title" => title || ""}
        }
      ]
    }
  end

  defp convert_mdex_node(%MDEx.Image{url: src, title: title, nodes: content}, _opts) do
    alt = get_mdex_text_content(content)

    %{
      "type" => "image",
      "attrs" => %{
        "src" => src,
        "alt" => alt,
        "title" => title || ""
      }
    }
  end

  defp convert_mdex_node(%MDEx.SoftBreak{}, _opts) do
    %{"type" => "text", "text" => " "}
  end

  defp convert_mdex_node(%MDEx.LineBreak{}, _opts) do
    %{"type" => "hardBreak"}
  end

  defp convert_mdex_node(%MDEx.HtmlInline{literal: literal}, _opts) do
    # Parse the HTML inline element and convert to appropriate mark
    cond do
      # Skip <u> tags and just extract the text content without adding underline mark
      String.starts_with?(literal, "<u>") && String.ends_with?(literal, "</u>") ->
        # Extract text without applying underline mark
        text = String.slice(literal, 3..-5)
        text_content = if String.trim(text) == "", do: " ", else: text

        %{
          "type" => "text",
          "text" => text_content
        }

      String.starts_with?(literal, "<sub>") && String.ends_with?(literal, "</sub>") ->
        # Subscript mark
        text = String.slice(literal, 5..-7)
        text_content = if String.trim(text) == "", do: " ", else: text

        %{
          "type" => "text",
          "text" => text_content,
          "marks" => [%{"type" => "subscript"}]
        }

      String.starts_with?(literal, "<sup>") && String.ends_with?(literal, "</sup>") ->
        # Superscript mark
        text = String.slice(literal, 5..-7)
        text_content = if String.trim(text) == "", do: " ", else: text

        %{
          "type" => "text",
          "text" => text_content,
          "marks" => [%{"type" => "superscript"}]
        }

      String.starts_with?(literal, "<mark>") && String.ends_with?(literal, "</mark>") ->
        # Highlight/mark
        text = String.slice(literal, 6..-8)
        text_content = if String.trim(text) == "", do: " ", else: text

        %{
          "type" => "text",
          "text" => text_content,
          "marks" => [%{"type" => "highlight"}]
        }

      true ->
        # Fallback - extract text from HTML without adding marks
        text = extract_text_from_html(literal)

        %{
          "type" => "text",
          "text" => text
        }
    end
  end

  # Fallback handler for unknown node types
  defp convert_mdex_node(node, _opts) do
    # Fallback to space character instead of empty text node
    IO.inspect(node, label: "Unhandled MDEx node type")
    %{"type" => "text", "text" => " "}
  end

  # Convert inline nodes
  defp convert_inline(nodes, opts) when is_list(nodes) do
    Enum.map(nodes, &convert_inline_node(&1, opts))
    |> List.flatten()
  end

  # Convert text node
  defp convert_inline_node(text, _opts) when is_binary(text) do
    text_content = if String.trim(text) == "", do: " ", else: text
    %{"type" => "text", "text" => text_content}
  end

  # Convert strong/bold text
  defp convert_inline_node({"strong", _attrs, content, _meta}, _opts) do
    # Clean any HTML tags in the text content
    text_content = content |> get_text_content() |> clean_html_tags()

    %{
      "type" => "text",
      "text" => text_content,
      "marks" => [%{"type" => "bold"}]
    }
  end

  # Convert emphasis/italic
  defp convert_inline_node({"em", _attrs, content, _meta}, _opts) do
    # Clean any HTML tags in the text content
    text_content = content |> get_text_content() |> clean_html_tags()

    %{
      "type" => "text",
      "text" => text_content,
      "marks" => [%{"type" => "italic"}]
    }
  end

  # Convert code span
  defp convert_inline_node({"code", _attrs, [content], _meta}, _opts) when is_binary(content) do
    %{
      "type" => "text",
      "text" => content,
      "marks" => [%{"type" => "code"}]
    }
  end

  # Convert link
  defp convert_inline_node({"a", attrs, content, _meta}, _opts) do
    href = attrs |> Enum.find(fn {key, _} -> key == "href" end) |> elem(1)
    title = attrs |> Enum.find(fn {key, _} -> key == "title" end)
    title_value = if title, do: elem(title, 1), else: ""

    %{
      "type" => "text",
      "text" => get_text_content(content),
      "marks" => [
        %{
          "type" => "link",
          "attrs" => %{"href" => href, "title" => title_value}
        }
      ]
    }
  end

  # Convert image
  defp convert_inline_node({"img", attrs, _content, _meta}, _opts) do
    src = attrs |> Enum.find(fn {key, _} -> key == "src" end) |> elem(1)
    title = attrs |> Enum.find(fn {key, _} -> key == "title" end)
    title_value = if title, do: elem(title, 1), else: ""
    alt = attrs |> Enum.find(fn {key, _} -> key == "alt" end)
    alt_value = if alt, do: elem(alt, 1), else: ""

    %{
      "type" => "image",
      "attrs" => %{
        "src" => src,
        "alt" => alt_value,
        "title" => title_value
      }
    }
  end

  # Convert line break
  defp convert_inline_node({"br", _attrs, _content, _meta}, _opts) do
    %{"type" => "hardBreak"}
  end

  # Make sure cells have at least a paragraph
  defp maybe_wrap_in_paragraph([]), do: [%{"type" => "paragraph", "content" => []}]

  defp maybe_wrap_in_paragraph(content) do
    if Enum.any?(content, fn node -> node["type"] == "paragraph" end) do
      content
    else
      [%{"type" => "paragraph", "content" => content}]
    end
  end

  # Helper to get text content from MDEx AST nodes
  defp get_mdex_text_content(nodes) when is_list(nodes) do
    Enum.map_join(nodes, "", fn
      %MDEx.Text{literal: text} -> text
      %MDEx.SoftBreak{} -> " "
      %MDEx.LineBreak{} -> " "
      %MDEx.HtmlInline{literal: literal} -> literal
      node -> get_mdex_text_content(node.nodes)
    end)
  end

  defp get_mdex_text_content(%{nodes: nodes}) when is_list(nodes) do
    get_mdex_text_content(nodes)
  end

  defp get_mdex_text_content(%MDEx.HtmlInline{literal: literal}) do
    literal
  end

  defp get_mdex_text_content(_), do: ""

  # Helper to clean HTML tags from text
  defp clean_html_tags(text) when is_binary(text) do
    text
    # First, extract text from blockquotes
    |> String.replace(~r/<blockquote>(.*?)<\/blockquote>/si, "\\1")
    |> String.replace(~r/<[^>]*>/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> then(fn cleaned -> if cleaned == "", do: " ", else: cleaned end)
  end

  # Helper to get text content from MDEx AST nodes
  defp get_text_content(nodes) when is_list(nodes) do
    Enum.map_join(nodes, "", fn
      text when is_binary(text) -> text
      {"br", _, _, _} -> " "
      {_tag, _attrs, content, _meta} -> get_text_content(content)
      _ -> ""
    end)
  end

  defp get_text_content(text) when is_binary(text), do: text
  defp get_text_content(_), do: ""

  # For any text node, ensure we never create empty text
  defp create_text_node(text) do
    text_content = if String.trim(text) == "", do: " ", else: text
    %{"type" => "text", "text" => text_content}
  end

  # Helper to extract text from HTML content
  defp extract_text_from_html(html) do
    # First, extract text from blockquotes, then remove other tags
    text =
      html
      # Extract blockquote content
      |> String.replace(~r/<blockquote>(.*?)<\/blockquote>/si, "\\1")
      # Replace tags with spaces
      |> String.replace(~r/<[^>]*>/, " ")
      # Normalize whitespace
      |> String.replace(~r/\s+/, " ")
      # Trim leading/trailing whitespace
      |> String.trim()

    # Ensure we never return an empty string
    if text == "", do: " ", else: text
  end
end

defmodule InvalidMarkdownError do
  defexception [:message]
end
