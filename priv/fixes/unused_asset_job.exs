%{}
|> WraftDocWeb.Worker.AssetWorker.new(tags: ["unused_assets"], queue: "scheduled")
|> Oban.insert()
