defmodule WraftDoc.YDocuments.YEcto do
  @moduledoc """
  Yex Ecto - Handles Y.js document persistence with auto-save functionality
  """

  defmacro __using__(opts) do
    repo = opts[:repo]
    schema = opts[:schema]

    quote do
      import Ecto.Query
      alias WraftDoc.Documents.Instance
      alias WraftDoc.Utils.XmlToProseMirror
      alias WraftDoc.Utils.ProsemirrorToMarkdown
      require Logger

      @repo unquote(repo)
      @schema unquote(schema)

      @flush_size 100
      @save_debounce_ms_idle 6_000  # 6 seconds when user stops typing
      @max_save_interval 60_000  # Maximum 60 seconds between saves

      # Start the auto-save supervisor if not already started
      def start_auto_save_supervisor do
        case Process.whereis(WraftDoc.AutoSaveSupervisor) do
          nil ->
            {:ok, pid} = WraftDoc.AutoSaveSupervisor.start_link()
            pid
          pid -> pid
        end
      end

      @doc """
      Gets or creates a Y.js document for the given content_id.
      Loads existing updates and initializes with saved content if available.
      """
      def get_y_doc(content_id) do
        ydoc = Yex.Doc.new()
        updates = get_updates(content_id)
        map = Yex.Doc.get_map(ydoc, "doc-initial")

        Yex.Doc.transaction(ydoc, fn ->
          Enum.each(updates, fn update ->
            Yex.apply_update(ydoc, update.value)
          end)
        end)

        if length(updates) == 0 do
          Logger.info("Loading initial content for document #{content_id}")

          case @repo.get(Instance, content_id) do
            %Instance{serialized: %{"serialized" => serialized}} when not is_nil(serialized) ->
              case Jason.decode(serialized) do
                {:ok, prosemirror_json} ->
                  prelim = Yex.MapPrelim.from(prosemirror_json)
                  Yex.Map.set(map, "content", prelim)

                error ->
                  Logger.error("Failed to parse ProseMirror JSON for #{content_id}: #{inspect(error)}")
                  Yex.Map.set(map, "initialLoad", "true")
              end

            nil ->
              Logger.warning("No Instance found for content_id: #{content_id}")
              Yex.Map.set(map, "initialLoad", "true")

            instance ->
              Logger.warning("Instance found but missing serialized content: #{inspect(instance, pretty: true)}")
              Yex.Map.set(map, "initialLoad", "true")
          end
        else
          Logger.debug("#{length(updates)} updates exist for #{content_id}, skipping initial content load")
          Yex.Map.delete(map, "content")
          Yex.Map.delete(map, "initialLoad")
        end

        maybe_flush_document(ydoc, content_id, updates)
        ydoc
      end

      @doc """
      Inserts a new update for the given content_id and tracks user activity.
      """
      def insert_update(content_id, value, user_id \\ nil) do
        result = @repo.insert(%@schema{content_id: content_id, value: value, version: :v1})
        track_user_activity(content_id, user_id)
        result
      end

      # Tracks user activity and schedules auto-save when user stops typing.
      # Only saves when user stops typing for the debounce period.
      defp track_user_activity(content_id, user_id) do
        # Start the auto-save supervisor if needed
        start_auto_save_supervisor()
        
        # Notify the auto-save supervisor about user activity
        WraftDoc.AutoSaveSupervisor.user_activity(content_id, user_id)
      end

      # Checks if user has been idle and saves if needed
      defp check_and_save_if_idle(content_id, user_id) do
        user_key = {content_id, user_id}
        last_activity = Process.get({:last_activity, user_key})
        now = System.system_time(:millisecond)
        
        if last_activity && (now - last_activity) >= @save_debounce_ms_idle do
          maybe_auto_save(content_id, user_id)
        end
      end

      # Checks if user has been idle long enough to trigger a save
      defp maybe_auto_save_by_idle(content_id, user_id) do
        user_key = {content_id, user_id}
        last_activity = Process.get({:last_activity, user_key})
        now = System.system_time(:millisecond)
        
        if last_activity && (now - last_activity) >= @save_debounce_ms_idle do
          maybe_auto_save(content_id, user_id)
        end
      end

      @doc """
      Forces an immediate save for the given content_id.
      Useful when user explicitly saves or leaves the document.
      """
      def force_save(content_id, user_id \\ nil) do
        Process.put({:last_save, content_id}, System.system_time(:millisecond))
        
        # Cancel any pending auto-save for this user
        WraftDoc.AutoSaveSupervisor.cancel_auto_save(content_id, user_id)
        
        Task.start(fn ->
          try do
            save_document_state(content_id)
          rescue
            e ->
              Logger.error("Failed to force save document #{content_id}: #{inspect(e)}")
          end
        end)
      end

      # Triggers auto-save with intelligent debouncing based on user activity.
      # Only saves when user has been idle for the debounce period.
      defp maybe_auto_save(content_id, user_id) do
        last_save = Process.get({:last_save, content_id})
        now = System.system_time(:millisecond)

        # Check if we should save based on max interval (safety net)
        should_save_by_max_interval = is_nil(last_save) || (now - last_save) >= @max_save_interval

        if should_save_by_max_interval do
          Process.put({:last_save, content_id}, now)

          IO.puts("Saving document #{content_id} by user #{user_id} idle timeout")

          Task.start(fn ->
            try do
              save_document_state(content_id)
            rescue
              e ->
                Logger.error("Failed to auto-save document #{content_id}: #{inspect(e)}")
            end
          end)
        end
      end

      @doc """
      Saves the current document state to the database.
      """
      def save_document_state(content_id) do
        doc = get_y_doc(content_id)
        {:ok, updates} = Yex.encode_state_as_update(doc)
        {:ok, sv} = Yex.encode_state_vector(doc)

        # Get the current prosemirror content
        y_xml_fragment = Yex.Doc.get_xml_fragment(doc, "prosemirror")
        string_data = Yex.XmlFragment.to_string(y_xml_fragment)

        # Default empty document structure
        empty_doc = %{
          "type" => "doc",
          "content" => [
            %{
              "type" => "paragraph",
              "content" => [%{"type" => "text", "text" => ""}]
            }
          ]
        }

        @repo.transaction(fn ->
          now = DateTime.utc_now() |> DateTime.truncate(:second)

          # Insert the Y.js update
          @repo.insert(%@schema{content_id: content_id, value: updates, version: :v1, inserted_at: now})
          put_state_vector(content_id, sv)
          clear_old_updates(content_id)

          # Update the Instance's serialized content
          case @repo.get(Instance, content_id) do
            %Instance{} = instance ->
              prosemirror_json = case string_data do
                "" -> empty_doc
                string_data ->
                  case safe_document_to_prosemirror(string_data) do
                    {:ok, result} -> result
                    {:error, _} -> empty_doc
                  end
              end

              # Convert prosemirror JSON to markdown for raw content with error handling
              raw_content = try do
                ProsemirrorToMarkdown.convert(prosemirror_json)
              rescue
                e ->
                  Logger.warning("Failed to convert prosemirror to markdown: #{inspect(e)}")
                  # Fallback to storing the original string data
                  string_data
              end

              serialized = Map.merge(instance.serialized, %{
                "serialized" => Jason.encode!(prosemirror_json),
                "body" => raw_content
              })

              instance
              |> Instance.update_changeset(%{"raw" => raw_content, "serialized" => serialized})
              |> @repo.update()

            nil ->
              Logger.warning("No Instance found for content_id: #{content_id} during auto-save")
          end
        end)
      end

      # Flushes the document if it has accumulated too many updates.
      defp maybe_flush_document(ydoc, content_id, updates) when length(updates) > @flush_size do
        Logger.info("Flushing document #{content_id} with #{length(updates)} updates")
        {:ok, u} = Yex.encode_state_as_update(ydoc)
        {:ok, sv} = Yex.encode_state_vector(ydoc)
        clock = List.last(updates).inserted_at
        flush_document(content_id, u, sv, clock)
      end

      defp maybe_flush_document(_ydoc, _content_id, _updates), do: :ok

      @doc """
      Gets the state vector for the given content_id.
      """
      def get_state_vector(content_id) do
        query =
          from(y in @schema,
            where: y.content_id == ^content_id and y.version == :v1_sv,
            select: y
          )

        @repo.one(query)
      end

      @doc """
      Gets the diff between the current document state and the given state vector.
      """
      def get_diff(content_id, sv) do
        doc = get_y_doc(content_id)
        Yex.encode_state_as_update(doc, sv)
      end

      @doc """
      Clears all data for the given content_id.
      """
      def clear_document(content_id) do
        query =
          from(y in @schema,
            where: y.content_id == ^content_id
          )

        @repo.delete_all(query)
      end

      # Stores or updates the state vector for the given content_id.
      defp put_state_vector(content_id, state_vector) do
        state_vector_record =
          case get_state_vector(content_id) do
            nil -> %@schema{content_id: content_id, version: :v1_sv}
            state_vector -> state_vector
          end

        changeset = @schema.changeset(state_vector_record, %{value: state_vector})
        @repo.insert_or_update(changeset)
      end

      # Gets all updates for the given content_id, ordered by insertion time.
      defp get_updates(content_id) do
        query =
          from(y in @schema,
            where: y.content_id == ^content_id and y.version == :v1,
            select: y,
            order_by: y.inserted_at
          )

        @repo.all(query)
      end

      # Flushes the document by consolidating updates and clearing old ones.
      defp flush_document(content_id, updates, sv, clock) do
        @repo.transaction(fn ->
          @repo.insert(%@schema{content_id: content_id, value: updates, version: :v1})
          put_state_vector(content_id, sv)
          clear_updates_to(content_id, clock)
        end)
      end

      # Clears all updates up to the given timestamp.
      defp clear_updates_to(content_id, to) do
        query =
          from(y in @schema,
            where: y.content_id == ^content_id and y.inserted_at < ^to
          )

        @repo.delete_all(query)
      end

      # Clears updates older than 24 hours to prevent database bloat.
      defp clear_old_updates(content_id) do
        # Keep only the last 24 hours of updates
        one_day_ago = DateTime.utc_now() |> DateTime.add(-24 * 60 * 60)

        query =
          from(y in @schema,
            where: y.content_id == ^content_id and y.version == :v1 and y.inserted_at < ^one_day_ago
          )

        @repo.delete_all(query)
      end

      # Safely converts XML document to ProseMirror JSON with error handling.
      defp safe_document_to_prosemirror(content) do
        try do
          result = XmlToProseMirror.document_to_prosemirror(content)
          {:ok, result}
        rescue
          error in WraftDoc.Utils.XmlToProseMirror.XmlParseError ->
            {:error, error.message}
        end
      end


    end
  end
end
