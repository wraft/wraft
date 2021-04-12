%{}
|> WraftDocWeb.Worker.ScheduledWorker.new(tags: ["unused_assets"], queue: "scheduled")
|> Oban.insert()
