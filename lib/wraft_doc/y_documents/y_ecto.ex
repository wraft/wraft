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
      alias WraftDoc.Utils.ProsemirrorToMarkdown
      alias WraftDoc.Utils.XmlToProseMirror

      require Logger

      @repo unquote(repo)
      @schema unquote(schema)

      @flush_size 100
      # 5 seconds when user stops typing
      @save_debounce_ms_idle 5_000
      # Maximum 90 seconds between saves
      @max_save_interval 90_000

      require WraftDoc.YDocuments.YEcto.AutoSave
      require WraftDoc.YDocuments.YEcto.AutoSave.Manager
      require WraftDoc.YDocuments.YEcto.AutoSave.Activity
      require WraftDoc.YDocuments.YEcto.Document

      # Delegate to helper modules for implementation
      WraftDoc.YDocuments.YEcto.AutoSave.define_functions(
        save_debounce_ms_idle: @save_debounce_ms_idle,
        max_save_interval: @max_save_interval
      )

      WraftDoc.YDocuments.YEcto.Document.define_functions(
        repo: @repo,
        schema: @schema,
        flush_size: @flush_size
      )
    end
  end
end

defmodule WraftDoc.YDocuments.YEcto.AutoSave do
  @moduledoc false

  alias WraftDoc.YDocuments.YEcto.AutoSave.Activity
  alias WraftDoc.YDocuments.YEcto.AutoSave.Manager

  defmacro define_functions(opts) do
    save_debounce_ms_idle = opts[:save_debounce_ms_idle]
    max_save_interval = opts[:max_save_interval]

    quote do
      alias WraftDoc.YDocuments.AutoSaveManager, as: AutoSaveManager

      Manager.define_manager_functions()
      Manager.define_save_functions(unquote(max_save_interval))

      Activity.define_functions(save_debounce_ms_idle: unquote(save_debounce_ms_idle))
    end
  end
end

defmodule WraftDoc.YDocuments.YEcto.AutoSave.Manager do
  @moduledoc false

  defmacro define_manager_functions do
    quote do
      alias WraftDoc.YDocuments.AutoSaveManager, as: AutoSaveManager

      # Start the auto-save manager if not already started
      def start_auto_save_manager do
        case Process.whereis(AutoSaveManager) do
          nil ->
            {:ok, pid} = AutoSaveManager.start_link()
            pid

          pid ->
            pid
        end
      end
    end
  end

  defmacro define_save_functions(max_save_interval) do
    quote do
      alias WraftDoc.YDocuments.AutoSaveManager, as: AutoSaveManager

      @doc """
      Forces an immediate save for the given content_id.
      Useful when user explicitly saves or leaves the document.
      """
      def force_save(content_id, user_id \\ nil) do
        Process.put({:last_save, content_id}, System.system_time(:millisecond))

        # Cancel any pending auto-save for this user
        AutoSaveManager.cancel_auto_save(content_id, user_id)

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
        should_save_by_max_interval =
          is_nil(last_save) || now - last_save >= unquote(max_save_interval)

        if should_save_by_max_interval do
          perform_auto_save(content_id, user_id, now)
        end
      end

      # Perform the actual auto-save operation
      defp perform_auto_save(content_id, user_id, now) do
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
  end
end

defmodule WraftDoc.YDocuments.YEcto.AutoSave.Activity do
  @moduledoc false

  defmacro define_functions(opts) do
    save_debounce_ms_idle = opts[:save_debounce_ms_idle]

    quote do
      alias WraftDoc.YDocuments.AutoSaveManager, as: AutoSaveManager

      # Tracks user activity and schedules auto-save when user stops typing.
      # Only saves when user stops typing for the debounce period.
      defp track_user_activity(content_id, user_id) do
        # Start the auto-save manager if needed
        start_auto_save_manager()

        # Notify the auto-save manager about user activity
        AutoSaveManager.user_activity(content_id, user_id)
      end

      # Checks if user has been idle and saves if needed
      defp check_and_save_if_idle(content_id, user_id) do
        user_key = {content_id, user_id}
        last_activity = Process.get({:last_activity, user_key})
        now = System.system_time(:millisecond)

        if last_activity && now - last_activity >= unquote(save_debounce_ms_idle) do
          maybe_auto_save(content_id, user_id)
        end
      end

      # Checks if user has been idle long enough to trigger a save
      defp maybe_auto_save_by_idle(content_id, user_id) do
        user_key = {content_id, user_id}
        last_activity = Process.get({:last_activity, user_key})
        now = System.system_time(:millisecond)

        if last_activity && now - last_activity >= unquote(save_debounce_ms_idle) do
          maybe_auto_save(content_id, user_id)
        end
      end
    end
  end
