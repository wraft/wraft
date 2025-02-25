function Image(img)
    local base_url = os.getenv("BASE_URL") or "http://127.0.0.1:4000/"

    -- If the image path starts with "/asset/image/", modify it
    if img.src:match("^/asset/image/") then
      print("🌍 S3 Image Detected: " .. img.src)
      img.src = base_url .. img.src
    end

    return img
end
