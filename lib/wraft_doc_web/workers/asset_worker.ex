defmodule WraftDocWeb.Worker.AssetWorker do
  use Oban.Worker, queue: :scheduled
  @impl Oban.Worker
  import Ecto.Query
  alias WraftDoc.{Repo, Document.Asset, Document.LayoutAsset}

  def perform(_args, _job) do
    IO.puts("Job started..!")

    from(a in Asset,
      left_join: la in LayoutAsset,
      on: la.asset_id == a.id,
      where: is_nil(la.asset_id)
    )
    |> Repo.all()
    |> Stream.map(fn x -> Repo.delete(x) end)
    |> Enum.to_list()

    IO.puts("Job finished..!")
    :ok
  end
end