end

defmodule WraftDoc.YDocuments.YEcto.Document do
  @moduledoc false

  defmacro define_functions(opts) do
    repo = opts[:repo]
    schema = opts[:schema]
    flush_size = opts[:flush_size]

    quote do
      alias WraftDoc.YDocuments.YEcto.Core, as: Core

      @doc """
      Gets or creates a Y.js document for the given content_id.
      Loads existing updates and initializes with saved content if available.
      """
      def get_y_doc(content_id) do
        Core.get_y_doc(
          content_id,
          unquote(repo),
          unquote(schema),
          unquote(flush_size)
        )
      end

      @doc """
      Inserts a new update for the given content_id and tracks user activity.
      """
      def insert_update(content_id, value, user_id \\ nil) do
        result =
          unquote(repo).insert(%unquote(schema){
            content_id: content_id,
            value: value,
            version: :v1
          })

        track_user_activity(content_id, user_id)
        result
      end

      @doc """
      Saves the current document state to the database.
      """
      def save_document_state(content_id) do
        Core.save_document_state(
          content_id,
          unquote(repo),
          unquote(schema)
        )
      end

      @doc """
      Gets the state vector for the given content_id.
      """
      def get_state_vector(content_id) do
        Core.get_state_vector(
          content_id,
          unquote(repo),
          unquote(schema)
        )
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
        Core.clear_document(content_id, unquote(repo), unquote(schema))
      end
    end
  end
end

