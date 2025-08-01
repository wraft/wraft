defmodule WraftDoc.Layouts.Layout do
  @moduledoc """
  The layout model.
  """
  @behaviour ExTypesense

  use WraftDoc.Schema
  use Waffle.Ecto.Schema
  alias __MODULE__
  alias __MODULE__.Margin

  schema "layouts" do
    field(:name, :string)
    field(:description, :string)
    field(:width, :float)
    field(:height, :float)
    field(:unit, :string)
    field(:slug, :string)
    field(:screenshot, WraftDocWeb.LayoutScreenShotUploader.Type)

    embeds_one(:margin, Margin, on_replace: :update)

    belongs_to(:engine, WraftDoc.Documents.Engine)
    belongs_to(:frame, WraftDoc.Frames.Frame)
    belongs_to(:asset, WraftDoc.Assets.Asset)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    has_many(:content_types, WraftDoc.ContentTypes.ContentType)

    timestamps()
  end

  def changeset(%Layout{} = layout, attrs \\ %{}) do
    layout
    |> cast(attrs, [
      :name,
      :description,
      :width,
      :height,
      :unit,
      :slug,
      :frame_id,
      :asset_id,
      :organisation_id,
      :engine_id
    ])
    |> cast_embed(:margin, with: &Margin.changeset/2)
    |> validate_required([
      :name,
      :description,
      :organisation_id,
      :engine_id
    ])
    |> foreign_key_constraint(:frame_id, message: "Please enter an existing frame")
    |> unique_constraint(:name,
      message: "Layout with the same name exists. Use another name.!",
      name: :layout_organisation_unique_index
    )
  end

  def update_changeset(%Layout{} = layout, attrs \\ %{}) do
    layout
    |> cast(attrs, [
      :name,
      :description,
      :width,
      :height,
      :unit,
      :slug,
      :asset_id,
      :frame_id,
      :engine_id
    ])
    |> cast_embed(:margin, with: &Margin.changeset/2)
    |> cast_attachments(attrs, [:screenshot])
    |> validate_required([
      :name,
      :description,
      :engine_id
    ])
    |> unique_constraint(:name,
      message: "Layout with the same name exists. Use another name.!",
      name: :layout_organisation_unique_index
    )
  end

  def file_changeset(%Layout{} = layout, attrs \\ %{}) do
    cast_attachments(layout, attrs, [:screenshot])
  end

  @impl ExTypesense
  def get_field_types do
    %{
      fields: [
        %{name: "id", type: "string", facet: false},
        %{name: "name", type: "string", facet: true},
        %{name: "description", type: "string", facet: true},
        %{name: "width", type: "float", facet: false},
        %{name: "height", type: "float", facet: false},
        %{name: "unit", type: "string", facet: true},
        %{name: "slug", type: "string", facet: true},
        %{name: "engine_id", type: "string", facet: true},
        %{name: "creator_id", type: "string", facet: true},
        %{name: "organisation_id", type: "string", facet: true},
        %{name: "inserted_at", type: "int64", facet: false},
        %{name: "updated_at", type: "int64", facet: false}
      ]
    }
  end
end

defmodule WraftDoc.Layouts.Layout.Margin do
  @moduledoc """
  The trail period model.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @derive {Jason.Encoder, only: [:top, :right, :bottom, :left]}

  embedded_schema do
    field(:top, :float)
    field(:right, :float)
    field(:bottom, :float)
    field(:left, :float)
  end

  def changeset(margin, attrs) do
    margin
    |> cast(attrs, [:top, :right, :bottom, :left])
    |> validate_number(:top, greater_than_or_equal_to: 0)
    |> validate_number(:right, greater_than_or_equal_to: 0)
    |> validate_number(:bottom, greater_than_or_equal_to: 0)
    |> validate_number(:left, greater_than_or_equal_to: 0)
  end
end
