defmodule WraftDoc.Utils.ProsemirrorToMarkdown do
  @moduledoc """
  Prosemirror2Md is a library that converts ProseMirror Node JSON to Markdown.
  """

  @doc """
  Converts a ProseMirror Node JSON to Markdown.
  ## Examples
      iex> WraftDoc.ProsemirrorToMarkdown.convert(%{"type" => "doc", "content" => []})
      ""
      iex> WraftDoc.ProsemirrorToMarkdown.convert(%{"type" => "invalid"})
      ** (WraftDoc.ProsemirrorToMarkdown.InvalidJsonError) Invalid ProseMirror JSON format.
  """
  @default_min_col_width 100

  def convert(%{"type" => "doc", "content" => content}, opts \\ []) do
    Enum.map_join(content, "\n\n", &convert_node(&1, opts))
  end

  defp convert_node(%{"type" => "paragraph", "content" => content}, opts) do
    Enum.map_join(content, "", &convert_node(&1, opts))
  end

  defp convert_node(%{"type" => "paragraph"}, _opts), do: "\n"

  defp convert_node(
         %{"type" => "heading", "attrs" => %{"level" => level}, "content" => content},
         opts
       ) do
    heading = Enum.map_join(content, "", &convert_node(&1, opts))
    String.duplicate("#", level) <> " " <> heading
  end

  defp convert_node(%{"type" => "heading", "attrs" => %{"level" => level}}, _opts),
    do: String.duplicate("#", level)

  defp convert_node(%{"type" => "heading"}, _opts),
    do: raise(InvalidJsonError, "Invalid heading format.")

  defp convert_node(%{"type" => "text", "text" => text, "marks" => marks}, opts) do
    Enum.reduce(Enum.reverse(marks), text, &convert_mark(&2, &1, opts))
  end

  defp convert_node(%{"type" => "text", "text" => text}, _opts), do: text

  defp convert_node(%{"type" => "bulletList", "content" => content}, opts) do
    Enum.map_join(content, "\n", &convert_node(&1, opts))
  end

  defp convert_node(
         %{
           "type" => "image",
           "attrs" => %{"src" => src, "height" => height, "width" => width} = attrs
         },
         _opts
       ) do
    "![#{attrs["alt"]}](#{src}){width=#{width} height=#{height}}"
  end

  defp convert_node(%{"type" => "image"}, _opts),
    do: raise(InvalidJsonError, "Invalid image format.")

  defp convert_node(%{"type" => "holder", "attrs" => %{"named" => named}} = _attrs, _opts)
       when named != "" do
    named
  end

  defp convert_node(%{"type" => "holder", "attrs" => %{"name" => name}}, _opts) do
    "[#{name}]"
  end

  defp convert_node(%{"type" => "holder"}, _opts),
    do: raise(InvalidJsonError, "Invalid holder format.")

  defp convert_node(%{"type" => "table", "content" => rows}, opts) when is_list(rows) do
    table_data = process_table_structure(rows)
    col_widths = calculate_column_widths(table_data)

    border = create_table_line(col_widths)

    formatted_rows = format_table_rows(table_data, col_widths, opts)

    Enum.join([border, formatted_rows, border], "\n")
  end

  defp convert_node(%{"type" => "list", "attrs" => %{"kind" => kind}, "content" => items}, opts) do
    Enum.map_join(items, "\n", fn item ->
      convert_list_item(item, kind, opts, 0)
    end)
  end

  defp convert_node(%{"type" => "blockquote", "content" => content}, opts) do
    content
    |> Enum.map_join("\n", &convert_node(&1, opts))
    |> wrap_lines("> ")
  end

  defp convert_node(%{"type" => "codeBlock", "content" => content}, opts) do
    content = Enum.map_join(content, "", &convert_node(&1, opts))
    "```\n#{content}\n```"
  end

  defp convert_node(%{"type" => "hardBreak"}, _opts), do: "  \n"
  defp convert_node(%{"type" => "horizontalRule"}, _opts), do: "---"

  defp convert_node(%{"type" => type}, _opts),
    do: raise(InvalidJsonError, "Invalid node type: #{type}")

  defp convert_mark(text, %{"type" => "textHighlight"}, _opts), do: text

  defp convert_mark(text, %{"type" => "bold"}, _opts), do: "**#{text}**"
  defp convert_mark(text, %{"type" => "italic"}, _opts), do: "*#{text}*"
  defp convert_mark(text, %{"type" => "code"}, _opts), do: "`#{text}`"

  defp convert_mark(text, %{"type" => "link", "attrs" => %{"href" => href}}, _opts),
    do: "[#{text}](#{href})"

  defp convert_mark(text, %{"type" => "strike"}, _opts), do: "~~#{text}~~"

  defp convert_mark(_text, %{"type" => type}, _opts),
    do: raise(InvalidJsonError, "Invalid mark type: #{type}")

  defp wrap_lines(text, prefix) do
    Enum.map_join(String.split(text, "\n"), "\n", &(prefix <> &1))
  end

  defp convert_list_item(%{"type" => "listItem", "content" => content}, "bullet", opts, level) do
    prefix = String.duplicate("  ", level) <> "- "
    process_list_item_content(content, prefix, opts)
  end

  defp convert_list_item(%{"type" => "listItem", "content" => content}, "ordered", opts, level) do
    prefix = String.duplicate("  ", level) <> "1. "
    process_list_item_content(content, prefix, opts)
  end

  defp convert_list_item(%{"type" => "listItem", "content" => content}, _kind, opts, level) do
    prefix = String.duplicate("  ", level) <> "- "
    process_list_item_content(content, prefix, opts)
  end

  defp process_list_item_content(content, prefix, opts) do
    Enum.map_join(content, "\n", fn
      %{"type" => "paragraph", "content" => paragraph_content} ->
        paragraph_text = Enum.map_join(paragraph_content, "", &convert_node(&1, opts))
        prefix <> paragraph_text

      %{"type" => "list"} = list_node ->
        convert_node(list_node, opts)

      %{"type" => invalid_type} ->
        raise(InvalidJsonError, "Invalid list item content type: #{invalid_type}")
    end)
  end

  defp process_table_structure(rows) do
    {table_data, _} =
      Enum.reduce(rows, {[], %{}}, fn row, {acc_rows, span_tracker} ->
        filtered_cells = filter_table_controller_cells(row["content"] || [])

        {row_cells, new_span_tracker, _next_col} =
          process_row_cells(filtered_cells, span_tracker, 0)

        {acc_rows ++ [row_cells], new_span_tracker}
      end)

    table_data
  end

  defp process_row_cells(cells, span_tracker, col_index) do
    {row_cells, updated_tracker, next_col} =
      handle_spanning_cells(span_tracker, col_index, [])

    Enum.reduce(cells, {row_cells, updated_tracker, next_col}, fn cell,
                                                                  {acc_cells, curr_tracker,
                                                                   curr_col} ->
      curr_col = find_next_available_column(curr_tracker, curr_col)

      attrs = cell["attrs"] || %{}
      colspan = attrs["colspan"] || 1
      rowspan = attrs["rowspan"] || 1

      cell_content = convert_pandoc_table_cell(cell, [])

      cell_info = %{
        content: cell_content,
        colspan: colspan,
        rowspan: rowspan,
        col_start: curr_col
      }

      new_tracker =
        if rowspan > 1 do
          Enum.reduce(1..(rowspan - 1), curr_tracker, fn row_offset, tracker ->
            spans_for_row = Map.get(tracker, row_offset, %{})

            spans =
              Enum.reduce(0..(colspan - 1), spans_for_row, fn col_offset, spans ->
                Map.put(spans, curr_col + col_offset, true)
              end)

            Map.put(tracker, row_offset, spans)
          end)
        else
          curr_tracker
        end

      {acc_cells ++ [cell_info], new_tracker, curr_col + colspan}
    end)
  end

  defp handle_spanning_cells(span_tracker, col_index, acc_cells) do
    spans = Map.get(span_tracker, 0, %{})

    cond do
      map_size(spans) == 0 ->
        {acc_cells, Map.delete(span_tracker, 0), col_index}

      Map.get(spans, col_index) ->
        new_tracker = update_span_tracker(span_tracker, spans, col_index)
        handle_spanning_cells(new_tracker, col_index + 1, acc_cells)

      true ->
        {acc_cells, span_tracker, col_index}
    end
  end

  defp update_span_tracker(span_tracker, spans, col_index) do
    new_spans = Map.delete(spans, col_index)

    if map_size(new_spans) > 0 do
      Map.put(span_tracker, 0, new_spans)
    else
      Map.delete(span_tracker, 0)
    end
  end

  defp find_next_available_column(span_tracker, col_index) do
    spans = Map.get(span_tracker, 0, %{})

    if Map.has_key?(spans, col_index) do
      find_next_available_column(span_tracker, col_index + 1)
    else
      col_index
    end
  end

  defp calculate_column_widths(table_data) do
    max_col_index = calculate_max_col_index(table_data)
    initial_widths = List.duplicate(@default_min_col_width, max_col_index)

    Enum.reduce(table_data, initial_widths, &update_column_widths/2)
  end

  defp calculate_max_col_index(table_data) do
    Enum.reduce(table_data, 0, fn row, max_col ->
      Enum.reduce(row, max_col, fn cell, row_max ->
        max(row_max, cell.col_start + cell.colspan)
      end)
    end)
  end

  defp update_column_widths(row, widths) do
    Enum.reduce(row, widths, fn cell, acc_widths ->
      content_width = calculate_content_width(cell)

      if cell.colspan > 1 do
        update_spanned_columns(cell, acc_widths, content_width)
      else
        update_single_column(cell, acc_widths, content_width)
      end
    end)
  end

  defp calculate_content_width(%{content: content} = _cell) do
    content
    |> String.split("\n", trim: false)
    |> Enum.map(&String.length/1)
    |> Enum.max(fn -> 0 end)
  end

  defp update_spanned_columns(
         %{col_start: col_start, colspan: colspan} = _cell,
         acc_widths,
         content_width
       ) do
    span_widths = Enum.slice(acc_widths, col_start, colspan)
    span_total = Enum.sum(span_widths)

    if content_width > span_total - (colspan - 1) * 3 do
      required_width = content_width + (colspan - 1) * 3
      width_per_col = required_width / colspan

      Enum.with_index(acc_widths, fn width, idx ->
        if idx >= col_start && idx < col_start + colspan do
          max(width, ceil(width_per_col))
        else
          width
        end
      end)
    else
      acc_widths
    end
  end

  defp update_single_column(%{col_start: col_start} = _cell, acc_widths, content_width) do
    List.update_at(acc_widths, col_start, fn width ->
      max(width, content_width)
    end)
  end

  defp format_table_rows(table_data, col_widths, opts) do
    {header_rows, body_rows} =
      case table_data do
        [first_row | rest] -> {[first_row], rest}
        [] -> {[], []}
      end

    header_content = format_rows(header_rows, col_widths, opts)

    body_content = format_rows(body_rows, col_widths, opts)

    header_separator = create_table_line(col_widths, "=")

    case {header_content, body_content} do
      {"", ""} -> ""
      {"", body} -> body
      {header, ""} -> header
      {header, body} -> header <> "\n" <> header_separator <> "\n" <> body
    end
  end

  defp format_rows(rows, col_widths, opts) do
    row_separator = create_table_line(col_widths)

    rows
    |> Enum.map(fn row -> format_row(row, col_widths, opts) end)
    |> Enum.intersperse(row_separator)
    |> Enum.join("\n")
  end

  defp format_row(row_cells, col_widths, _opts) do
    cell_content_map = build_cell_content_map(row_cells)

    max_height = calculate_max_height(cell_content_map)

    0..(max_height - 1)
    |> Enum.map(&build_row_line(&1, cell_content_map, col_widths))
    |> Enum.map_join("\n", &format_line(&1, col_widths))
  end

  defp build_cell_content_map(row_cells) do
    Enum.reduce(row_cells, %{}, fn cell, acc ->
      lines = String.split(cell.content, "\n", trim: false)

      Map.put(acc, cell.col_start, %{
        lines: lines,
        colspan: cell.colspan,
        height: length(lines)
      })
    end)
  end

  defp calculate_max_height(cell_content_map) do
    cell_content_map
    |> Map.values()
    |> Enum.map(& &1.height)
    |> Enum.max(fn -> 1 end)
  end

  defp build_row_line(row_idx, cell_content_map, col_widths) do
    Enum.map(0..(length(col_widths) - 1), fn col_idx ->
      build_cell_content(row_idx, col_idx, cell_content_map)
    end)
  end

  defp build_cell_content(row_idx, col_idx, cell_content_map) do
    case Map.get(cell_content_map, col_idx) do
      nil ->
        nil

      %{lines: lines, colspan: colspan} ->
        content = if row_idx < length(lines), do: Enum.at(lines, row_idx), else: ""
        {content, colspan}
    end
  end

  defp format_line(line_cells, col_widths) do
    {formatted_line, _} =
      Enum.reduce(0..(length(col_widths) - 1), {"", 0}, fn col_idx, {line, skip} ->
        if skip > 0 do
          {line, skip - 1}
        else
          case Enum.at(line_cells, col_idx) do
            nil ->
              width = Enum.at(col_widths, col_idx, @default_min_col_width)
              cell_content = String.pad_trailing("", width)
              {line <> "| " <> cell_content <> " ", 0}

            {content, colspan} ->
              spanned_width =
                col_widths
                |> Enum.slice(col_idx, colspan)
                |> Enum.sum()

              total_width = spanned_width + (colspan - 1) * 3

              cell_content = String.pad_trailing(content, total_width)
              {line <> "| " <> cell_content <> " ", colspan - 1}
          end
        end
      end)

    formatted_line <> "|"
  end

  defp create_table_line(col_widths, char \\ "-") do
    col_widths
    |> Enum.map_join("+", fn width -> String.duplicate(char, width + 2) end)
    |> (&"+#{&1}+").()
  end

  defp convert_pandoc_table_cell(%{"type" => _cell_type, "content" => content}, opts)
       when is_list(content) do
    content
    |> Enum.map_join("", fn item -> process_cell_content_item(item, opts) end)
    |> String.trim_trailing()
  end

  defp convert_pandoc_table_cell(%{"type" => _}, _opts), do: ""

  defp process_cell_content_item(%{"type" => "paragraph", "content" => para_content}, opts)
       when is_list(para_content) do
    text = Enum.map_join(para_content, "", fn item -> process_paragraph_item(item, opts) end)

    if String.trim(text) == "", do: "", else: text <> "\n"
  end

  defp process_cell_content_item(%{"type" => "paragraph"}, _opts), do: "\n"

  defp process_cell_content_item(%{"type" => "hardBreak"}, _opts), do: "\n"

  defp process_cell_content_item(item, opts), do: convert_node(item, opts)

  defp process_paragraph_item(%{"type" => "text", "text" => text}, _opts), do: text
  defp process_paragraph_item(%{"type" => "hardBreak"}, _opts), do: "\n"
  defp process_paragraph_item(item, opts), do: convert_node(item, opts)

  defp filter_table_controller_cells(cells),
    do: Enum.reject(cells, &match?(%{"type" => "tableControllerCell"}, &1))
end

defmodule InvalidJsonError do
  defexception [:message]
end
