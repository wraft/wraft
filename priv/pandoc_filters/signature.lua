local function px_to_cm(px)
    return string.format("%.2f", px * 2.54 / 96)
end

local function px_to_pt(px)
    return string.format("%.2f", px * 0.75)
end

function Para(el)
    local text = pandoc.utils.stringify(el)

    if text:match("%[SIGNATURE_FIELD_PLACEHOLDER") then
        local width = tonumber(text:match("width:(%d+)"))
        local height = tonumber(text:match("height:(%d+)"))
        if not width or not height then return el end

        local width_cm = px_to_cm(width)
        local height_cm = px_to_cm(height)

        local width_pt = px_to_pt(width)
        local height_pt = px_to_pt(height)

        local latex_code = string.format("\\sigField[\\BC{0 0 0}]{signatureField}{%scm}{%scm}", width_cm, height_cm)
        local typst_code = string.format([[
    #rect(
      stroke: rgb(0, 184, 148),
      width: %spt,
      height: %spt,
      fill: rgb(214, 255, 244)
    )
    ]], width_pt, height_pt)

        return pandoc.Para({
            pandoc.RawInline("latex", latex_code),
            pandoc.RawInline("typst", typst_code),
        })
    end

    return el
end
