defmodule WraftDoc.YEcto do
  defmacro __using__(opts) do
    repo = opts[:repo]
    schema = opts[:schema]

    quote do
      import Ecto.Query

      @repo unquote(repo)
      @schema unquote(schema)

      @flush_size 100

      def get_y_doc(content_id) do
        ydoc = Yex.Doc.new()
        updates = get_updates(content_id)

        map = Yex.Doc.get_map(ydoc, "doc-initial")

        Yex.Doc.transaction(ydoc, fn ->
          Enum.each(updates, fn update ->
            Yex.apply_update(ydoc, update.value)
          end)
        end)

        if length(updates) > 0 do
          Yex.Map.delete(map, "initialLoad")
        else
          Yex.Map.set(map, "initialLoad", "true")
        end

        if length(updates) > @flush_size do
          {:ok, u} = Yex.encode_state_as_update(ydoc)
          {:ok, sv} = Yex.encode_state_vector(ydoc)
          clock = List.last(updates, nil).inserted_at
          flush_document(content_id, u, sv, clock)
        end

        ydoc
      end

      def insert_update(content_id, value) do
        @repo.insert(%@schema{content_id: content_id, value: value, version: :v1})
      end

      def get_state_vector(content_id) do
        query =
          from(y in @schema,
            where: y.content_id == ^content_id and y.version == :v1_sv,
            select: y
          )

        @repo.one(query)
      end

      def get_diff(content_id, sv) do
        doc = get_y_doc(content_id)
        Yex.encode_state_as_update(doc, sv)
      end

      def clear_document(content_id) do
        query =
          from(y in @schema,
            where: y.content_id == ^content_id
          )

        @repo.delete_all(query)
      end

      defp put_state_vector(content_id, state_vector) do
        case get_state_vector(content_id) do
          nil -> %@schema{content_id: content_id, version: :v1_sv}
          state_vector -> state_vector
        end
        |> @schema.changeset(%{value: state_vector})
        |> @repo.insert_or_update()
      end

      defp get_updates(content_id) do
        query =
          from(y in @schema,
            where: y.content_id == ^content_id and y.version == :v1,
            select: y,
            order_by: y.inserted_at
          )

        @repo.all(query)
      end

      defp flush_document(content_id, updates, sv, clock) do
        @repo.insert(%@schema{content_id: content_id, value: updates, version: :v1})
        put_state_vector(content_id, sv)
        clear_updates_to(content_id, clock)
      end

      defp clear_updates_to(content_id, to) do
        query =
          from(y in @schema,
            where: y.content_id == ^content_id and y.inserted_at < ^to
          )

        @repo.delete_all(query)
      end
    end
  end
end
