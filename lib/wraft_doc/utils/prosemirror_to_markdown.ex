defmodule WraftDoc.Utils.ProsemirrorToMarkdown do
  @moduledoc """
  Prosemirror2Md is a library that converts ProseMirror Node JSON to Markdown.
  """

  alias WraftDoc.Utils.StringHelper

  @doc """
  Converts a ProseMirror Node JSON to Markdown.

  Supports conditional blocks that are conditionally included based on field values.
  Conditional blocks have the structure:
  ```json
  {
    "type": "conditionalBlock",
    "attrs": {
      "conditions": [
        {
          "placeholder": "field_name",
          "operation": "equal",
          "value": "expected_value",
          "logic": "and"  // optional, defaults to "and"
        }
      ]
    },
    "content": [...]
  }
  ```

  Supported operations: equal, not_equal, like, not_like, greater_than,
  greater_than_or_equal, less_than, less_than_or_equal

  The "logic" field on each condition (except the first) specifies how to combine
  with the previous result: "and" (default) or "or".

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

  @spec convert(map(), keyword()) :: String.t()
  def convert(%{"type" => "doc", "content" => content}, opts \\ []) do
    Enum.map_join(content, "\n\n", &convert_node(&1, opts))
  end

  defp convert_node(
         %{
           "type" => "conditionalBlock",
           "attrs" => attrs,
           "content" => content
         },
         opts
       )
       when is_map(attrs) do
    field_values = Keyword.get(opts, :field_values, %{})
    conditions = Map.get(attrs, "conditions", [])

    if evaluate_conditions(conditions, field_values) do
      Enum.map_join(content, "\n\n", &convert_node(&1, opts))
    else
      ""
    end
  end

  defp convert_node(
         %{"type" => "conditionalBlock", "content" => content},
         opts
       ) do
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

  defp convert_node(%{"type" => "holder", "attrs" => attrs} = _node, opts) do
    field_values = Keyword.get(opts, :field_values, %{})
    machine_name = Map.get(attrs, "machineName") || Map.get(attrs, "machine_name")
    name = Map.get(attrs, "name")

    value = get_holder_value(field_values, machine_name, name)
    format_holder_output(value, name)
  end

  defp convert_node(%{"type" => "holder"}, _opts),
    do: raise(InvalidJsonError, "Invalid holder format.")

  defp convert_node(
         %{
           "type" => "smartTableWrapper",
           "attrs" => %{"tableName" => table_name},
           "content" => [_ | _] = content
         },
         opts
       ) do
    case Enum.find(content, &(&1["type"] == "table")) do
      %{"type" => "table"} = table ->
        convert_node(table, opts)

      nil ->
        "[SMART_TABLE_PLACEHOLDER:#{table_name}]"
    end
  end

  defp convert_node(
         %{
           "type" => "smartTableWrapper",
           "content" => [],
           "attrs" => %{"tableName" => table_name}
         } = _node,
         _opts
       ) do
    "[SMART_TABLE_PLACEHOLDER:#{table_name}]"
  end

  defp convert_node(
         %{"type" => "smartTableWrapper", "attrs" => %{"tableName" => table_name}},
         _opts
       ) do
    "[SMART_TABLE_PLACEHOLDER:#{table_name}]"
  end

  defp convert_node(%{"type" => "table", "content" => rows} = _table, opts) when is_list(rows) do
    process_table(rows, opts)
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

  defp get_holder_value(field_values, machine_name, name) do
    cond do
      machine_name && Map.has_key?(field_values, machine_name) ->
        value = Map.get(field_values, machine_name)
        if value != nil, do: value, else: try_name_lookup(field_values, name)

      name ->
        try_name_lookup(field_values, name)

      true ->
        nil
    end
  end

  defp try_name_lookup(field_values, name) when is_binary(name) do
    if Map.has_key?(field_values, name) do
      Map.get(field_values, name)
    else
      converted_name = StringHelper.convert_to_variable_name(name)
      Map.get(field_values, converted_name)
    end
  end

  defp try_name_lookup(_field_values, _name), do: nil

  defp format_holder_output(nil, nil), do: " [holder] "
  defp format_holder_output(nil, name), do: " [#{name}] "
  defp format_holder_output(value, _name), do: "  #{value}  "

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

  defp process_table(rows, opts) do
    {grid, max_row, max_col} = build_grid(rows, opts)

    if max_row == -1 do
      "++\n++"
    else
      col_widths = calc_col_widths(grid, max_row, max_col)
      wrapped_grid = wrap_content(grid, max_row, max_col, col_widths)
      row_heights = calc_row_heights(wrapped_grid, max_row, max_col)
      has_header? = rows != [] and has_header_cells?(Enum.at(rows, 0))

      render_table(wrapped_grid, max_row, max_col, col_widths, row_heights, has_header?)
    end
  end

  defp has_header_cells?(%{"content" => cells}) do
    Enum.any?(cells, &(&1["type"] == "tableHeaderCell"))
  end

  defp has_header_cells?(_), do: false

  defp build_grid(rows, opts) do
    {grid, _tracker, max_r, max_c} =
      Enum.reduce(rows, {%{}, %{}, -1, -1}, fn row, {g, tracker, mr, mc} ->
        cells = filter_cells(row["content"] || [])
        r = mr + 1

        {g, tracker, _, new_mc} =
          Enum.reduce(cells, {g, tracker, 0, mc}, fn cell, {g_acc, tr_acc, c_idx, max_c_acc} ->
            c_idx = find_next_col(tr_acc, r, c_idx)

            attrs = cell["attrs"] || %{}
            colspan = attrs["colspan"] || 1
            rowspan = attrs["rowspan"] || 1
            colwidth = attrs["colwidth"]

            content = convert_cell(cell, opts)

            cell_data = %{
              content: content,
              rowspan: rowspan,
              colspan: colspan,
              colwidth: colwidth,
              primary: true
            }

            new_g = Map.put(g_acc, {r, c_idx}, cell_data)

            {next_g, next_tr} = insert_spans(new_g, tr_acc, r, c_idx, rowspan, colspan)

            {next_g, next_tr, c_idx + colspan, max(max_c_acc, c_idx + colspan - 1)}
          end)

        {g, tracker, r, new_mc}
      end)

    {grid, max_r, max_c}
  end

  defp filter_cells(cells), do: Enum.reject(cells, &(&1["type"] == "tableControllerCell"))

  defp find_next_col(tracker, r, c) do
    if Map.has_key?(tracker, {r, c}) do
      find_next_col(tracker, r, c + 1)
    else
      c
    end
  end

  defp insert_spans(grid, tracker, r, c, rowspan, colspan) do
    Enum.reduce(0..(rowspan - 1), {grid, tracker}, &insert_span_row(&1, &2, r, c, colspan))
  end

  defp insert_span_row(ro, {g, tr}, r, c, colspan) do
    Enum.reduce(0..(colspan - 1), {g, tr}, &insert_span_cell(&1, &2, r, c, ro))
  end

  defp insert_span_cell(co, {gg, ttr}, r, c, ro) do
    if ro == 0 and co == 0 do
      {gg, Map.put(ttr, {r + ro, c + co}, true)}
    else
      covered = %{primary: false, parent: {r, c}}
      {Map.put(gg, {r + ro, c + co}, covered), Map.put(ttr, {r + ro, c + co}, true)}
    end
  end

  defp convert_cell(%{"content" => content}, opts) do
    (content || [])
    |> Enum.map_join("", &convert_cell_item(&1, opts))
    |> String.trim_trailing()
  end

  defp convert_cell(_, _), do: ""

  defp convert_cell_item(%{"type" => "paragraph", "content" => pc}, opts) do
    text = Enum.map_join(pc || [], "", &convert_paragraph_content(&1, opts))
    if String.trim(text) == "", do: "", else: text <> "\n"
  end

  defp convert_cell_item(%{"type" => "paragraph"}, _opts), do: "\n"

  defp convert_cell_item(%{"type" => "bulletList", "content" => bc, "attrs" => attrs}, opts) do
    prefix = if attrs["kind"] == "ordered", do: "1. ", else: "- "

    (bc || [])
    |> Enum.map_join("\n", fn i -> prefix <> convert_node(i, opts) end)
    |> Kernel.<>("\n")
  end

  defp convert_cell_item(%{"type" => "hardBreak"}, _opts), do: "\n"

  defp convert_cell_item(node, opts), do: convert_node(node, opts)

  defp convert_paragraph_content(%{"type" => "text", "text" => text, "marks" => marks}, opts) do
    Enum.reduce(Enum.reverse(marks || []), text, fn mark, acc ->
      convert_mark(acc, mark, opts)
    end)
  end

  defp convert_paragraph_content(%{"type" => "hardBreak"}, _opts), do: "\n"

  defp convert_paragraph_content(node, opts), do: convert_node(node, opts)

  defp calc_col_widths(grid, _max_row, max_col) do
    Enum.map(0..max_col, fn c ->
      case Map.get(grid, {0, c}) do
        %{primary: true, colwidth: [w | _], colspan: 1} when is_integer(w) -> w
        %{primary: true, colwidth: [w | _], colspan: span} when is_integer(w) -> div(w, span)
        _ -> @default_min_col_width
      end
    end)
  end

  defp calc_total_width(col_widths, start_c, colspan) do
    widths = Enum.map(0..(colspan - 1), &Enum.at(col_widths, start_c + &1))
    Enum.sum(widths) + (colspan - 1) * 3
  end

  defp wrap_content(grid, max_row, max_col, col_widths) do
    Enum.reduce(0..max_row, grid, fn r, g ->
      Enum.reduce(0..max_col, g, &wrap_cell(r, &1, &2, col_widths))
    end)
  end

  defp wrap_cell(r, c, gg, col_widths) do
    case Map.get(gg, {r, c}) do
      %{primary: true, content: text, colspan: span} = cell ->
        width = calc_total_width(col_widths, c, span)

        lines =
          text
          |> String.split("\n")
          |> Enum.flat_map(&do_wrap(&1, width))

        Map.put(gg, {r, c}, Map.put(cell, :lines, lines))

      _ ->
        gg
    end
  end

  defp do_wrap(text, max_w) do
    if String.length(text) <= max_w do
      [text]
    else
      idx = find_break_idx(text, max_w)
      [String.slice(text, 0, idx) | do_wrap(String.slice(text, idx..-1//1), max_w)]
    end
  end

  defp find_break_idx(text, max_w) do
    prefix = String.slice(text, 0, max_w)

    case reversed_space_idx(prefix) do
      nil ->
        max_w

      pos ->
        if max_w - pos < max_w * 0.5 do
          max_w
        else
          max_w - pos
        end
    end
  end

  defp reversed_space_idx(str) do
    str
    |> String.reverse()
    |> :binary.match(" ")
    |> case do
      {pos, _} -> pos
      :nomatch -> nil
    end
  end

  defp calc_row_heights(grid, max_row, max_col) do
    Enum.map(0..max_row, fn r ->
      Enum.reduce(0..max_col, 1, &update_max_height(grid, r, &1, &2))
    end)
  end

  defp update_max_height(grid, r, c, max_h) do
    case Map.get(grid, {r, c}) do
      %{primary: true, lines: lines} -> max(max_h, length(lines))
      _ -> max_h
    end
  end

  defp render_table(grid, max_row, max_col, col_widths, row_heights, has_header?) do
    top_border = render_separator(grid, -1, max_col, col_widths, char: "-")

    body =
      Enum.map_join(
        0..max_row,
        "\n",
        &render_row_with_separator(
          grid,
          &1,
          max_row,
          max_col,
          col_widths,
          row_heights,
          has_header?
        )
      )

    top_border <> "\n" <> body
  end

  defp render_row_with_separator(grid, r, max_row, max_col, col_widths, row_heights, has_header?) do
    height = Enum.at(row_heights, r)

    row_lines =
      Enum.map_join(0..(height - 1), "\n", fn line_idx ->
        render_text_line(grid, r, max_col, col_widths, line_idx)
      end)

    separator =
      if r == max_row do
        render_separator(grid, r, max_col, col_widths, char: "-")
      else
        char = if has_header? and r == 0, do: "=", else: "-"
        render_separator(grid, r, max_col, col_widths, char: char)
      end

    row_lines <> "\n" <> separator
  end

  defp render_text_line(grid, r, max_col, col_widths, line_idx) do
    Enum.reduce(0..max_col, "", &append_cell_text(grid, r, &1, &2, col_widths, line_idx)) <> "|"
  end

  defp append_cell_text(grid, r, c, acc, col_widths, line_idx) do
    case Map.get(grid, {r, c}) do
      %{primary: false, parent: {pr, _pc}} ->
        if pr == r do
          acc
        else
          width = Enum.at(col_widths, c)
          acc <> "| " <> String.duplicate(" ", width) <> " "
        end

      %{primary: true, lines: lines, colspan: span} ->
        width = calc_total_width(col_widths, c, span)
        text = if line_idx < length(lines), do: Enum.at(lines, line_idx), else: ""
        acc <> "| " <> String.pad_trailing(text, width) <> " "

      nil ->
        width = Enum.at(col_widths, c)
        acc <> "| " <> String.duplicate(" ", width) <> " "
    end
  end

  defp render_separator(grid, r, max_col, col_widths, opts) do
    char = Keyword.get(opts, :char, "-")

    Enum.reduce(0..max_col, "", &append_separator_cell(grid, r, &1, &2, col_widths, char)) <> "+"
  end

  defp append_separator_cell(grid, r, c, acc, col_widths, char) do
    width = Enum.at(col_widths, c)
    state = determine_separator_state(grid, r, c)
    fill_char = if state == :continue, do: " ", else: char
    acc <> "+" <> String.duplicate(fill_char, width + 2)
  end

  defp determine_separator_state(_grid, r, _c) when r < 0, do: :normal

  defp determine_separator_state(grid, r, c) do
    case Map.get(grid, {r, c}) do
      %{primary: true, rowspan: rs} when rs > 1 ->
        :continue

      %{primary: false, parent: {pr, _}} when pr < r + 1 ->
        check_parent_rowspan(grid, r + 1, c, r)

      _ ->
        :normal
    end
  end

  defp check_parent_rowspan(grid, next_r, c, r) do
    case Map.get(grid, {next_r, c}) do
      %{primary: false, parent: {bpr, _}} when bpr <= r -> :continue
      _ -> :normal
    end
  end

  @doc false
  @spec evaluate_conditions(list(), map()) :: boolean()
  defp evaluate_conditions(conditions, field_values) when is_list(conditions) do
    evaluate_conditions_with_logic(conditions, field_values)
  end

  defp evaluate_conditions(_, _), do: false

  # Empty conditions list returns true (block is always included)
  # This allows conditional blocks without conditions to always render
  @spec evaluate_conditions_with_logic(list(), map()) :: boolean()
  defp evaluate_conditions_with_logic([], _field_values), do: true

  @spec evaluate_conditions_with_logic(list(), map()) :: boolean()
  defp evaluate_conditions_with_logic([first | rest], field_values) do
    first_result = evaluate_single_condition(first, field_values)
    evaluate_conditions_with_logic(rest, first_result, field_values)
  end

  @spec evaluate_conditions_with_logic(list(), boolean(), map()) :: boolean()
  defp evaluate_conditions_with_logic([], acc, _field_values), do: acc

  # Each condition's "logic" field specifies how to combine with the previous result.
  # The first condition is evaluated alone, subsequent conditions use their "logic"
  # field to combine with the accumulated result.
  @spec evaluate_conditions_with_logic(list(), boolean(), map()) :: boolean()
  defp evaluate_conditions_with_logic(
         [condition | rest],
         acc,
         field_values
       ) do
    condition_result = evaluate_single_condition(condition, field_values)
    logic = Map.get(condition, "logic", "and")

    new_acc =
      case logic do
        "or" -> acc || condition_result
        _ -> acc && condition_result
      end

    evaluate_conditions_with_logic(rest, new_acc, field_values)
  end

  @spec evaluate_single_condition(map(), map()) :: boolean()
  defp evaluate_single_condition(
         %{"placeholder" => placeholder, "operation" => operation, "value" => value} = condition,
         field_values
       ) do
    machine_name = Map.get(condition, "machineName") || Map.get(condition, "machine_name")
    field_value = get_field_value_with_machine_name(machine_name, placeholder, field_values)
    compare_values(field_value, operation, value)
  end

  defp evaluate_single_condition(_, _), do: false

  @spec get_field_value_with_machine_name(String.t() | nil, String.t(), map()) :: String.t()
  defp get_field_value_with_machine_name(machine_name, placeholder, field_values)
       when is_map(field_values) do
    value =
      cond do
        machine_name && Map.has_key?(field_values, machine_name) ->
          field_val = Map.get(field_values, machine_name)

          if field_val != nil,
            do: field_val,
            else: try_placeholder_lookup(field_values, placeholder)

        Map.has_key?(field_values, placeholder) ->
          field_val = Map.get(field_values, placeholder)
          if field_val != nil, do: field_val, else: try_converted_name(field_values, placeholder)

        true ->
          try_converted_name(field_values, placeholder)
      end

    to_string(value)
  end

  defp get_field_value_with_machine_name(_, _, _), do: ""

  defp try_placeholder_lookup(field_values, placeholder) do
    case Map.get(field_values, placeholder) do
      nil -> try_converted_name(field_values, placeholder)
      val -> val
    end
  end

  defp try_converted_name(field_values, placeholder) do
    converted_name = StringHelper.convert_to_variable_name(placeholder)
    Map.get(field_values, converted_name, "")
  end

  @spec compare_values(any(), String.t(), any()) :: boolean()
  defp compare_values(field_value, operation, expected_value) do
    field_str = String.trim(to_string(field_value))
    expected_str = String.trim(to_string(expected_value))
    do_compare(operation, field_str, expected_str)
  end

  defp do_compare("equal", field_str, expected_str), do: compare_equal(field_str, expected_str)

  defp do_compare("not_equal", field_str, expected_str),
    do: compare_not_equal(field_str, expected_str)

  defp do_compare("like", field_str, expected_str), do: compare_like(field_str, expected_str)

  defp do_compare("not_like", field_str, expected_str),
    do: compare_not_like(field_str, expected_str)

  defp do_compare("greater_than", field_str, expected_str),
    do: compare_numeric(field_str, expected_str, :>)

  defp do_compare("greater_than_or_equal", field_str, expected_str),
    do: compare_numeric(field_str, expected_str, :>=)

  defp do_compare("less_than", field_str, expected_str),
    do: compare_numeric(field_str, expected_str, :<)

  defp do_compare("less_than_or_equal", field_str, expected_str),
    do: compare_numeric(field_str, expected_str, :<=)

  defp do_compare(_, _, _), do: false

  defp compare_equal(field_str, expected_str) do
    String.downcase(field_str) == String.downcase(expected_str)
  end

  defp compare_not_equal(field_str, expected_str) do
    String.downcase(field_str) != String.downcase(expected_str)
  end

  defp compare_like(field_str, expected_str) do
    String.contains?(String.downcase(field_str), String.downcase(expected_str))
  end

  defp compare_not_like(field_str, expected_str) do
    not String.contains?(String.downcase(field_str), String.downcase(expected_str))
  end

  defp compare_numeric(field_str, expected_str, op) do
    case {parse_number(field_str), parse_number(expected_str)} do
      {{:ok, field_num}, {:ok, expected_num}} ->
        apply_numeric_operator(field_num, expected_num, op)

      _ ->
        apply_string_operator(field_str, expected_str, op)
    end
  end

  defp apply_numeric_operator(field_num, expected_num, op) do
    case op do
      :> -> field_num > expected_num
      :>= -> field_num >= expected_num
      :< -> field_num < expected_num
      :<= -> field_num <= expected_num
    end
  end

  defp apply_string_operator(field_str, expected_str, op) do
    case op do
      :> -> field_str > expected_str
      :>= -> field_str >= expected_str
      :< -> field_str < expected_str
      :<= -> field_str <= expected_str
    end
  end

  @spec parse_number(String.t()) :: {:ok, float()} | :error
  defp parse_number(str) do
    case Float.parse(str) do
      {num, _} -> {:ok, num}
      :error -> :error
    end
  end
end

defmodule InvalidJsonError do
  defexception [:message]
end
