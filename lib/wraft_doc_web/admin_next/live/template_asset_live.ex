defmodule WraftDocWeb.AdminNext.TemplateAssetLive do
  @moduledoc """
  Backpex admin for `WraftDoc.TemplateAssets.TemplateAsset`.

  Mirrors `WraftDocWeb.TemplateAssets.TemplateAssetAdmin` (Kaffy) with one
  intentional limitation: **the file/thumbnail upload form is not wired here**.

  Why: the original Kaffy admin's `insert/2` runs a multi-step pipeline
  (ZIP validation → file validation → `TemplateAssets.process_template_asset`
   → Ecto.Multi for asset + template_asset) that takes a `Plug.Upload`
  posted via the multipart form. Backpex uploads use a different
  LiveView-native flow (`allow_upload` + per-row hooks). Porting the
  pipeline 1:1 needs a custom `Backpex.Fields.Upload` + a save hook that
  reconstructs the params; that's its own follow-up.

  In the meantime this admin lets you:
  - **List** existing template assets (publicly seeded ones — `organisation_id
    IS NULL AND creator_id IS NULL`, matching Kaffy).
  - **Edit** name, description on existing rows.
  - **View** file name + ZIP size on the index.
  - **Delete** an asset (delegates to `Assets.delete_asset/1` so the storage
    file and thumbnail are cleaned up — same flow as Kaffy's `delete/2`).

  Creating new template assets should still happen via the API or seed
  scripts until the upload hook is wired.
  """
  use Backpex.LiveResource,
    adapter: Backpex.Adapters.Ecto,
    adapter_config: [
      schema: WraftDoc.TemplateAssets.TemplateAsset,
      repo: WraftDoc.Repo,
      update_changeset: &__MODULE__.changeset/3,
      create_changeset: &__MODULE__.changeset/3,
      item_query: &__MODULE__.item_query/3
    ],
    pubsub: [server: WraftDoc.PubSub],
    init_order: %{by: :inserted_at, direction: :desc}

  use WraftDocWeb.AdminNext.LiveResourcePage,
    subtitle: "Public template asset library. Create new assets via Import; edit metadata here."

  import Ecto.Query

  require Logger

  @impl Backpex.LiveResource
  def singular_name, do: "Template Asset"

  @impl Backpex.LiveResource
  def plural_name, do: "Template Assets"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {WraftDocWeb.AdminNext.Layouts, :app}

  @impl Backpex.LiveResource
  def can?(_assigns, :new, _item), do: false
  def can?(_assigns, _action, _item), do: true

  def extra_actions(assigns) do
    ~H"""
    <.link navigate="/admin/template-assets/import" class="btn btn-primary btn-sm">
      <Backpex.HTML.CoreComponents.icon name="hero-arrow-up-tray" class="size-4" /> Import
    </.link>
    """
  end

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{module: Backpex.Fields.Text, label: "Name", searchable: true, orderable: true},
      description: %{module: Backpex.Fields.Textarea, label: "Description"},
      file_name: %{
        module: Backpex.Fields.Text,
        label: "File",
        except: [:new],
        render_form: &__MODULE__.render_readonly_text/1
      },
      zip_file_size: %{
        module: Backpex.Fields.Text,
        label: "ZIP size",
        except: [:new],
        render_form: &__MODULE__.render_readonly_text/1
      },
      thumbnail: %{
        module: Backpex.Fields.Text,
        label: "Thumbnail",
        except: [:new],
        render: &__MODULE__.render_thumbnail/1,
        render_form: &__MODULE__.render_thumbnail_readonly/1
      },
      inserted_at: %{
        module: Backpex.Fields.DateTime,
        label: "Created At",
        except: [:new, :edit],
        orderable: true
      },
      updated_at: %{
        module: Backpex.Fields.DateTime,
        label: "Updated At",
        except: [:new, :edit],
        orderable: true
      }
    ]
  end

  @doc false
  def render_readonly_text(assigns) do
    ~H"""
    <div class="text-base-content/80 bg-base-200 rounded px-3 py-2 text-sm">
      {@form[@name].value || "—"}
    </div>
    """
  end

  @doc false
  def render_thumbnail(assigns) do
    ~H"""
    <span class="text-base-content/70 text-xs">
      {WraftDocWeb.AdminNext.TemplateAssetLive.thumbnail_label(@value)}
    </span>
    """
  end

  @doc false
  def render_thumbnail_readonly(assigns) do
    ~H"""
    <div class="text-base-content/80 bg-base-200 rounded px-3 py-2 text-sm">
      {WraftDocWeb.AdminNext.TemplateAssetLive.thumbnail_label(@form[@name].value)}
    </div>
    """
  end

  def thumbnail_label(nil), do: "—"
  def thumbnail_label(%{file_name: file_name}) when is_binary(file_name), do: file_name
  def thumbnail_label(%Waffle.File{file_name: file_name}), do: file_name
  def thumbnail_label(value) when is_binary(value), do: value
  def thumbnail_label(_), do: "—"

  @impl Backpex.LiveResource
  def item_actions(default_actions) do
    Keyword.delete(default_actions, :delete) ++ [delete: %{module: __MODULE__.CleanupDelete}]
  end

  def item_query(query, _live_action, _assigns) do
    from(t in query,
      where: is_nil(t.organisation_id) and is_nil(t.creator_id),
      preload: [:asset]
    )
  end

  def changeset(template_asset, attrs, _metadata) do
    # Only allow editing name + description — match the limited edit surface
    # the original Kaffy admin supported in practice.
    cast_attrs = Map.take(attrs, ["name", "description"])
    Ecto.Changeset.cast(template_asset, cast_attrs, [:name, :description])
  end

  defmodule CleanupDelete do
    @moduledoc """
    Replaces the default delete with one that also drops the underlying
    `Asset` row + storage file and the thumbnail. Mirrors the Kaffy admin's
    `delete/2` callback.
    """
    use Backpex.ItemAction

    alias WraftDoc.Assets
    alias WraftDoc.Repo
    alias WraftDoc.TemplateAssets.TemplateAsset, as: TASchema
    alias WraftDocWeb.AssetUploader
    alias WraftDocWeb.TemplateAssetThumbnailUploader
    require Logger

    @impl Backpex.ItemAction
    def icon(assigns, _item) do
      ~H'<Backpex.HTML.CoreComponents.icon name="hero-trash" class="h-5 w-5 hover:text-red-600" />'
    end

    @impl Backpex.ItemAction
    def label(_assigns, _item), do: "Delete"

    @impl Backpex.ItemAction
    def confirm(_assigns), do: "Delete template asset (including storage file and thumbnail)?"

    @impl Backpex.ItemAction
    def confirm_label(_assigns), do: "Delete"

    @impl Backpex.ItemAction
    def cancel_label(_assigns), do: "Cancel"

    @impl Backpex.ItemAction
    def handle(socket, items, _data) do
      deleted =
        Enum.flat_map(items, fn %TASchema{} = ta ->
          ta = Repo.preload(ta, :asset)
          %{asset: %{file: file} = asset} = ta

          with {:ok, _} <- Assets.delete_asset(asset),
               :ok <- delete_thumbnail(ta),
               :ok <- AssetUploader.delete({file, asset}) do
            [ta]
          else
            err ->
              Logger.error("TemplateAsset cleanup delete failed for #{ta.id}: #{inspect(err)}")
              []
          end
        end)

      {:ok,
       socket
       |> Phoenix.LiveView.clear_flash()
       |> Phoenix.LiveView.put_flash(:info, "Deleted #{length(deleted)} template asset(s).")}
    end

    defp delete_thumbnail(%{thumbnail: nil}), do: :ok

    defp delete_thumbnail(%{thumbnail: thumbnail} = ta),
      do: TemplateAssetThumbnailUploader.delete({thumbnail, ta})
  end
end
