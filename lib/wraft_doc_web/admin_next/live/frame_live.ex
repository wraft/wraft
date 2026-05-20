defmodule WraftDocWeb.AdminNext.FrameLive do
  @moduledoc """
  Backpex admin for `WraftDoc.Frames.Frame`.

  Mirrors `WraftDocWeb.Frames.FrameAdmin` (Kaffy) with the same upload
  limitation as `TemplateAssetLive`: file + thumbnail uploads are not wired
  to the Backpex form. Create new Frames via the API; this UI manages name,
  description, and organisation assignment on existing rows, plus deletion.
  """
  use Backpex.LiveResource,
    adapter: Backpex.Adapters.Ecto,
    adapter_config: [
      schema: WraftDoc.Frames.Frame,
      repo: WraftDoc.Repo,
      update_changeset: &__MODULE__.changeset/3,
      create_changeset: &__MODULE__.changeset/3,
      item_query: &__MODULE__.item_query/3
    ],
    pubsub: [server: WraftDoc.PubSub],
    init_order: %{by: :inserted_at, direction: :desc}

  use WraftDocWeb.AdminNext.LiveResourcePage,
    subtitle:
      "LaTeX/Typst frames used as document templates. Create new frames via Import; edit metadata here."

  import Ecto.Query

  alias WraftDoc.Frames.Frame

  @impl Backpex.LiveResource
  def singular_name, do: "Frame"

  @impl Backpex.LiveResource
  def plural_name, do: "Frames"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {WraftDocWeb.AdminNext.Layouts, :app}

  @impl Backpex.LiveResource
  def can?(_assigns, :new, _item), do: false
  def can?(_assigns, _action, _item), do: true

  def extra_actions(assigns) do
    ~H"""
    <.link navigate="/admin/frames/import" class="btn btn-primary btn-sm">
      <Backpex.HTML.CoreComponents.icon name="hero-arrow-up-tray" class="size-4" /> Import
    </.link>
    """
  end

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{module: Backpex.Fields.Text, label: "Name", searchable: true, orderable: true},
      description: %{module: Backpex.Fields.Textarea, label: "Description"},
      type: %{
        module: Backpex.Fields.Select,
        label: "Type",
        options: [{"LaTeX", :latex}, {"Typst", :typst}],
        except: [:new, :edit]
      },
      file_size: %{
        module: Backpex.Fields.Text,
        label: "File size",
        except: [:new],
        render_form: &__MODULE__.render_readonly_text/1
      },
      thumbnail: %{
        module: Backpex.Fields.Text,
        label: "Thumbnail",
        except: [:new],
        render: &__MODULE__.render_file_name/1,
        render_form: &__MODULE__.render_file_name_readonly/1
      },
      organisation: %{
        module: Backpex.Fields.BelongsTo,
        label: "Organisation",
        display_field: :name,
        live_resource: WraftDocWeb.AdminNext.OrganisationLive
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
  def render_file_name(assigns) do
    ~H"""
    <span class="text-base-content/70 text-xs">
      {WraftDocWeb.AdminNext.FrameLive.file_name_label(@value)}
    </span>
    """
  end

  @doc false
  def render_file_name_readonly(assigns) do
    ~H"""
    <div class="text-base-content/80 bg-base-200 rounded px-3 py-2 text-sm">
      {WraftDocWeb.AdminNext.FrameLive.file_name_label(@form[@name].value)}
    </div>
    """
  end

  def file_name_label(nil), do: "—"
  def file_name_label(%{file_name: file_name}) when is_binary(file_name), do: file_name
  def file_name_label(%Waffle.File{file_name: file_name}), do: file_name
  def file_name_label(value) when is_binary(value), do: value
  def file_name_label(_), do: "—"

  def item_query(query, _live_action, _assigns) do
    from(r in query, preload: [:organisation, :asset])
  end

  def changeset(frame, attrs, _metadata) do
    Frame.admin_changeset(frame, Map.take(attrs, ["name", "description", "organisation_id"]))
  end
end
