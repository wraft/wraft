base_url = os.getenv("BACKEND_URL") or "http://localhost:4000"


function Image(img)
  if img.src:match("^/asset/image/") then
    if not img.src:match("^https?://") then
        img.src = base_url .. img.src
    end
  end
  print("🌍 S3 Image public:" .. img.src)
  return img
end
