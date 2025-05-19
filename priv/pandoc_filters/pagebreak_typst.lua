function RawBlock(el)
    if el.text:match("\\newpage") or el.text:match("\\pagebreak") then
        return pandoc.RawBlock("typst", "#pagebreak()")
    end
end
