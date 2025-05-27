-- This filter is used to format listing in table cell as a hack

function Table(table)
  if FORMAT ~= "typst" then
    return table
  end

  for _, body in ipairs(table.bodies) do
    for _, row in ipairs(body.body) do
      for _, cell in ipairs(row.cells) do
        cell.contents = fixCellContents(cell.contents)
      end
    end
  end

  if table.head and table.head.rows then
    for _, row in ipairs(table.head.rows) do
      for _, cell in ipairs(row.cells) do
        cell.contents = fixCellContents(cell.contents)
      end
    end
  end

  return table
end

function fixCellContents(blocks)
  local newBlocks = {}

  for _, block in ipairs(blocks) do
    if block.tag == "OrderedList" then
      local listItems = {}
      for i, item in ipairs(block.content) do
        local itemText = pandoc.utils.stringify(item)
        table.insert(listItems, i .. ". " .. itemText)
      end

      local typstContent = table.concat(listItems, " \\\n")
      local rawBlock = pandoc.RawBlock("typst", typstContent)
      table.insert(newBlocks, rawBlock)

    elseif block.tag == "BulletList" then
      local listItems = {}
      for _, item in ipairs(block.content) do
        local itemText = pandoc.utils.stringify(item)
        table.insert(listItems, "• " .. itemText)
      end

      local typstContent = table.concat(listItems, " \\\n")
      local rawBlock = pandoc.RawBlock("typst", typstContent)
      table.insert(newBlocks, rawBlock)

    else
      table.insert(newBlocks, block)
    end
  end

  return newBlocks
end
