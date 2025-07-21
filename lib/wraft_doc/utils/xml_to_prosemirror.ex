defmodule WraftDoc.Utils.XmlToProseMirror do
  @moduledoc """
  Module for converting XML to ProseMirror Node JSON format.

  This module provides functionality to parse XML documents and convert them
  into ProseMirror's JSON structure, which is used throughout the WraftDoc system
  for document editing and processing.
  """
  alias WraftDoc.Utils.XmlToProseMirror.XmlParseError

  @doc """
  Converts XML text to ProseMirror Node JSON format.

  ## Parameters
    - xml: String containing XML content
    - opts: Keyword list of options (optional)

  ## Examples
      iex> WraftDoc.Utils.XmlToProseMirror.to_prosemirror("<p>Hello <strong>World</strong></p>")
      %{
        "type" => "doc",
        "content" => [
          %{
            "type" => "paragraph",
            "content" => [
              %{"type" => "text", "text" => "Hello "},
              %{
                "type" => "text",
                "text" => "World",
                "marks" => [%{"type" => "bold"}]
              }
            ]
          }
        ]
      }

  ## Returns
    - Map containing ProseMirror document structure
    - Raises `XmlParseError` if XML is invalid
  """
  @spec to_prosemirror(String.t(), Keyword.t()) :: map()
  def to_prosemirror(xml, opts \\ []) when is_binary(xml) do
    # Validate input
    case validate_xml_input(xml) do
      {:ok, validated_xml} ->
        try do
          # Parse XML using :xmerl
          {parsed_xml, _} = :xmerl_scan.string(String.to_charlist(validated_xml), quiet: true)

          # Convert to ProseMirror JSON structure
          %{
            "type" => "doc",
            "content" => [convert_xml_element(parsed_xml, opts)]
          }
        rescue
          error ->
            reraise XmlParseError.exception("Failed to parse XML: #{inspect(error)}"),
                    __STACKTRACE__
        catch
          :exit, reason ->
            raise XmlParseError,
                  "Failed to parse XML: #{inspect(reason)}"
        end

      {:error, reason} ->
        raise XmlParseError, reason
    end
  end

  @doc """
  Safely converts input to ProseMirror format, handling both XML and non-XML content.

  This function will:
  - Convert valid XML to ProseMirror format
  - Wrap plain text in paragraph elements
  - Handle empty input gracefully
  - Provide helpful error messages for invalid input
  """
  @spec safe_to_prosemirror(any(), Keyword.t()) :: {:ok, map()} | {:error, String.t()}
  def safe_to_prosemirror(input, opts \\ []) do
    case input do
      nil ->
        {:ok,
         %{
           "type" => "doc",
           "content" => [
             %{"type" => "paragraph", "content" => [%{"type" => "text", "text" => ""}]}
           ]
         }}

      input when is_binary(input) ->
        result = to_prosemirror(input, opts)
        {:ok, result}

      _ ->
        {:error, "Input must be a string or nil"}
    end
  rescue
    error in XmlParseError ->
      {:error, error.message}
  end

  @doc """
  Safely converts a complete XML document to ProseMirror format.

  This function handles XML documents with multiple root elements or text nodes
  and provides safe error handling.
  """
  @spec safe_document_to_prosemirror(any(), Keyword.t()) :: {:ok, map()} | {:error, String.t()}
  def safe_document_to_prosemirror(input, opts \\ []) do
    case input do
      nil ->
        {:ok,
         %{
           "type" => "doc",
           "content" => [
             %{"type" => "paragraph", "content" => [%{"type" => "text", "text" => ""}]}
           ]
         }}

      input when is_binary(input) ->
        result = document_to_prosemirror(input, opts)
        {:ok, result}

      _ ->
        {:error, "Input must be a string or nil"}
    end
  rescue
    error in XmlParseError ->
      {:error, error.message}
  end

  @doc """
  Converts a complete XML document to ProseMirror format.

  This function handles XML documents with multiple root elements or text nodes.
  """
  @spec document_to_prosemirror(String.t(), Keyword.t()) :: map()
  def document_to_prosemirror(xml, opts \\ []) when is_binary(xml) do
    # Validate input
    case validate_xml_input(xml) do
      {:ok, validated_xml} ->
        try do
          # Wrap in a root element to handle multiple top-level elements
          wrapped_xml = "<root>#{validated_xml}</root>"
          {parsed_xml, _} = :xmerl_scan.string(String.to_charlist(wrapped_xml), quiet: true)

          # Extract content from the root wrapper
          content = extract_content_from_root(parsed_xml, opts)

          %{
            "type" => "doc",
            "content" => content
          }
        rescue
          error ->
            reraise XmlParseError.exception("Failed to parse XML document: #{inspect(error)}"),
                    __STACKTRACE__
        catch
          :exit, reason ->
            raise XmlParseError,
                  "Failed to parse XML document: #{inspect(reason)}"
        end

      {:error, reason} ->
        raise XmlParseError, reason
    end
  end

  # Convert XML element to ProseMirror node
  defp convert_xml_element({:xmlElement, name, _, _, _, _, _, attrs, content, _, _, _}, opts) do
    element_name = atom_to_string(name)
    handle_element_by_type(element_name, attrs, content, opts)
  end

  # Convert XML text node to ProseMirror text
  defp convert_xml_element({:xmlText, _, _, _, text, :text}, _opts) do
    text_content =
      text
      |> to_string()
      |> String.trim()

    if text_content == "" do
      nil
    else
      %{"type" => "text", "text" => text_content}
    end
  end

  # Handle other XML node types
  defp convert_xml_element({:xmlComment, _, _, _, _}, _opts), do: nil
  defp convert_xml_element({:xmlPI, _, _, _, _}, _opts), do: nil
  defp convert_xml_element(_, _opts), do: nil

  # Handle elements by type to reduce complexity
  defp handle_element_by_type("doc", _attrs, content, opts) do
    %{
      "type" => "doc",
      "content" => convert_content_list(content, opts)
    }
  end

  defp handle_element_by_type("p", _attrs, content, opts) do
    create_paragraph_node(content, opts)
  end

  defp handle_element_by_type("paragraph", _attrs, content, opts) do
    create_paragraph_node(content, opts)
  end

  defp handle_element_by_type(name, attrs, content, opts)
       when name in ["h1", "h2", "h3", "h4", "h5", "h6"] do
    level = String.to_integer(String.last(name))
    create_heading_node(attrs, content, level, opts)
  end

  defp handle_element_by_type("heading", attrs, content, opts) do
    level = attrs |> get_attribute_value("level") |> parse_integer(1)
    create_heading_node(attrs, content, level, opts)
  end

  defp handle_element_by_type("strong", _attrs, content, opts) do
    create_formatted_text(content, "bold", opts)
  end

  defp handle_element_by_type("b", _attrs, content, opts) do
    create_formatted_text(content, "bold", opts)
  end

  defp handle_element_by_type("em", _attrs, content, opts) do
    create_formatted_text(content, "italic", opts)
  end

  defp handle_element_by_type("i", _attrs, content, opts) do
    create_formatted_text(content, "italic", opts)
  end

  defp handle_element_by_type("u", _attrs, content, opts) do
    create_formatted_text(content, "underline", opts)
  end

  defp handle_element_by_type("s", _attrs, content, opts) do
    create_formatted_text(content, "strike", opts)
  end

  defp handle_element_by_type("strike", _attrs, content, opts) do
    create_formatted_text(content, "strike", opts)
  end

  defp handle_element_by_type("code", _attrs, content, opts) do
    create_formatted_text(content, "code", opts)
  end

  defp handle_element_by_type("a", attrs, content, opts) do
    href = get_attribute_value(attrs, "href")
    title = get_attribute_value(attrs, "title")
    create_link_text(content, href, title, opts)
  end

  defp handle_element_by_type("ul", attrs, content, opts) do
    %{
      "type" => "bulletList",
      "attrs" => convert_list_attrs(attrs),
      "content" => convert_list_items(content, opts)
    }
  end

  defp handle_element_by_type("ol", attrs, content, opts) do
    %{
      "type" => "bulletList",
      "attrs" => Map.merge(convert_list_attrs(attrs), %{"kind" => "ordered"}),
      "content" => convert_list_items(content, opts)
    }
  end

  defp handle_element_by_type("orderedList", attrs, content, opts) do
    %{
      "type" => "orderedList",
      "attrs" => convert_prosemirror_list_attrs(attrs),
      "content" => convert_list_items(content, opts)
    }
  end

  defp handle_element_by_type("bulletList", attrs, content, opts) do
    %{
      "type" => "bulletList",
      "attrs" => convert_prosemirror_list_attrs(attrs),
      "content" => convert_list_items(content, opts)
    }
  end

  defp handle_element_by_type("li", _attrs, content, opts) do
    %{
      "type" => "listItem",
      "content" => convert_content_list(content, opts)
    }
  end

  defp handle_element_by_type("listItem", attrs, content, opts) do
    %{
      "type" => "listItem",
      "attrs" => convert_prosemirror_list_item_attrs(attrs),
      "content" => convert_content_list(content, opts)
    }
  end

  defp handle_element_by_type("blockquote", _attrs, content, opts) do
    %{
      "type" => "blockquote",
      "content" => convert_content_list(content, opts)
    }
  end

  defp handle_element_by_type("pre", attrs, content, opts) do
    %{
      "type" => "codeBlock",
      "attrs" => convert_code_attrs(attrs),
      "content" => convert_content_list(content, opts)
    }
  end

  defp handle_element_by_type("table", attrs, content, opts) do
    %{
      "type" => "table",
      "attrs" => convert_table_attrs(attrs),
      "content" => convert_table_content(content, opts)
    }
  end

  defp handle_element_by_type("tr", _attrs, content, opts) do
    %{
      "type" => "tableRow",
      "content" => convert_table_row_content(content, opts)
    }
  end

  defp handle_element_by_type("td", attrs, content, opts) do
    %{
      "type" => "tableCell",
      "attrs" => convert_table_cell_attrs(attrs),
      "content" => convert_content_list(content, opts)
    }
  end

  defp handle_element_by_type("th", attrs, content, opts) do
    %{
      "type" => "tableHeader",
      "attrs" => convert_table_cell_attrs(attrs),
      "content" => convert_content_list(content, opts)
    }
  end

  defp handle_element_by_type("img", attrs, _content, _opts) do
    %{
      "type" => "image",
      "attrs" => convert_image_attrs(attrs)
    }
  end

  defp handle_element_by_type("image", attrs, _content, _opts) do
    %{
      "type" => "image",
      "attrs" => convert_image_attrs(attrs)
    }
  end

  defp handle_element_by_type("br", _attrs, _content, _opts) do
    %{"type" => "hardBreak"}
  end

  defp handle_element_by_type("hr", _attrs, _content, _opts) do
    %{"type" => "horizontalRule"}
  end

  defp handle_element_by_type("pageBreak", _attrs, _content, _opts) do
    %{"type" => "pageBreak"}
  end

  defp handle_element_by_type("hardBreak", _attrs, _content, _opts) do
    %{"type" => "hardBreak"}
  end

  defp handle_element_by_type("horizontalRule", _attrs, _content, _opts) do
    %{"type" => "horizontalRule"}
  end

  defp handle_element_by_type("codeBlock", attrs, content, opts) do
    %{
      "type" => "codeBlock",
      "attrs" => convert_code_attrs(attrs),
      "content" => convert_content_list(content, opts)
    }
  end

  defp handle_element_by_type("fancyparagraph", attrs, content, opts) do
    %{
      "type" => "fancyparagraph",
      "attrs" => convert_element_attrs(attrs),
      "content" => convert_content_list(content, opts)
    }
  end

  defp handle_element_by_type("mention", attrs, content, opts) do
    %{
      "type" => "mention",
      "attrs" => convert_mention_attrs(attrs),
      "content" => convert_content_list(content, opts)
    }
  end

  defp handle_element_by_type("tableHeaderCell", attrs, content, opts) do
    %{
      "type" => "tableHeaderCell",
      "attrs" => convert_table_cell_attrs(attrs),
      "content" => convert_content_list(content, opts)
    }
  end

  defp handle_element_by_type("tableCell", attrs, content, opts) do
    %{
      "type" => "tableCell",
      "attrs" => convert_table_cell_attrs(attrs),
      "content" => convert_content_list(content, opts)
    }
  end

  defp handle_element_by_type("tableRow", _attrs, content, opts) do
    %{
      "type" => "tableRow",
      "content" => convert_table_row_content(content, opts)
    }
  end

  defp handle_element_by_type("list", attrs, content, opts) do
    %{
      "type" => "list",
      "attrs" => convert_list_attrs(attrs),
      "content" => convert_list_items(content, opts)
    }
  end

  defp handle_element_by_type("holder", attrs, _content, _opts) do
    %{
      "type" => "holder",
      "attrs" => convert_holder_attrs(attrs)
    }
  end

  defp handle_element_by_type("signature", attrs, _content, _opts) do
    %{
      "type" => "signature",
      "attrs" => convert_signature_attrs(attrs)
    }
  end

  defp handle_element_by_type("div", attrs, content, opts) do
    %{
      "type" => "paragraph",
      "attrs" => convert_element_attrs(attrs),
      "content" => convert_content_list(content, opts)
    }
  end

  defp handle_element_by_type("span", attrs, content, opts) do
    create_formatted_text(content, nil, opts, convert_element_attrs(attrs))
  end

  # Unknown elements - treat as generic containers
  defp handle_element_by_type(_unknown, attrs, content, opts) do
    %{
      "type" => "paragraph",
      "attrs" => convert_element_attrs(attrs),
      "content" => convert_content_list(content, opts)
    }
  end

  # Helper functions for creating common node types
  defp create_paragraph_node(content, opts) do
    content_list = convert_content_list(content, opts)
    base_node = %{"type" => "paragraph"}

    # Only add content if it's not empty
    if content_list != [] do
      Map.put(base_node, "content", content_list)
    else
      base_node
    end
  end

  defp create_heading_node(attrs, content, level, opts) do
    %{
      "type" => "heading",
      "attrs" => attrs |> convert_element_attrs() |> Map.put("level", level),
      "content" => convert_content_list(content, opts)
    }
  end

  # Convert a list of XML content to ProseMirror content
  defp convert_content_list(content, opts) do
    content
    |> Enum.map(&convert_xml_element(&1, opts))
    |> Enum.reject(&is_nil/1)
  end

  # Extract content from root wrapper element
  defp extract_content_from_root({:xmlElement, :root, _, _, _, _, _, _, content, _, _, _}, opts) do
    convert_content_list(content, opts)
  end

  # Create formatted text with marks
  defp create_formatted_text(content, mark_type, opts, additional_attrs \\ %{}) do
    text_content = extract_text_from_content(content, opts)

    base_node = %{"type" => "text", "text" => text_content}

    base_node =
      if map_size(additional_attrs) > 0 do
        Map.put(base_node, "attrs", additional_attrs)
      else
        base_node
      end

    if mark_type do
      Map.put(base_node, "marks", [%{"type" => mark_type}])
    else
      base_node
    end
  end

  # Create link text
  defp create_link_text(content, href, title, opts) do
    text_content = extract_text_from_content(content, opts)

    link_attrs = %{"href" => href || ""}
    link_attrs = if title, do: Map.put(link_attrs, "title", title), else: link_attrs

    %{
      "type" => "text",
      "text" => text_content,
      "marks" => [%{"type" => "link", "attrs" => link_attrs}]
    }
  end

  # Extract text content from XML content list
  defp extract_text_from_content(content, opts) do
    content
    |> Enum.map(&convert_xml_element(&1, opts))
    |> Enum.reject(&is_nil/1)
    |> Enum.map_join("", fn
      %{"type" => "text", "text" => text} -> text
      _ -> ""
    end)
  end

  # Convert list items
  defp convert_list_items(content, opts) do
    content
    |> Enum.map(&convert_xml_element(&1, opts))
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn element ->
      case element do
        %{"type" => "listItem"} ->
          element

        other ->
          %{
            "type" => "listItem",
            "content" => [other]
          }
      end
    end)
  end

  # Convert table content
  defp convert_table_content(content, opts) do
    content
    |> Enum.map(&convert_xml_element(&1, opts))
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&(&1["type"] == "tableRow"))
  end

  # Convert table row content
  defp convert_table_row_content(content, opts) do
    content
    |> Enum.map(&convert_xml_element(&1, opts))
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&(&1["type"] in ["tableCell", "tableHeader", "tableHeaderCell"]))
  end

  # Attribute conversion functions
  defp convert_element_attrs(attrs) do
    Enum.reduce(attrs, %{}, fn {:xmlAttribute, name, _, _, _, _, _, _, value, _}, acc ->
      attr_name = atom_to_string(name)
      attr_value = to_string(value)
      Map.put(acc, attr_name, attr_value)
    end)
  end

  defp convert_list_attrs(attrs) do
    converted = convert_element_attrs(attrs)

    %{
      "type" => Map.get(converted, "type", "bullet"),
      "order" => parse_integer(Map.get(converted, "start", "1"), 1)
    }
  end

  defp convert_prosemirror_list_attrs(attrs) do
    converted = convert_element_attrs(attrs)

    %{
      "kind" => Map.get(converted, "kind", "bullet"),
      "order" => parse_integer(Map.get(converted, "order", "1"), 1),
      "checked" => parse_boolean(Map.get(converted, "checked", "false")),
      "collapsed" => parse_boolean(Map.get(converted, "collapsed", "false"))
    }
  end

  defp convert_prosemirror_list_item_attrs(attrs) do
    converted = convert_element_attrs(attrs)

    %{
      "kind" => Map.get(converted, "kind", "bullet"),
      "checked" => parse_boolean(Map.get(converted, "checked", "false")),
      "collapsed" => parse_boolean(Map.get(converted, "collapsed", "false"))
    }
  end

  defp convert_code_attrs(attrs) do
    converted = convert_element_attrs(attrs)
    %{"language" => extract_language(Map.get(converted, "class", ""))}
  end

  defp convert_table_attrs(attrs) do
    converted = convert_element_attrs(attrs)

    %{
      "columnWidths" => nil,
      "cellMinWidth" => 100,
      "resizable" => true,
      "class" => Map.get(converted, "class", "")
    }
  end

  defp convert_table_cell_attrs(attrs) do
    converted = convert_element_attrs(attrs)

    %{
      "colspan" => String.to_integer(Map.get(converted, "colspan", "1")),
      "rowspan" => String.to_integer(Map.get(converted, "rowspan", "1")),
      "alignment" => Map.get(converted, "align")
    }
  end

  defp convert_image_attrs(attrs) do
    converted = convert_element_attrs(attrs)

    %{
      "src" => Map.get(converted, "src", ""),
      "alt" => Map.get(converted, "alt", ""),
      "title" => Map.get(converted, "title", ""),
      "width" => parse_dimension(Map.get(converted, "width")),
      "height" => parse_dimension(Map.get(converted, "height"))
    }
  end

  defp convert_holder_attrs(attrs) do
    converted = convert_element_attrs(attrs)

    %{
      "name" => Map.get(converted, "name", ""),
      "named" => Map.get(converted, "named"),
      "id" => Map.get(converted, "id")
    }
  end

  defp convert_signature_attrs(attrs) do
    converted = convert_element_attrs(attrs)

    %{
      "width" => parse_dimension(Map.get(converted, "width")) || 200,
      "height" => parse_dimension(Map.get(converted, "height")) || 100,
      "counterparty" => Map.get(converted, "counterparty"),
      "src" => Map.get(converted, "src"),
      "placeholder" => parse_boolean(Map.get(converted, "placeholder", "true"))
    }
  end

  defp convert_mention_attrs(attrs) do
    converted = convert_element_attrs(attrs)

    %{
      "id" => Map.get(converted, "id"),
      "label" => Map.get(converted, "label"),
      "type" => Map.get(converted, "type", "user")
    }
  end

  # Input validation
  defp validate_xml_input(xml) do
    cond do
      is_nil(xml) ->
        {:error, "XML input cannot be nil"}

      String.trim(xml) == "" ->
        # Return empty paragraph for empty input
        {:ok, "<p></p>"}

      not is_binary(xml) ->
        {:error, "XML input must be a string"}

      # Check if it looks like JSON (common mistake)
      String.starts_with?(String.trim(xml), "{") ->
        {:error, "Input appears to be JSON, not XML. Use a different converter for JSON content."}

      # Check if it has basic XML structure
      not (String.contains?(xml, "<") and String.contains?(xml, ">")) ->
        # Treat as plain text and wrap in paragraph
        escaped_text =
          xml
          |> String.replace("&", "&amp;")
          |> String.replace("<", "&lt;")
          |> String.replace(">", "&gt;")

        {:ok, "<p>#{escaped_text}</p>"}

      true ->
        # Clean up problematic Unicode characters that cause XML parsing issues
        cleaned_xml = clean_unicode_characters(xml)
        {:ok, cleaned_xml}
    end
  end

  # Clean problematic Unicode characters that cause XML parsing issues
  defp clean_unicode_characters(xml) do
    xml
    # Replace smart quotes with regular quotes
    # Left double quotation mark (U+201C)
    |> String.replace(<<8220::utf8>>, "\"")
    # Right double quotation mark (U+201D)
    |> String.replace(<<8221::utf8>>, "\"")
    # Left single quotation mark (U+2018)
    |> String.replace(<<8216::utf8>>, "'")
    # Right single quotation mark (U+2019)
    |> String.replace(<<8217::utf8>>, "'")
    # Replace em dash and en dash with regular dash
    # Em dash (U+2014)
    |> String.replace(<<8212::utf8>>, "-")
    # En dash (U+2013)
    |> String.replace(<<8211::utf8>>, "-")
    # Replace non-breaking space with regular space
    # Non-breaking space (U+00A0)
    |> String.replace(<<160::utf8>>, " ")
    # Replace other problematic characters
    # Horizontal ellipsis (U+2026)
    |> String.replace(<<8230::utf8>>, "...")
    # Bullet (U+2022)
    |> String.replace(<<8226::utf8>>, "*")
    # Replace acute accent and other diacritical marks
    # Acute accent (U+00B4)
    |> String.replace(<<180::utf8>>, "'")
    # Grave accent (U+0060)
    |> String.replace(<<96::utf8>>, "'")
    # Diaeresis (U+00A8)
    |> String.replace(<<168::utf8>>, "")
    # Macron (U+00AF)
    |> String.replace(<<175::utf8>>, "-")
    # Cedilla (U+00B8)
    |> String.replace(<<184::utf8>>, "")
    # Replace other common problematic characters
    # Left-pointing double angle quotation mark (U+00AB)
    |> String.replace(<<171::utf8>>, "<<")
    # Right-pointing double angle quotation mark (U+00BB)
    |> String.replace(<<187::utf8>>, ">>")
    # Single left-pointing angle quotation mark (U+2039)
    |> String.replace(<<8249::utf8>>, "<")
    # Single right-pointing angle quotation mark (U+203A)
    |> String.replace(<<8250::utf8>>, ">")
    # Trade mark sign (U+2122)
    |> String.replace(<<8482::utf8>>, "TM")
    # Copyright sign (U+00A9)
    |> String.replace(<<169::utf8>>, "(C)")
    # Registered sign (U+00AE)
    |> String.replace(<<174::utf8>>, "(R)")
    # Degree sign (U+00B0)
    |> String.replace(<<176::utf8>>, "deg")
    # Plus-minus sign (U+00B1)
    |> String.replace(<<177::utf8>>, "+/-")
    # Superscript two (U+00B2)
    |> String.replace(<<178::utf8>>, "2")
    # Superscript three (U+00B3)
    |> String.replace(<<179::utf8>>, "3")
    # Superscript one (U+00B9)
    |> String.replace(<<185::utf8>>, "1")
    # Vulgar fraction one quarter (U+00BC)
    |> String.replace(<<188::utf8>>, "1/4")
    # Vulgar fraction one half (U+00BD)
    |> String.replace(<<189::utf8>>, "1/2")
    # Vulgar fraction three quarters (U+00BE)
    |> String.replace(<<190::utf8>>, "3/4")
    # Replace common accented characters that cause XML parsing issues
    # À (U+00C0)
    |> String.replace(<<192::utf8>>, "A")
    # Á (U+00C1)
    |> String.replace(<<193::utf8>>, "A")
    # Â (U+00C2)
    |> String.replace(<<194::utf8>>, "A")
    # Ã (U+00C3)
    |> String.replace(<<195::utf8>>, "A")
    # Ä (U+00C4)
    |> String.replace(<<196::utf8>>, "A")
    # Å (U+00C5)
    |> String.replace(<<197::utf8>>, "A")
    # Æ (U+00C6)
    |> String.replace(<<198::utf8>>, "AE")
    # Ç (U+00C7)
    |> String.replace(<<199::utf8>>, "C")
    # È (U+00C8)
    |> String.replace(<<200::utf8>>, "E")
    # É (U+00C9)
    |> String.replace(<<201::utf8>>, "E")
    # Ê (U+00CA)
    |> String.replace(<<202::utf8>>, "E")
    # Ë (U+00CB)
    |> String.replace(<<203::utf8>>, "E")
    # Ì (U+00CC)
    |> String.replace(<<204::utf8>>, "I")
    # Í (U+00CD)
    |> String.replace(<<205::utf8>>, "I")
    # Î (U+00CE)
    |> String.replace(<<206::utf8>>, "I")
    # Ï (U+00CF)
    |> String.replace(<<207::utf8>>, "I")
    # Ð (U+00D0)
    |> String.replace(<<208::utf8>>, "D")
    # Ñ (U+00D1)
    |> String.replace(<<209::utf8>>, "N")
    # Ò (U+00D2)
    |> String.replace(<<210::utf8>>, "O")
    # Ó (U+00D3)
    |> String.replace(<<211::utf8>>, "O")
    # Ô (U+00D4)
    |> String.replace(<<212::utf8>>, "O")
    # Õ (U+00D5)
    |> String.replace(<<213::utf8>>, "O")
    # Ö (U+00D6)
    |> String.replace(<<214::utf8>>, "O")
    # × (U+00D7)
    |> String.replace(<<215::utf8>>, "x")
    # Ø (U+00D8)
    |> String.replace(<<216::utf8>>, "O")
    # Ù (U+00D9)
    |> String.replace(<<217::utf8>>, "U")
    # Ú (U+00DA)
    |> String.replace(<<218::utf8>>, "U")
    # Û (U+00DB)
    |> String.replace(<<219::utf8>>, "U")
    # Ü (U+00DC)
    |> String.replace(<<220::utf8>>, "U")
    # Ý (U+00DD)
    |> String.replace(<<221::utf8>>, "Y")
    # Þ (U+00DE)
    |> String.replace(<<222::utf8>>, "Th")
    # ß (U+00DF)
    |> String.replace(<<223::utf8>>, "ss")
    # à (U+00E0)
    |> String.replace(<<224::utf8>>, "a")
    # á (U+00E1)
    |> String.replace(<<225::utf8>>, "a")
    # â (U+00E2)
    |> String.replace(<<226::utf8>>, "a")
    # ã (U+00E3)
    |> String.replace(<<227::utf8>>, "a")
    # ä (U+00E4)
    |> String.replace(<<228::utf8>>, "a")
    # å (U+00E5)
    |> String.replace(<<229::utf8>>, "a")
    # æ (U+00E6)
    |> String.replace(<<230::utf8>>, "ae")
    # ç (U+00E7)
    |> String.replace(<<231::utf8>>, "c")
    # è (U+00E8)
    |> String.replace(<<232::utf8>>, "e")
    # é (U+00E9)
    |> String.replace(<<233::utf8>>, "e")
    # ê (U+00EA)
    |> String.replace(<<234::utf8>>, "e")
    # ë (U+00EB)
    |> String.replace(<<235::utf8>>, "e")
    # ì (U+00EC)
    |> String.replace(<<236::utf8>>, "i")
    # í (U+00ED)
    |> String.replace(<<237::utf8>>, "i")
    # î (U+00EE)
    |> String.replace(<<238::utf8>>, "i")
    # ï (U+00EF)
    |> String.replace(<<239::utf8>>, "i")
    # ð (U+00F0)
    |> String.replace(<<240::utf8>>, "d")
    # ñ (U+00F1)
    |> String.replace(<<241::utf8>>, "n")
    # ò (U+00F2)
    |> String.replace(<<242::utf8>>, "o")
    # ó (U+00F3)
    |> String.replace(<<243::utf8>>, "o")
    # ô (U+00F4)
    |> String.replace(<<244::utf8>>, "o")
    # õ (U+00F5)
    |> String.replace(<<245::utf8>>, "o")
    # ö (U+00F6)
    |> String.replace(<<246::utf8>>, "o")
    # ÷ (U+00F7)
    |> String.replace(<<247::utf8>>, "/")
    # ø (U+00F8)
    |> String.replace(<<248::utf8>>, "o")
    # ù (U+00F9)
    |> String.replace(<<249::utf8>>, "u")
    # ú (U+00FA)
    |> String.replace(<<250::utf8>>, "u")
    # û (U+00FB)
    |> String.replace(<<251::utf8>>, "u")
    # ü (U+00FC)
    |> String.replace(<<252::utf8>>, "u")
    # ý (U+00FD)
    |> String.replace(<<253::utf8>>, "y")
    # þ (U+00FE)
    |> String.replace(<<254::utf8>>, "th")
    # ÿ (U+00FF)
    |> String.replace(<<255::utf8>>, "y")
    # Remove or replace any other control characters that might cause issues
    |> String.replace(~r/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "")
  end

  # Helper functions
  defp atom_to_string(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp atom_to_string(other), do: to_string(other)

  defp get_attribute_value(attrs, attr_name) do
    attrs
    |> Enum.find(fn {:xmlAttribute, name, _, _, _, _, _, _, _, _} ->
      atom_to_string(name) == attr_name
    end)
    |> case do
      {:xmlAttribute, _, _, _, _, _, _, _, value, _} -> to_string(value)
      nil -> nil
    end
  end

  defp extract_language(class_string) do
    case Regex.run(~r/language-(\w+)/, class_string) do
      [_, language] -> language
      _ -> ""
    end
  end

  defp parse_dimension(nil), do: nil

  defp parse_dimension(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_dimension(value) when is_integer(value), do: value
  defp parse_dimension(_), do: nil

  defp parse_integer(nil, default), do: default

  defp parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_integer(value, _default) when is_integer(value), do: value
  defp parse_integer(_, default), do: default

  defp parse_boolean(nil), do: false
  defp parse_boolean("true"), do: true
  defp parse_boolean("false"), do: false
  defp parse_boolean(true), do: true
  defp parse_boolean(false), do: false
  defp parse_boolean(_), do: false
end

defmodule WraftDoc.Utils.XmlToProseMirror.XmlParseError do
  @moduledoc """
  Exception raised when XML parsing fails.
  """
  defexception [:message]
end
