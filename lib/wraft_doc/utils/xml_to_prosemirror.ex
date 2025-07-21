defmodule WraftDoc.Utils.XmlToProseMirror do
  @moduledoc """
  Module for converting XML to ProseMirror Node JSON format.
  
  This module provides functionality to parse XML documents and convert them
  into ProseMirror's JSON structure, which is used throughout the WraftDoc system
  for document editing and processing.
  """

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
            raise WraftDoc.Utils.XmlToProseMirror.XmlParseError, "Failed to parse XML: #{inspect(error)}"
        catch
          :exit, reason ->
            raise WraftDoc.Utils.XmlToProseMirror.XmlParseError, "Failed to parse XML: #{inspect(reason)}"
        end
      
      {:error, reason} ->
        raise WraftDoc.Utils.XmlToProseMirror.XmlParseError, reason
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
    try do
      case input do
        nil ->
          {:ok, %{"type" => "doc", "content" => [%{"type" => "paragraph", "content" => [%{"type" => "text", "text" => ""}]}]}}
        
        input when is_binary(input) ->
          result = to_prosemirror(input, opts)
          {:ok, result}
        
        _ ->
          {:error, "Input must be a string or nil"}
      end
    rescue
      error in WraftDoc.Utils.XmlToProseMirror.XmlParseError ->
        {:error, error.message}
    end
  end

  @doc """
  Safely converts a complete XML document to ProseMirror format.
  
  This function handles XML documents with multiple root elements or text nodes
  and provides safe error handling.
  """
  @spec safe_document_to_prosemirror(any(), Keyword.t()) :: {:ok, map()} | {:error, String.t()}
  def safe_document_to_prosemirror(input, opts \\ []) do
    try do
      case input do
        nil ->
          {:ok, %{"type" => "doc", "content" => [%{"type" => "paragraph", "content" => [%{"type" => "text", "text" => ""}]}]}}
        
        input when is_binary(input) ->
          result = document_to_prosemirror(input, opts)
          {:ok, result}
        
        _ ->
          {:error, "Input must be a string or nil"}
      end
    rescue
      error in WraftDoc.Utils.XmlToProseMirror.XmlParseError ->
        {:error, error.message}
    end
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
            raise WraftDoc.Utils.XmlToProseMirror.XmlParseError, "Failed to parse XML document: #{inspect(error)}"
        catch
          :exit, reason ->
            raise WraftDoc.Utils.XmlToProseMirror.XmlParseError, "Failed to parse XML document: #{inspect(reason)}"
        end
      
      {:error, reason} ->
        raise WraftDoc.Utils.XmlToProseMirror.XmlParseError, reason
    end
  end

  # Convert XML element to ProseMirror node
  defp convert_xml_element({:xmlElement, name, _, _, _, _, _, attrs, content, _, _, _}, opts) do
    element_name = atom_to_string(name)
    
    case element_name do
      # Document structure elements
      "doc" -> 
        %{
          "type" => "doc",
          "content" => convert_content_list(content, opts)
        }
      
      # Paragraph elements
      "p" -> 
        content_list = convert_content_list(content, opts)
        base_node = %{"type" => "paragraph"}
        
        # Only add content if it's not empty
        if content_list != [] do
          Map.put(base_node, "content", content_list)
        else
          base_node
        end
      
      "paragraph" ->
        content_list = convert_content_list(content, opts)
        base_node = %{"type" => "paragraph"}
        
        # Only add content if it's not empty
        if content_list != [] do
          Map.put(base_node, "content", content_list)
        else
          base_node
        end
      
      # Heading elements
      name when name in ["h1", "h2", "h3", "h4", "h5", "h6"] ->
        level = String.to_integer(String.last(name))
        %{
          "type" => "heading",
          "attrs" => Map.put(convert_element_attrs(attrs), "level", level),
          "content" => convert_content_list(content, opts)
        }
      
      "heading" ->
        # Get level from attributes
        level = get_attribute_value(attrs, "level") |> parse_integer(1)
        %{
          "type" => "heading",
          "attrs" => Map.put(convert_element_attrs(attrs), "level", level),
          "content" => convert_content_list(content, opts)
        }
      
      # Text formatting elements
      "strong" -> create_formatted_text(content, "bold", opts)
      "b" -> create_formatted_text(content, "bold", opts)
      "em" -> create_formatted_text(content, "italic", opts)
      "i" -> create_formatted_text(content, "italic", opts)
      "u" -> create_formatted_text(content, "underline", opts)
      "s" -> create_formatted_text(content, "strike", opts)
      "strike" -> create_formatted_text(content, "strike", opts)
      "code" -> create_formatted_text(content, "code", opts)
      
      # Link elements
      "a" ->
        href = get_attribute_value(attrs, "href")
        title = get_attribute_value(attrs, "title")
        create_link_text(content, href, title, opts)
      
      # List elements
      "ul" ->
        %{
          "type" => "bulletList",
          "attrs" => convert_list_attrs(attrs),
          "content" => convert_list_items(content, opts)
        }
      
      "ol" ->
        %{
          "type" => "bulletList",
          "attrs" => Map.merge(convert_list_attrs(attrs), %{"kind" => "ordered"}),
          "content" => convert_list_items(content, opts)
        }
      
      "orderedList" ->
        %{
          "type" => "orderedList",
          "attrs" => convert_prosemirror_list_attrs(attrs),
          "content" => convert_list_items(content, opts)
        }
      
      "bulletList" ->
        %{
          "type" => "bulletList",
          "attrs" => convert_prosemirror_list_attrs(attrs),
          "content" => convert_list_items(content, opts)
        }
      
      "li" ->
        %{
          "type" => "listItem",
          "content" => convert_content_list(content, opts)
        }
      
      "listItem" ->
        %{
          "type" => "listItem",
          "attrs" => convert_prosemirror_list_item_attrs(attrs),
          "content" => convert_content_list(content, opts)
        }
      
      # Block elements
      "blockquote" ->
        %{
          "type" => "blockquote",
          "content" => convert_content_list(content, opts)
        }
      
      "pre" ->
        %{
          "type" => "codeBlock",
          "attrs" => convert_code_attrs(attrs),
          "content" => convert_content_list(content, opts)
        }
      
      # Table elements
      "table" ->
        %{
          "type" => "table",
          "attrs" => convert_table_attrs(attrs),
          "content" => convert_table_content(content, opts)
        }
      
      "tr" ->
        %{
          "type" => "tableRow",
          "content" => convert_table_row_content(content, opts)
        }
      
      "td" ->
        %{
          "type" => "tableCell",
          "attrs" => convert_table_cell_attrs(attrs),
          "content" => convert_content_list(content, opts)
        }
      
      "th" ->
        %{
          "type" => "tableHeader",
          "attrs" => convert_table_cell_attrs(attrs),
          "content" => convert_content_list(content, opts)
        }
      
      # Media elements
      "img" ->
        %{
          "type" => "image",
          "attrs" => convert_image_attrs(attrs)
        }
      
      "image" ->
        %{
          "type" => "image",
          "attrs" => convert_image_attrs(attrs)
        }
      
      # Break elements
      "br" -> %{"type" => "hardBreak"}
      "hr" -> %{"type" => "horizontalRule"}
      "pageBreak" -> %{"type" => "pageBreak"}
      "hardBreak" -> %{"type" => "hardBreak"}
      "horizontalRule" -> %{"type" => "horizontalRule"}
      
      # Code elements
      "codeBlock" ->
        %{
          "type" => "codeBlock",
          "attrs" => convert_code_attrs(attrs),
          "content" => convert_content_list(content, opts)
        }
      
      # Special paragraph types
      "fancyparagraph" ->
        %{
          "type" => "fancyparagraph",
          "attrs" => convert_element_attrs(attrs),
          "content" => convert_content_list(content, opts)
        }
      
      # Mention elements
      "mention" ->
        %{
          "type" => "mention",
          "attrs" => convert_mention_attrs(attrs),
          "content" => convert_content_list(content, opts)
        }
      
      # Additional table cell types
      "tableHeaderCell" ->
        %{
          "type" => "tableHeaderCell",
          "attrs" => convert_table_cell_attrs(attrs),
          "content" => convert_content_list(content, opts)
        }
      
      "tableCell" ->
        %{
          "type" => "tableCell",
          "attrs" => convert_table_cell_attrs(attrs),
          "content" => convert_content_list(content, opts)
        }
      
      "tableRow" ->
        %{
          "type" => "tableRow",
          "content" => convert_table_row_content(content, opts)
        }
      
      # Generic list element
      "list" ->
        %{
          "type" => "list",
          "attrs" => convert_list_attrs(attrs),
          "content" => convert_list_items(content, opts)
        }
      
      # Custom elements (WraftDoc specific)
      "holder" ->
        %{
          "type" => "holder",
          "attrs" => convert_holder_attrs(attrs)
        }
      
      "signature" ->
        %{
          "type" => "signature",
          "attrs" => convert_signature_attrs(attrs)
        }
      
      # Generic div/span handling
      "div" ->
        %{
          "type" => "paragraph",
          "attrs" => convert_element_attrs(attrs),
          "content" => convert_content_list(content, opts)
        }
      
      "span" -> create_formatted_text(content, nil, opts, convert_element_attrs(attrs))
      
      # Unknown elements - treat as generic containers
      _ ->
        %{
          "type" => "paragraph",
          "attrs" => convert_element_attrs(attrs),
          "content" => convert_content_list(content, opts)
        }
    end
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
    |> Enum.map(fn
      %{"type" => "text", "text" => text} -> text
      _ -> ""
    end)
    |> Enum.join("")
  end

  # Convert list items
  defp convert_list_items(content, opts) do
    content
    |> Enum.map(&convert_xml_element(&1, opts))
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn element ->
      case element do
        %{"type" => "listItem"} -> element
        other -> %{
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
    attrs
    |> Enum.reduce(%{}, fn {:xmlAttribute, name, _, _, _, _, _, _, value, _}, acc ->
      attr_name = atom_to_string(name)
      attr_value = to_string(value)
      Map.put(acc, attr_name, attr_value)
    end)
  end



  defp convert_list_attrs(attrs) do
    converted = convert_element_attrs(attrs)
    
    %{
      "type" => Map.get(converted, "type", "bullet"),
      "order" => Map.get(converted, "start", "1") |> parse_integer(1)
    }
  end

  defp convert_prosemirror_list_attrs(attrs) do
    converted = convert_element_attrs(attrs)
    
    %{
      "kind" => Map.get(converted, "kind", "bullet"),
      "order" => Map.get(converted, "order", "1") |> parse_integer(1),
      "checked" => Map.get(converted, "checked", "false") |> parse_boolean(),
      "collapsed" => Map.get(converted, "collapsed", "false") |> parse_boolean()
    }
  end

  defp convert_prosemirror_list_item_attrs(attrs) do
    converted = convert_element_attrs(attrs)
    
    %{
      "kind" => Map.get(converted, "kind", "bullet"),
      "checked" => Map.get(converted, "checked", "false") |> parse_boolean(),
      "collapsed" => Map.get(converted, "collapsed", "false") |> parse_boolean()
    }
  end

  defp convert_code_attrs(attrs) do
    converted = convert_element_attrs(attrs)
    %{"language" => Map.get(converted, "class", "") |> extract_language()}
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
      "colspan" => Map.get(converted, "colspan", "1") |> String.to_integer(),
      "rowspan" => Map.get(converted, "rowspan", "1") |> String.to_integer(),
      "alignment" => Map.get(converted, "align")
    }
  end

  defp convert_image_attrs(attrs) do
    converted = convert_element_attrs(attrs)
    %{
      "src" => Map.get(converted, "src", ""),
      "alt" => Map.get(converted, "alt", ""),
      "title" => Map.get(converted, "title", ""),
      "width" => Map.get(converted, "width") |> parse_dimension(),
      "height" => Map.get(converted, "height") |> parse_dimension()
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
      "width" => Map.get(converted, "width") |> parse_dimension() || 200,
      "height" => Map.get(converted, "height") |> parse_dimension() || 100,
      "counterparty" => Map.get(converted, "counterparty"),
      "src" => Map.get(converted, "src"),
      "placeholder" => Map.get(converted, "placeholder", "true") |> parse_boolean()
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
        {:ok, "<p></p>"}  # Return empty paragraph for empty input
      
      not is_binary(xml) ->
        {:error, "XML input must be a string"}
      
      # Check if it looks like JSON (common mistake)
      String.starts_with?(String.trim(xml), "{") ->
        {:error, "Input appears to be JSON, not XML. Use a different converter for JSON content."}
      
      # Check if it has basic XML structure
      not (String.contains?(xml, "<") and String.contains?(xml, ">")) ->
        # Treat as plain text and wrap in paragraph
        escaped_text = xml |> String.replace("&", "&amp;") |> String.replace("<", "&lt;") |> String.replace(">", "&gt;")
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
    |> String.replace(<<8220::utf8>>, "\"")  # Left double quotation mark (U+201C)
    |> String.replace(<<8221::utf8>>, "\"")  # Right double quotation mark (U+201D)
    |> String.replace(<<8216::utf8>>, "'")   # Left single quotation mark (U+2018)
    |> String.replace(<<8217::utf8>>, "'")   # Right single quotation mark (U+2019)
    # Replace em dash and en dash with regular dash
    |> String.replace(<<8212::utf8>>, "-")   # Em dash (U+2014)
    |> String.replace(<<8211::utf8>>, "-")   # En dash (U+2013)
    # Replace non-breaking space with regular space
    |> String.replace(<<160::utf8>>, " ")    # Non-breaking space (U+00A0)
    # Replace other problematic characters
    |> String.replace(<<8230::utf8>>, "...")  # Horizontal ellipsis (U+2026)
    |> String.replace(<<8226::utf8>>, "*")    # Bullet (U+2022)
    # Replace acute accent and other diacritical marks
    |> String.replace(<<180::utf8>>, "'")     # Acute accent (U+00B4)
    |> String.replace(<<96::utf8>>, "'")      # Grave accent (U+0060)
    |> String.replace(<<168::utf8>>, "")      # Diaeresis (U+00A8)
    |> String.replace(<<175::utf8>>, "-")     # Macron (U+00AF)
    |> String.replace(<<184::utf8>>, "")      # Cedilla (U+00B8)
    # Replace other common problematic characters
    |> String.replace(<<171::utf8>>, "<<")    # Left-pointing double angle quotation mark (U+00AB)
    |> String.replace(<<187::utf8>>, ">>")    # Right-pointing double angle quotation mark (U+00BB)
    |> String.replace(<<8249::utf8>>, "<")    # Single left-pointing angle quotation mark (U+2039)
    |> String.replace(<<8250::utf8>>, ">")    # Single right-pointing angle quotation mark (U+203A)
    |> String.replace(<<8482::utf8>>, "TM")   # Trade mark sign (U+2122)
    |> String.replace(<<169::utf8>>, "(C)")   # Copyright sign (U+00A9)
    |> String.replace(<<174::utf8>>, "(R)")   # Registered sign (U+00AE)
    |> String.replace(<<176::utf8>>, "deg")   # Degree sign (U+00B0)
    |> String.replace(<<177::utf8>>, "+/-")   # Plus-minus sign (U+00B1)
    |> String.replace(<<178::utf8>>, "2")     # Superscript two (U+00B2)
    |> String.replace(<<179::utf8>>, "3")     # Superscript three (U+00B3)
    |> String.replace(<<185::utf8>>, "1")     # Superscript one (U+00B9)
    |> String.replace(<<188::utf8>>, "1/4")   # Vulgar fraction one quarter (U+00BC)
    |> String.replace(<<189::utf8>>, "1/2")   # Vulgar fraction one half (U+00BD)
    |> String.replace(<<190::utf8>>, "3/4")   # Vulgar fraction three quarters (U+00BE)
    # Replace common accented characters that cause XML parsing issues
    |> String.replace(<<192::utf8>>, "A")     # À (U+00C0)
    |> String.replace(<<193::utf8>>, "A")     # Á (U+00C1)
    |> String.replace(<<194::utf8>>, "A")     # Â (U+00C2)
    |> String.replace(<<195::utf8>>, "A")     # Ã (U+00C3)
    |> String.replace(<<196::utf8>>, "A")     # Ä (U+00C4)
    |> String.replace(<<197::utf8>>, "A")     # Å (U+00C5)
    |> String.replace(<<198::utf8>>, "AE")    # Æ (U+00C6)
    |> String.replace(<<199::utf8>>, "C")     # Ç (U+00C7)
    |> String.replace(<<200::utf8>>, "E")     # È (U+00C8)
    |> String.replace(<<201::utf8>>, "E")     # É (U+00C9)
    |> String.replace(<<202::utf8>>, "E")     # Ê (U+00CA)
    |> String.replace(<<203::utf8>>, "E")     # Ë (U+00CB)
    |> String.replace(<<204::utf8>>, "I")     # Ì (U+00CC)
    |> String.replace(<<205::utf8>>, "I")     # Í (U+00CD)
    |> String.replace(<<206::utf8>>, "I")     # Î (U+00CE)
    |> String.replace(<<207::utf8>>, "I")     # Ï (U+00CF)
    |> String.replace(<<208::utf8>>, "D")     # Ð (U+00D0)
    |> String.replace(<<209::utf8>>, "N")     # Ñ (U+00D1)
    |> String.replace(<<210::utf8>>, "O")     # Ò (U+00D2)
    |> String.replace(<<211::utf8>>, "O")     # Ó (U+00D3)
    |> String.replace(<<212::utf8>>, "O")     # Ô (U+00D4)
    |> String.replace(<<213::utf8>>, "O")     # Õ (U+00D5)
    |> String.replace(<<214::utf8>>, "O")     # Ö (U+00D6)
    |> String.replace(<<215::utf8>>, "x")     # × (U+00D7)
    |> String.replace(<<216::utf8>>, "O")     # Ø (U+00D8)
    |> String.replace(<<217::utf8>>, "U")     # Ù (U+00D9)
    |> String.replace(<<218::utf8>>, "U")     # Ú (U+00DA)
    |> String.replace(<<219::utf8>>, "U")     # Û (U+00DB)
    |> String.replace(<<220::utf8>>, "U")     # Ü (U+00DC)
    |> String.replace(<<221::utf8>>, "Y")     # Ý (U+00DD)
    |> String.replace(<<222::utf8>>, "Th")    # Þ (U+00DE)
    |> String.replace(<<223::utf8>>, "ss")    # ß (U+00DF)
    |> String.replace(<<224::utf8>>, "a")     # à (U+00E0)
    |> String.replace(<<225::utf8>>, "a")     # á (U+00E1)
    |> String.replace(<<226::utf8>>, "a")     # â (U+00E2)
    |> String.replace(<<227::utf8>>, "a")     # ã (U+00E3)
    |> String.replace(<<228::utf8>>, "a")     # ä (U+00E4)
    |> String.replace(<<229::utf8>>, "a")     # å (U+00E5)
    |> String.replace(<<230::utf8>>, "ae")    # æ (U+00E6)
    |> String.replace(<<231::utf8>>, "c")     # ç (U+00E7)
    |> String.replace(<<232::utf8>>, "e")     # è (U+00E8)
    |> String.replace(<<233::utf8>>, "e")     # é (U+00E9)
    |> String.replace(<<234::utf8>>, "e")     # ê (U+00EA)
    |> String.replace(<<235::utf8>>, "e")     # ë (U+00EB)
    |> String.replace(<<236::utf8>>, "i")     # ì (U+00EC)
    |> String.replace(<<237::utf8>>, "i")     # í (U+00ED)
    |> String.replace(<<238::utf8>>, "i")     # î (U+00EE)
    |> String.replace(<<239::utf8>>, "i")     # ï (U+00EF)
    |> String.replace(<<240::utf8>>, "d")     # ð (U+00F0)
    |> String.replace(<<241::utf8>>, "n")     # ñ (U+00F1)
    |> String.replace(<<242::utf8>>, "o")     # ò (U+00F2)
    |> String.replace(<<243::utf8>>, "o")     # ó (U+00F3)
    |> String.replace(<<244::utf8>>, "o")     # ô (U+00F4)
    |> String.replace(<<245::utf8>>, "o")     # õ (U+00F5)
    |> String.replace(<<246::utf8>>, "o")     # ö (U+00F6)
    |> String.replace(<<247::utf8>>, "/")     # ÷ (U+00F7)
    |> String.replace(<<248::utf8>>, "o")     # ø (U+00F8)
    |> String.replace(<<249::utf8>>, "u")     # ù (U+00F9)
    |> String.replace(<<250::utf8>>, "u")     # ú (U+00FA)
    |> String.replace(<<251::utf8>>, "u")     # û (U+00FB)
    |> String.replace(<<252::utf8>>, "u")     # ü (U+00FC)
    |> String.replace(<<253::utf8>>, "y")     # ý (U+00FD)
    |> String.replace(<<254::utf8>>, "th")    # þ (U+00FE)
    |> String.replace(<<255::utf8>>, "y")     # ÿ (U+00FF)
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