defmodule WraftDoc.YDocuments.YEcto.Core do
  @moduledoc false

  import Ecto.Query
  require Logger
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Utils.ProsemirrorToMarkdown
  alias WraftDoc.Utils.XmlToProseMirror

  def get_y_doc(content_id, repo, schema, flush_size) do
    ydoc = Yex.Doc.new()
    updates = get_updates(content_id, repo, schema)
    map = Yex.Doc.get_map(ydoc, "doc-initial")

    apply_updates_to_doc(ydoc, updates)
    initialize_doc_content(ydoc, map, updates, repo, content_id)
    maybe_flush_document(ydoc, content_id, updates, repo, schema, flush_size)
    ydoc
  end

  defp apply_updates_to_doc(ydoc, updates) do
    Yex.Doc.transaction(ydoc, fn ->
      Enum.each(updates, fn update ->
        Yex.apply_update(ydoc, update.value)
      end)
    end)
  end

  defp initialize_doc_content(_ydoc, map, updates, repo, content_id) do
    if Enum.empty?(updates) do
      load_existing_content(map, repo, content_id)
    else
      Yex.Map.delete(map, "content")
    end
  end

  defp load_existing_content(map, repo, content_id) do
    case repo.get(Instance, content_id) do
      %Instance{serialized: %{"serialized" => serialized}} when not is_nil(serialized) ->
        load_serialized_content(map, serialized, content_id)

      _ ->
        :ok
    end
  end

  defp load_serialized_content(map, serialized, content_id) do
    case Jason.decode(serialized) do
      {:ok, prosemirror_json} ->
        prelim = Yex.MapPrelim.from(prosemirror_json)
        Yex.Map.set(map, "content", prelim)

      error ->
        Logger.error("Failed to parse ProseMirror JSON for #{content_id}: #{inspect(error)}")
    end
  end

  def save_document_state(content_id, repo, schema) do
    doc = get_y_doc(content_id, repo, schema, 50)
    {:ok, updates} = Yex.encode_state_as_update(doc)
    {:ok, sv} = Yex.encode_state_vector(doc)
    string_data = extract_prosemirror_content(doc)

    repo.transaction(fn ->
      now = DateTime.truncate(DateTime.utc_now(), :second)
      insert_y_update(repo, schema, content_id, updates, now)
      put_state_vector(content_id, sv, repo, schema)
      clear_old_updates(content_id, repo, schema)
      update_instance_content(repo, content_id, string_data)
    end)
  end

  defp extract_prosemirror_content(doc) do
    y_xml_fragment = Yex.Doc.get_xml_fragment(doc, "prosemirror")
    Yex.XmlFragment.to_string(y_xml_fragment)
  end

  defp insert_y_update(repo, schema, content_id, updates, now) do
    repo.insert(
      struct(schema, %{content_id: content_id, value: updates, version: :v1, inserted_at: now})
    )
  end

  defp update_instance_content(repo, content_id, string_data) do
    case repo.get(Instance, content_id) do
      %Instance{} = instance ->
        prosemirror_json = build_prosemirror_json(string_data)
        raw_content = convert_to_markdown(prosemirror_json, string_data)
        serialized = build_serialized_content(instance.serialized, prosemirror_json, raw_content)

        instance
        |> Instance.update_changeset(%{"raw" => raw_content, "serialized" => serialized})
        |> repo.update()

      nil ->
        :ok
    end
  end

  defp build_prosemirror_json(string_data) do
    empty_doc = %{
      "type" => "doc",
      "content" => [
        %{
          "type" => "paragraph",
          "content" => [%{"type" => "text", "text" => ""}]
        }
      ]
    }

    case string_data do
      "" ->
        empty_doc

      string_data ->
        case safe_document_to_prosemirror(string_data) do
          {:ok, result} -> result
          {:error, _} -> empty_doc
        end
    end
  end

  defp convert_to_markdown(prosemirror_json, string_data) do
    ProsemirrorToMarkdown.convert(prosemirror_json)
  rescue
    _e ->
      # Fallback to storing the original string data
      string_data
  end

  defp build_serialized_content(instance_serialized, prosemirror_json, raw_content) do
    Map.merge(instance_serialized, %{
      "serialized" => Jason.encode!(prosemirror_json),
      "body" => raw_content
    })
  end

  def get_state_vector(content_id, repo, schema) do
    query =
      from(y in schema,
        where: y.content_id == ^content_id and y.version == :v1_sv,
        select: y
      )

    repo.one(query)
  end

  def clear_document(content_id, repo, schema) do
    query =
      from(y in schema,
        where: y.content_id == ^content_id
      )

    repo.delete_all(query)
  end

  # Private helper functions

  defp maybe_flush_document(ydoc, content_id, updates, repo, schema, flush_size)
       when length(updates) > flush_size do
    {:ok, u} = Yex.encode_state_as_update(ydoc)
    {:ok, sv} = Yex.encode_state_vector(ydoc)
    clock = List.last(updates).inserted_at
    flush_document(content_id, u, sv, clock, repo, schema)
  end

  defp maybe_flush_document(_ydoc, _content_id, _updates, _repo, _schema, _flush_size), do: :ok

  defp put_state_vector(content_id, state_vector, repo, schema) do
    state_vector_record =
      case get_state_vector(content_id, repo, schema) do
        nil -> struct(schema, %{content_id: content_id, version: :v1_sv})
        state_vector -> state_vector
      end

    changeset = schema.changeset(state_vector_record, %{value: state_vector})
    repo.insert_or_update(changeset)
  end

  defp get_updates(content_id, repo, schema) do
    query =
      from(y in schema,
        where: y.content_id == ^content_id and y.version == :v1,
        select: y,
        order_by: y.inserted_at
      )

    repo.all(query)
  end

  defp flush_document(content_id, updates, sv, clock, repo, schema) do
    repo.transaction(fn ->
      repo.insert(struct(schema, %{content_id: content_id, value: updates, version: :v1}))
      put_state_vector(content_id, sv, repo, schema)
      clear_updates_to(content_id, clock, repo, schema)
    end)
  end

  defp clear_updates_to(content_id, to, repo, schema) do
    query =
      from(y in schema,
        where: y.content_id == ^content_id and y.inserted_at < ^to
      )

    repo.delete_all(query)
  end

  defp clear_old_updates(content_id, repo, schema) do
    # Keep only the last 24 hours of updates
    one_day_ago = DateTime.add(DateTime.utc_now(), -24 * 60 * 60)

    query =
      from(y in schema,
        where: y.content_id == ^content_id and y.version == :v1 and y.inserted_at < ^one_day_ago
      )

    repo.delete_all(query)
  end

  defp safe_document_to_prosemirror(content) do
    result = XmlToProseMirror.document_to_prosemirror(content)
    {:ok, result}
  rescue
    error in WraftDoc.Utils.XmlToProseMirror.XmlParseError ->
      {:error, error.message}
  end
end
