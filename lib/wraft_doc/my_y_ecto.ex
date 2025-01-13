defmodule WraftDoc.MyYEcto do
  use WraftDoc.YEcto, repo: WraftDoc.Repo, schema: WraftDoc.YjsWritings
end

defmodule WraftDoc.EctoPersistence do
  @behaviour Yex.Sync.SharedDoc.PersistenceBehaviour
  @impl true
  def bind(_state, content_id, doc) do
    ecto_doc = WraftDoc.MyYEcto.get_y_doc(content_id)

    {:ok, new_updates} = Yex.encode_state_as_update(doc)

    WraftDoc.MyYEcto.insert_update(content_id, new_updates)

    Yex.apply_update(doc, Yex.encode_state_as_update!(ecto_doc))
  end

  @impl true
  def unbind(_state, _content_id, _doc) do
  end

  @impl true
  def update_v1(_state, update, content_id, _doc) do
    WraftDoc.MyYEcto.insert_update(content_id, update)
    :ok
  end
end
