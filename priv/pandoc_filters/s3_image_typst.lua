local base_url = os.getenv("BACKEND_URL") or "http://localhost:4000"
local image_folder = os.getenv("PWD") .. "/organisations/images/"
local image_map = {}
local document_path = ""

-- TODO: Set up document path from metadata
-- currently i can retrieve the path from the metadata cant be used by image_folder.
-- function Meta(meta)
--   if meta.path then
--     document_path = pandoc.utils.stringify(meta.path)  -- Convert metadata to string
--     _G.image_folder = document_path .. "/images/"

--     os.execute("mkdir -p " .. image_folder)
--   end
--   return meta
-- end

local function detect_file_type(data)
    if not data or #data < 8 then
        return "png"
    end

    local image_signatures = {
        { pattern = { 137, 80, 78, 71 }, ext = "png" },
        { pattern = { 255, 216, 255 }, ext = "jpg" },
        { pattern = { 71, 73, 70, 56 }, ext = "gif" },
        { pattern = { 82, 73, 70, 70 }, ext = "webp" },
        { pattern = { 66, 77 },        ext = "bmp" }
    }

    -- Check each image signature pattern
    for _, sig in ipairs(image_signatures) do
        local match = true
        for i, byte in ipairs(sig.pattern) do
            if string.byte(data, i) ~= byte then
                match = false
                break
            end
        end
        if match then
            return sig.ext
        end
    end

    if data:match("^%s*<%?xml") or data:match("^%s*<svg") then
        return "svg"
    end

    return "png"
end

-- Function to construct full path for image storage
local function get_storage_path(filename, ext)
    return image_folder .. filename .. "." .. ext
end

-- Unified Image Processing Function
function Image(img)
    if img.src:match("^/asset/image/") then
        local uuid = img.src:match("/asset/image/([^{}]+)")

        -- Form the full URL if it's not already a URL
        local full_url
        if not img.src:match("^https?://") then
            full_url = base_url .. img.src
        else
            full_url = img.src
        end

        if full_url:match(base_url .. "/asset/image/") then
            local temp_path = image_folder .. "temp_" .. uuid

            os.execute("curl -s -L -o " .. temp_path .. " " .. full_url)

            -- Detect file type
            local file = io.open(temp_path, "rb")
            if file then
                local data = file:read(32)
                file:close()

                local ext = detect_file_type(data)
                local final_path = get_storage_path("img_" .. uuid, ext)

                os.execute("cp " .. temp_path .. " " .. final_path)

                img.src = final_path
            else
                img.src = temp_path
            end
        else
            img.src = full_url
        end

        return img
    end
end
