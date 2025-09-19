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

  @default_min_col_width 55

  @roman %{
    lower: ~w(i ii iii iv v vi vii viii ix x xi xii xiii xiv xv xvi xvii xviii xix xx),
    upper: ~w(I II III IV V VI VII VIII IX X XI XII XIII XIV XV XVI XVII XVIII XIX XX)
  }

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

  defp convert_node(
         %{"type" => "bulletList", "attrs" => %{"kind" => kind}, "content" => content},
         opts
       ) do
    convert_list_content(content, kind, 0, opts)
  end

  defp convert_node(
         %{"type" => "listItem", "attrs" => %{"kind" => kind}, "content" => content} = node,
         opts
       ) do
    depth = opts[:depth] || 0
    index = node["index"] || 1

    {paragraphs, nested} = Enum.split_with(content, &(&1["type"] == "paragraph"))

    text = Enum.map_join(paragraphs, " ", &convert_node(&1, opts))

    marker = list_marker(kind, index)

    current_line =
      String.duplicate("    ", depth) <> "#{marker} #{text}"

    if nested == [] do
      current_line
    else
      current_line <>
        "\n" <>
        Enum.map_join(Enum.with_index(nested, 1), "\n", fn {item, i} ->
          convert_node(Map.put(item, "index", i), depth: depth + 1)
        end)
    end
  end

  defp convert_node(%{"type" => "listItem", "content" => content}, opts) do
    Enum.map_join(content, "", &convert_node(&1, opts))
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
    "  #{named}  "
  end

  defp convert_node(%{"type" => "holder", "attrs" => %{"name" => name}}, _opts) do
    " [#{name}] "
  end

  defp convert_node(%{"type" => "holder"}, _opts),
    do: raise(InvalidJsonError, "Invalid holder format.")

  defp convert_node(%{"type" => "table", "content" => rows} = _table, opts) when is_list(rows) do
    table_data = process_table_structure(rows)
    col_widths = calculate_column_widths(table_data)
    border = create_table_line(col_widths)

    formatted_rows = format_table_rows(table_data, col_widths, opts)

    Enum.join([border, formatted_rows, border], "\n")
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

  defp convert_node(%{"type" => "tableRow", "content" => content}, opts) do
    # Table rows are handled within the table processing
    # This is just a fallback in case a row is processed individually
    Enum.map_join(content, "", &convert_node(&1, opts))
  end

  defp convert_node(%{"type" => "hardBreak"}, _opts), do: "  \n"
  defp convert_node(%{"type" => "horizontalRule"}, _opts), do: "---"
  defp convert_node(%{"type" => "pageBreak"}, _opts), do: "\\pagebreak"

  defp convert_node(
         %{"type" => "signature", "attrs" => %{"width" => width, "height" => height}} = _node,
         _opts
       ) do
    # Placeholder for signature field, as the actual rendering of signatures
    "[SIGNATURE_FIELD_PLACEHOLDER width:#{width} height:#{height}]"
  end

  defp convert_node(%{"type" => type}, _opts),
    do: raise(InvalidJsonError, "Invalid node type: #{type}")

  defp convert_mark(text, %{"type" => "textHighlight"}, _opts), do: "#{text}"

  defp convert_mark(text, %{"type" => "bold"}, _opts), do: "**#{text}**"
  defp convert_mark(text, %{"type" => "italic"}, _opts), do: "*#{text}*"
  defp convert_mark(text, %{"type" => "code"}, _opts), do: "`#{text}`"

  defp convert_mark(text, %{"type" => "link", "attrs" => %{"href" => href}}, _opts),
    do: "[#{text}](#{href})"

  defp convert_mark(text, %{"type" => "strike"}, _opts), do: "~~#{text}~~"

  defp convert_mark(text, %{"type" => "underline"}, _opts), do: "[#{text}]{.underline}"

  defp convert_mark(_text, %{"type" => type}, _opts),
    do: raise(InvalidJsonError, "Invalid mark type: #{type}")

  defp list_marker("ordered", index), do: "#{index}."
  defp list_marker("lower-alpha", index), do: <<?a + index - 1>> <> "."
  defp list_marker("upper-alpha", index), do: <<?A + index - 1>> <> ". "
  defp list_marker("lower-roman", index), do: Enum.at(@roman.lower, index - 1) <> "."
  defp list_marker("upper-roman", index), do: Enum.at(@roman.upper, index - 1) <> ". "
  defp list_marker("bullet", _), do: "-"

  defp convert_item(
         %{"type" => "bulletList", "attrs" => %{"kind" => kind}, "content" => content},
         indent_level,
         opts
       ) do
    convert_list_content(content, kind, indent_level, opts)
  end

  defp convert_item(%{"type" => "paragraph"} = item, indent_level, opts) do
    content = Map.get(item, "content", [])
    text = Enum.map_join(content, "", &convert_node(&1, opts))

    case text do
      "" ->
        ""

      _ ->
        indentation = String.duplicate("   ", indent_level)
        "#{indentation}#{text}"
    end
  end

  defp convert_item(%{"type" => "listItem"} = item, indent_level, opts) do
    # Handle the old structure where lists contain listItems
    content = Map.get(item, "content", [])

    content
    |> Enum.map(&convert_item(&1, indent_level, opts))
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("\n")
  end

  defp convert_item(_, _, _opts), do: ""

  defp convert_list_content(items, list_kind, indent_level, opts) do
    case items do
      [%{"type" => "listItem"} | _] ->
        convert_list_items(items, list_kind, indent_level, opts)

      _ ->
        convert_direct_content(items, list_kind, indent_level, opts)
    end
  end

  defp convert_list_items(items, list_kind, indent_level, opts) do
    items
    |> Enum.with_index(1)
    |> Enum.map(fn {item, index} ->
      convert_list_item_old(item, list_kind, index, indent_level, opts)
    end)
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("\n")
  end

  defp convert_direct_content(items, list_kind, indent_level, opts) do
    items
    |> group_content_items()
    |> Enum.with_index(1)
    |> Enum.map(fn {group, index} ->
      group_marker = get_list_marker(list_kind, index)

      convert_content_group(group, group_marker, indent_level, opts)
    end)
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("\n")
  end

  defp group_content_items(items) do
    items
    |> Enum.reduce([], fn item, acc ->
      case item do
        %{"type" => "paragraph"} ->
          acc ++ [[item]]

        %{"type" => "bulletList"} ->
          handle_bulletlist_grouping(acc, item)

        _ ->
          acc
      end
    end)
    |> Enum.filter(&(&1 != []))
  end

  defp handle_bulletlist_grouping(acc, item) do
    case acc do
      [] ->
        [[item]]

      groups ->
        {last_group, other_groups} = List.pop_at(groups, -1)
        other_groups ++ [last_group ++ [item]]
    end
  end

  defp convert_content_group(group, marker, indent_level, opts) do
    indentation = String.duplicate("   ", indent_level)

    paragraph_text =
      group
      |> Enum.find(&match?(%{"type" => "paragraph"}, &1))
      |> case do
        nil -> ""
        para -> convert_node(para, opts)
      end

    nested_lists =
      Enum.filter(group, &match?(%{"type" => "bulletList"}, &1))

    main_line =
      case paragraph_text do
        "" -> ""
        text -> "#{indentation}#{marker} #{text}"
      end

    nested_content =
      nested_lists
      |> Enum.map(&convert_item(&1, indent_level + 1, opts))
      |> Enum.filter(&(&1 != ""))
      |> Enum.join("\n")

    # Combine main line and nested content
    case {main_line, nested_content} do
      {"", ""} -> ""
      {main, ""} -> main
      {"", nested} -> nested
      {main, nested} -> "#{main}\n#{nested}"
    end
  end

  defp convert_list_item_old(%{"type" => "listItem"} = item, list_kind, index, indent_level, opts) do
    content = Map.get(item, "content", [])
    indentation = String.duplicate("   ", indent_level)

    {paragraph_content, nested_lists} = extract_list_item_parts(content, opts)

    marker = get_list_marker(list_kind, index)

    format_list_item_output(
      paragraph_content,
      nested_lists,
      indentation,
      marker,
      indent_level,
      opts
    )
  end

  defp extract_list_item_parts(content, opts) do
    paragraph_content =
      content
      |> Enum.find(&match?(%{"type" => "paragraph"}, &1))
      |> case do
        nil -> ""
        para -> convert_node(para, opts)
      end

    nested_lists = Enum.filter(content, &match?(%{"type" => "bulletList"}, &1))

    {paragraph_content, nested_lists}
  end

  defp get_list_marker("ordered", index), do: "#{index}."
  defp get_list_marker(_, _), do: "-"

  defp format_list_item_output(
         paragraph_content,
         nested_lists,
         indentation,
         marker,
         indent_level,
         opts
       ) do
    lines = create_main_line(paragraph_content, nested_lists, indentation, marker)

    nested_lines = process_nested_lists(nested_lists, indent_level, opts)

    all_lines = lines ++ nested_lines

    case all_lines do
      [] -> ""
      _ -> Enum.join(all_lines, "\n")
    end
  end

  defp create_main_line(paragraph_content, nested_lists, indentation, marker) do
    case paragraph_content do
      "" when nested_lists == [] -> []
      "" -> []
      text -> ["#{indentation}#{marker} #{text}"]
    end
  end

  defp process_nested_lists(nested_lists, indent_level, opts) do
    Enum.flat_map(nested_lists, fn nested_list ->
      nested_content = convert_item(nested_list, indent_level + 1, opts)
      String.split(nested_content, "\n", trim: true)
    end)
  end

  defp wrap_lines(text, prefix) do
    Enum.map_join(String.split(text, "\n"), "\n", &(prefix <> &1))
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
      handle_rowspans(span_tracker, col_index, [])

    Enum.reduce(cells, {row_cells, updated_tracker, next_col}, fn cell,
                                                                  {acc_cells, curr_tracker,
                                                                   curr_col} ->
      process_single_cell(cell, acc_cells, curr_tracker, curr_col)
    end)
  end

  defp process_single_cell(cell, acc_cells, curr_tracker, curr_col) do
    curr_col = find_next_available_column(curr_tracker, curr_col)

    attrs = cell["attrs"] || %{}
    colspan = attrs["colspan"] || 1
    rowspan = attrs["rowspan"] || 1

    cell_content = convert_pandoc_table_cell(cell, [])

    cell_info = %{
      content: cell_content,
      colspan: colspan,
      rowspan: rowspan,
      col_start: curr_col,
      attrs: attrs
    }

    new_tracker =
      update_tracker_for_rowspan(rowspan, curr_tracker, curr_col, colspan, cell_content, attrs)

    {acc_cells ++ [cell_info], new_tracker, curr_col + colspan}
  end

  defp update_tracker_for_rowspan(rowspan, curr_tracker, curr_col, colspan, cell_content, attrs) do
    if rowspan > 1 do
      Enum.reduce(1..(rowspan - 1), curr_tracker, fn row_offset, tracker ->
        add_rowspan_to_tracker(tracker, row_offset, curr_col, colspan, cell_content, attrs)
      end)
    else
      curr_tracker
    end
  end

  defp add_rowspan_to_tracker(tracker, row_offset, curr_col, colspan, cell_content, attrs) do
    spans_for_row = Map.get(tracker, row_offset, %{})

    spans =
      Enum.reduce(0..(colspan - 1), spans_for_row, fn col_offset, spans ->
        Map.put(spans, curr_col + col_offset, %{
          content: cell_content,
          colspan: colspan,
          col_start: curr_col,
          primary_col: col_offset == 0,
          attrs: attrs
        })
      end)

    Map.put(tracker, row_offset, spans)
  end

  defp handle_rowspans(span_tracker, col_index, acc_cells) do
    spans = Map.get(span_tracker, 0, %{})

    cond do
      map_size(spans) == 0 ->
        {acc_cells, Map.delete(span_tracker, 0), col_index}

      Map.has_key?(spans, col_index) ->
        span_data = Map.get(spans, col_index)

        if span_data.primary_col do
          cell_info = %{
            content: span_data.content,
            colspan: span_data.colspan,
            rowspan: 1,
            col_start: col_index
          }

          new_cells = acc_cells ++ [cell_info]
          new_tracker = update_span_tracker(span_tracker, spans, col_index, span_data.colspan)
          handle_rowspans(new_tracker, col_index + span_data.colspan, new_cells)
        else
          new_tracker = update_span_tracker(span_tracker, spans, col_index, 1)
          handle_rowspans(new_tracker, col_index + 1, acc_cells)
        end

      true ->
        {acc_cells, span_tracker, col_index}
    end
  end

  defp update_span_tracker(span_tracker, spans, col_index, colspan) do
    new_spans =
      Enum.reduce(0..(colspan - 1), spans, fn offset, acc ->
        Map.delete(acc, col_index + offset)
      end)

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

    table_data
    |> Enum.any?()
    |> if do
      process_table_widths(table_data, max_col_index)
    else
      List.duplicate(@default_min_col_width, max_col_index)
    end
  end

  defp process_table_widths([first_row | _], max_col_index) do
    widths = List.duplicate(@default_min_col_width, max_col_index)

    Enum.reduce(first_row, widths, fn cell, acc ->
      process_cell_width(cell, acc)
    end)
  end

  defp process_cell_width(
         %{
           col_start: col_start,
           colspan: colspan,
           attrs: %{"colwidth" => colwidth}
         },
         widths
       ) do
    width = get_width_size(colwidth)
    width_per_col = if colspan > 1, do: div(width, colspan), else: width
    update_column_widths(widths, col_start, colspan, width_per_col)
  end

  defp process_cell_width(
         %{
           col_start: col_start,
           colspan: colspan
         },
         widths
       ) do
    # Use default width for cells without colwidth
    width_per_col = @default_min_col_width
    update_column_widths(widths, col_start, colspan, width_per_col)
  end

  defp process_cell_width(_cell, widths) do
    # Fallback for any unexpected cell structure
    widths
  end

  defp update_column_widths(widths, col_start, colspan, width_per_col) do
    Enum.reduce(0..(colspan - 1), widths, fn offset, acc ->
      col_index = col_start + offset

      if col_index < length(acc) do
        List.replace_at(acc, col_index, width_per_col)
      else
        acc
      end
    end)
  end

  defp get_width_size([colwidth]), do: colwidth
  defp get_width_size(_), do: @default_min_col_width

  defp calculate_max_col_index(table_data) do
    Enum.reduce(table_data, 0, fn row, max_col ->
      Enum.reduce(row, max_col, fn %{col_start: col_start, colspan: colspan}, row_max ->
        max(row_max, col_start + colspan)
      end)
    end)
  end

  defp format_table_rows(table_data, col_widths, opts) do
    {header_rows, body_rows} = split_table_rows(table_data)

    header_content = format_header_content(header_rows, col_widths, opts)
    header_separator = generate_header_separator(header_rows, col_widths)
    header_has_rowspan_to_body = check_header_rowspan_to_body(header_rows, body_rows)

    body_content =
      format_body_content(
        header_rows,
        body_rows,
        col_widths,
        opts,
        header_content,
        header_has_rowspan_to_body
      )

    combine_header_and_body(
      header_content,
      header_separator,
      body_content,
      header_has_rowspan_to_body
    )
  end

  defp split_table_rows([first_row | rest]), do: {[first_row], rest}
  defp split_table_rows([]), do: {[], []}

  defp format_header_content(header_rows, col_widths, opts) do
    Enum.map_join(header_rows, "\n", &format_row(&1, col_widths, opts))
  end

  defp generate_header_separator(header_rows, col_widths) do
    if Enum.any?(header_rows) do
      create_header_separator_line(header_rows, col_widths)
    else
      create_table_line(col_widths, "=")
    end
  end

  defp check_header_rowspan_to_body(header_rows, body_rows) do
    Enum.any?(header_rows) && Enum.any?(body_rows) &&
      Enum.any?(List.last(header_rows), fn cell ->
        cell.rowspan > 1 && cell.rowspan > length(header_rows)
      end)
  end

  defp format_body_content(
         header_rows,
         body_rows,
         col_widths,
         opts,
         header_content,
         header_has_rowspan_to_body
       ) do
    if Enum.any?(body_rows) do
      all_rows = if header_has_rowspan_to_body, do: header_rows ++ body_rows, else: body_rows

      if header_has_rowspan_to_body do
        all_content = format_rows_with_rowspans(all_rows, col_widths, opts)

        header_lines = String.split(header_content, "\n")
        all_lines = String.split(all_content, "\n")

        body_lines = Enum.drop(all_lines, length(header_lines))
        Enum.join(body_lines, "\n")
      else
        format_rows_with_rowspans(body_rows, col_widths, opts)
      end
    else
      ""
    end
  end

  defp combine_header_and_body(
         header_content,
         header_separator,
         body_content,
         header_has_rowspan_to_body
       ) do
    case {header_content, body_content} do
      {"", ""} ->
        ""

      {"", body} ->
        body

      {header, ""} ->
        header

      {header, body} ->
        if header_has_rowspan_to_body do
          header <> "\n" <> body
        else
          header <> "\n" <> header_separator <> "\n" <> body
        end
    end
  end

  defp format_rows_with_rowspans(rows, col_widths, opts) do
    rowspan_matrix = create_rowspan_matrix(rows, length(col_widths))

    0..(length(rows) - 1)
    |> Enum.reduce([], fn row_idx, acc ->
      formatted_row = format_row(Enum.at(rows, row_idx), col_widths, opts)

      if row_idx == 0 do
        [formatted_row | acc]
      else
        row_separator =
          create_row_separator_with_rowspans(row_idx - 1, rows, rowspan_matrix, col_widths)

        [formatted_row, row_separator | acc]
      end
    end)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  defp create_rowspan_matrix(rows, col_count) do
    empty_matrix =
      Enum.map(0..(length(rows) - 1), fn _ -> List.duplicate(:normal, col_count) end)

    rows
    |> Enum.with_index()
    |> Enum.reduce(empty_matrix, &process_row_for_matrix/2)
  end

  defp process_row_for_matrix({row, row_idx}, matrix) do
    Enum.reduce(row, matrix, fn cell, acc_matrix ->
      case cell do
        %{rowspan: rowspan} when rowspan > 1 ->
          update_matrix_for_rowspan(
            acc_matrix,
            row_idx,
            cell.col_start,
            cell.colspan,
            rowspan
          )

        _ ->
          acc_matrix
      end
    end)
  end

  defp update_matrix_for_rowspan(matrix, row_idx, col_start, colspan, rowspan) do
    matrix
    |> mark_rowspan_start(row_idx, col_start, colspan, rowspan)
    |> mark_rowspan_continue(row_idx, col_start, colspan, rowspan)
  end

  defp mark_rowspan_start(matrix, row_idx, col_start, colspan, rowspan) do
    Enum.reduce(0..(colspan - 1), matrix, fn col_offset, acc_matrix ->
      update_in(acc_matrix, [Access.at(row_idx), Access.at(col_start + col_offset)], fn _ ->
        {:rowspan_start, rowspan}
      end)
    end)
  end

  defp mark_rowspan_continue(matrix, row_idx, col_start, colspan, rowspan) do
    Enum.reduce(1..(rowspan - 1), matrix, fn row_offset, acc_matrix ->
      if row_idx + row_offset < length(acc_matrix) do
        update_row_for_rowspan_continue(acc_matrix, row_idx, row_offset, col_start, colspan)
      else
        acc_matrix
      end
    end)
  end

  defp update_row_for_rowspan_continue(matrix, row_idx, row_offset, col_start, colspan) do
    Enum.reduce(0..(colspan - 1), matrix, fn col_offset, inner_acc ->
      update_cell_for_rowspan_continue(inner_acc, row_idx, row_offset, col_start, col_offset)
    end)
  end

  defp update_cell_for_rowspan_continue(matrix, row_idx, row_offset, col_start, col_offset) do
    if col_start + col_offset < length(Enum.at(matrix, row_idx + row_offset)) do
      update_in(
        matrix,
        [Access.at(row_idx + row_offset), Access.at(col_start + col_offset)],
        fn _ -> :rowspan_continue end
      )
    else
      matrix
    end
  end

  defp create_row_separator_with_rowspans(row_idx, rows, rowspan_matrix, col_widths) do
    if row_idx >= length(rows) - 1 do
      ""
    else
      next_row_spans = Enum.at(rowspan_matrix, row_idx + 1)

      next_row_spans
      |> build_separator_parts(col_widths)
      |> apply_rowspan_formatting(next_row_spans, col_widths)
    end
  end

  defp build_separator_parts(next_row_spans, col_widths) do
    {separator_parts, _} =
      Enum.reduce(0..(length(col_widths) - 1), {[], nil}, fn col_idx, {parts, prev_state} ->
        cell_state = Enum.at(next_row_spans, col_idx)
        width = Enum.at(col_widths, col_idx)

        part =
          case {prev_state, cell_state} do
            {_, :rowspan_continue} -> "+" <> String.duplicate(" ", width + 2)
            _ -> "+" <> String.duplicate("-", width + 2)
          end

        {parts ++ [part], cell_state}
      end)

    Enum.join(separator_parts) <> "+"
  end

  defp apply_rowspan_formatting(raw_separator, next_row_spans, col_widths) do
    next_row_spans
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.with_index(fn [a, b], idx ->
      if a == :rowspan_continue && b == :rowspan_continue do
        pos = (idx + 1) * (Enum.at(col_widths, idx) + 3) + idx
        {pos, " "}
      else
        {-1, ""}
      end
    end)
    |> Enum.filter(fn {pos, _} -> pos >= 0 end)
    |> Enum.sort_by(fn {pos, _} -> -pos end)
    |> Enum.reduce(raw_separator, fn {pos, replacement}, acc ->
      String.slice(acc, 0, pos) <>
        replacement <> String.slice(acc, pos + 1, String.length(acc))
    end)
  end

  defp create_header_separator_line(header_rows, col_widths) do
    matrix_row =
      header_rows
      |> List.last()
      |> then(&create_rowspan_matrix([&1], length(col_widths)))
      |> List.first()

    raw_separator =
      col_widths
      |> Enum.with_index(fn width, col_idx ->
        cell_state = Enum.at(matrix_row, col_idx, :normal)

        case cell_state do
          :rowspan_continue ->
            "+" <> String.duplicate(" ", width + 2)

          _ ->
            "+" <> String.duplicate("=", width + 2)
        end
      end)
      |> Enum.join()
      |> then(&(&1 <> "+"))

    matrix_row
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.with_index(fn [a, b], idx ->
      if a == :rowspan_continue && b == :rowspan_continue do
        pos = (idx + 1) * (Enum.at(col_widths, idx) + 3) + idx
        {pos, " "}
      else
        {-1, ""}
      end
    end)
    |> Enum.filter(fn {pos, _} -> pos >= 0 end)
    |> Enum.sort_by(fn {pos, _} -> -pos end)
    |> Enum.reduce(raw_separator, fn {pos, replacement}, acc ->
      String.slice(acc, 0, pos) <> replacement <> String.slice(acc, pos + 1, String.length(acc))
    end)
  end

  defp create_table_line(col_widths, char \\ "-") do
    col_widths
    |> Enum.map_join("+", fn width -> String.duplicate(char, width + 2) end)
    |> (&"+#{&1}+").()
  end

  defp format_row(row_cells, col_widths, _opts) do
    cell_content_map = build_cell_content_map(row_cells, col_widths)
    max_height = calculate_max_height(cell_content_map)

    0..(max_height - 1)
    |> Enum.map(&build_row_line(&1, cell_content_map, col_widths))
    |> Enum.map_join("\n", &format_line(&1, col_widths))
  end

  defp build_cell_content_map(row_cells, col_widths) do
    row_cells
    |> create_primary_content_map(col_widths)
    |> then(&add_colspan_relationships(row_cells, &1))
  end

  defp create_primary_content_map(row_cells, col_widths) do
    Enum.reduce(row_cells, %{}, fn %{
                                     col_start: col_start,
                                     colspan: colspan,
                                     rowspan: rowspan,
                                     content: content
                                   } = _cell,
                                   acc ->
      lines =
        col_start
        |> calculate_total_colspan_width(colspan, col_widths)
        |> Kernel.-(colspan * 2)
        |> then(&process_cell_lines(content, &1))

      cell_map = %{
        lines: lines,
        colspan: colspan,
        rowspan: rowspan,
        height: length(lines),
        is_colspan_start: true
      }

      Map.put(acc, col_start, cell_map)
    end)
  end

  defp process_cell_lines(content, max_width) do
    content
    |> String.split("\n", trim: false)
    |> Enum.flat_map(fn line ->
      if String.length(line) > max_width do
        wrap_text(line, max_width)
      else
        [line]
      end
    end)
  end

  defp add_colspan_relationships(row_cells, primary_map) do
    Enum.reduce(row_cells, primary_map, fn cell, acc ->
      col_start = cell.col_start
      colspan = cell.colspan

      if colspan > 1 do
        add_colspan_references(col_start, colspan, acc)
      else
        acc
      end
    end)
  end

  defp add_colspan_references(col_start, colspan, acc_map) do
    Enum.reduce(1..(colspan - 1), acc_map, fn offset, acc ->
      Map.put(acc, col_start + offset, %{parent_col: col_start})
    end)
  end

  defp wrap_text(text, max_width) do
    if String.length(text) <= max_width do
      [text]
    else
      break_at = find_break_point(text, max_width)
      first_line = String.slice(text, 0, break_at)
      rest = String.slice(text, break_at, String.length(text))

      [first_line | wrap_text(rest, max_width)]
    end
  end

  defp find_break_point(text, max_width) do
    if String.length(text) <= max_width do
      String.length(text)
    else
      last_space =
        text
        |> String.slice(0, max_width)
        |> String.reverse()
        |> :binary.match(" ")
        |> case do
          {pos, _} -> max_width - pos
          :nomatch -> max_width
        end

      if last_space < max_width * 0.5, do: max_width, else: last_space
    end
  end

  defp calculate_max_height(cell_content_map) do
    cell_content_map
    |> Map.values()
    |> Enum.filter(&Map.has_key?(&1, :height))
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
        {nil, 1, :empty}

      %{parent_col: parent_col} ->
        {nil, 1, {:covered_by, parent_col}}

      %{lines: lines, colspan: colspan} ->
        content = if row_idx < length(lines), do: Enum.at(lines, row_idx), else: ""
        {content, colspan, :content}
    end
  end

  defp format_line(line_cells, col_widths) do
    {line_str, _processed_cols} =
      Enum.reduce(0..(length(line_cells) - 1), {"", MapSet.new()}, fn col_idx,
                                                                      {line, processed} ->
        if MapSet.member?(processed, col_idx) do
          {line, processed}
        else
          cell_info = Enum.at(line_cells, col_idx)
          format_cell_for_line(cell_info, col_idx, col_widths, line, processed)
        end
      end)

    line_str <> "|"
  end

  defp format_cell_for_line(cell_info, col_idx, col_widths, line, processed) do
    case cell_info do
      {nil, _, :empty} ->
        width = Enum.at(col_widths, col_idx, @default_min_col_width)
        {line <> "| " <> String.pad_trailing("", width) <> " ", processed}

      {_, _, {:covered_by, _}} ->
        {line, processed}

      {content, colspan, :content} when colspan > 1 ->
        format_colspan_cell(content, col_idx, colspan, col_widths, line, processed)

      {content, 1, :content} ->
        width = Enum.at(col_widths, col_idx, @default_min_col_width)
        {line <> "| " <> String.pad_trailing(content || "", width) <> " ", processed}

      _ ->
        width = Enum.at(col_widths, col_idx, @default_min_col_width)
        {line <> "| " <> String.pad_trailing("", width) <> " ", processed}
    end
  end

  defp format_colspan_cell(content, col_idx, colspan, col_widths, line, processed) do
    total_width = calculate_total_colspan_width(col_idx, colspan, col_widths)

    new_processed =
      Enum.reduce(1..(colspan - 1), processed, fn offset, acc ->
        MapSet.put(acc, col_idx + offset)
      end)

    {line <> "| " <> String.pad_trailing(content || "", total_width) <> " ", new_processed}
  end

  defp calculate_total_colspan_width(start_col, colspan, col_widths) do
    span_widths = Enum.slice(col_widths, start_col, colspan)
    col_width_sum = Enum.sum(span_widths)

    col_width_sum + (colspan - 1) * 3
  end

  defp convert_pandoc_table_cell(%{"type" => "tableHeaderCell", "content" => content}, opts) do
    content
    |> Enum.map_join("", fn item -> process_cell_content_item(item, opts) end)
    |> String.trim_trailing()
  end

  defp convert_pandoc_table_cell(%{"type" => "tableCell", "content" => content}, opts) do
    content
    |> Enum.map_join("", fn item -> process_cell_content_item(item, opts) end)
    |> String.trim_trailing()
  end

  defp convert_pandoc_table_cell(%{"type" => _cell_type, "content" => content}, opts) do
    content
    |> Enum.map_join("", fn item -> process_cell_content_item(item, opts) end)
    |> String.trim_trailing()
  end

  defp convert_pandoc_table_cell(%{"type" => _}, _opts), do: ""

  defp process_cell_content_item(%{"type" => "paragraph", "content" => para_content}, opts) do
    text = Enum.map_join(para_content, "", fn item -> process_paragraph_item(item, opts) end)
    if String.trim(text) == "", do: "", else: text <> "\n"
  end

  defp process_cell_content_item(%{"type" => "paragraph"}, _opts), do: "\n"

  defp process_cell_content_item(
         %{"type" => "bulletList", "content" => content, "attrs" => attrs},
         opts
       ) do
    prefix =
      case attrs do
        %{"kind" => "ordered"} -> "1. "
        _ -> "- "
      end

    content
    |> Enum.map_join("\n", fn item ->
      prefix <> convert_node(item, opts)
    end)
    |> then(&(&1 <> "\n"))
  end

  defp process_cell_content_item(%{"type" => "hardBreak"}, _opts), do: "\n"

  defp process_cell_content_item(item, opts), do: convert_node(item, opts)

  defp process_paragraph_item(%{"type" => "text", "text" => text, "marks" => marks}, opts),
    do: Enum.reduce(Enum.reverse(marks), text, &convert_mark(&2, &1, opts))

  defp process_paragraph_item(%{"type" => "hardBreak"}, _opts), do: "\n"
  defp process_paragraph_item(item, opts), do: convert_node(item, opts)

  defp filter_table_controller_cells(cells),
    do: Enum.reject(cells, &match?(%{"type" => "tableControllerCell"}, &1))
end

defmodule InvalidJsonError do
  defexception [:message]
end
