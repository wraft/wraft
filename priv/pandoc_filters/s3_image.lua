-- Global variable to store the base URL
base_url = "http://127.0.0.1:4000/"  -- Fallback value

-- Function to extract metadata
function Meta(meta)
  if meta.base_url then
      base_url = pandoc.utils.stringify(meta.base_url)
      print("🌍 Base URL Set to:", base_url)
  end
end

function Image(img)
    -- If the image path starts with "/asset/image/", modify it
    if img.src:match("^/asset/image/") then
      print("🌍 S3 Image Detected: " .. img.src)
      img.src = base_url .. img.src
    end

    return img
end
