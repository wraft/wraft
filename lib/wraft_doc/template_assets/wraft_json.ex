defmodule WraftDoc.TemplateAssets.WraftJson do
  @moduledoc """
  Schema for wraft.json
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias WraftDoc.TemplateAssets.DataTemplate
  alias WraftDoc.TemplateAssets.Flow
  alias WraftDoc.TemplateAssets.Layout
  alias WraftDoc.TemplateAssets.Theme
  alias WraftDoc.TemplateAssets.Variant

  schema "wraft_json" do
    embeds_one(:theme, Theme)
    embeds_one(:layout, Layout)
    embeds_one(:flow, Flow)
    embeds_one(:variant, Variant)
    embeds_one(:data_template, DataTemplate)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [])
    |> cast_embed(:theme, required: true)
    |> cast_embed(:layout, required: true)
    |> cast_embed(:flow, required: true)
    |> cast_embed(:variant, required: true)
    |> cast_embed(:data_template, required: true)
  end
end

defmodule WraftDoc.TemplateAssets.Theme do
  @moduledoc """
  Schema for Theme in wraft_json
  """

  use Ecto.Schema
  import Ecto.Changeset

  # alias WraftDoc.TemplateAssets.Colors
  # alias WraftDoc.TemplateAssets.Font

  # :fonts, :colors
  @required_fields [:name]

  embedded_schema do
    field(:name, :string)
    # embeds_many :fonts, Font
    # embeds_one :colors, Colors
    # field :variant_link, :string
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name])
    |> validate_required(@required_fields)

    # |> cast_embed(:fonts, required: true)
    # |> cast_embed(:colors, required: true)
  end
end

defmodule WraftDoc.TemplateAssets.Font do
  @moduledoc """
  Schema for font in theme
  """

  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [:font_name, :font_weight, :file_path]

  embedded_schema do
    field(:font_name, :string)
    field(:font_weight, :string)
    field(:file_path, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
  end
end

defmodule WraftDoc.TemplateAssets.Colors do
  @moduledoc """
  Schema for colors in theme
  """

  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [:primary_color, :secondary_color, :body_color]

  embedded_schema do
    field(:primary_color, :string)
    field(:secondary_color, :string)
    field(:body_color, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
  end
end

defmodule WraftDoc.TemplateAssets.Layout do
  @moduledoc """
  Schema for Layout in wraft_json
  """

  use Ecto.Schema
  import Ecto.Changeset

  # alias WraftDoc.TemplateAssets.LayoutField
  # alias WraftDoc.TemplateAssets.Meta

  # :meta, :fields,
  @required_fields [:name, :slug, :slug_file, :description, :engine]

  embedded_schema do
    field(:name, :string)
    field(:slug, :string)
    field(:slug_file, :string)
    # embeds_one :meta, Meta
    # embeds_many :fields, LayoutField
    field(:description, :string)
    field(:engine, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name, :slug, :slug_file, :description, :engine])
    |> validate_required(@required_fields)

    # |> cast_embed(:meta, required: true)
    # |> cast_embed(:fields, required: true)
  end
end

defmodule WraftDoc.TemplateAssets.Meta do
  @moduledoc """
  Schema for Meta in Layout
  """

  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [:standard_size, :margin]

  embedded_schema do
    field(:standard_size, :string)
    field(:margin, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
  end
end

defmodule WraftDoc.TemplateAssets.LayoutField do
  @moduledoc """
  Schema for LayoutField in Layout
  """

  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [:type, :name, :description, :required]

  embedded_schema do
    field(:type, :string)
    field(:name, :string)
    field(:description, :string)
    field(:required, :boolean)
    field(:accepts, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:type, :name, :description, :required, :accepts])
    |> validate_required(@required_fields)
  end
end

defmodule WraftDoc.TemplateAssets.Flow do
  @moduledoc """
  Schema for Flow in wraft_json
  """

  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [:name]

  embedded_schema do
    field(:name, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
  end
end

defmodule WraftDoc.TemplateAssets.Variant do
  @moduledoc """
  Schema for Variant in wraft_json
  """

  use Ecto.Schema
  import Ecto.Changeset

  # alias WraftDoc.TemplateAssets.VariantField

  @required_fields [:color, :name, :description, :prefix]

  embedded_schema do
    field(:color, :string)
    field(:name, :string)
    field(:description, :string)
    field(:prefix, :string)
    # embeds_many :fields, VariantField
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:color, :name, :description, :prefix])
    |> validate_required(@required_fields)

    # |> cast_embed(:fields, required: true)
  end
end

defmodule WraftDoc.TemplateAssets.VariantField do
  @moduledoc """
  Schema for VariantField in Variant
  """
  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [:type, :name, :description, :required]

  embedded_schema do
    field(:type, :string)
    field(:name, :string)
    field(:description, :string)
    field(:required, :boolean)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
  end
end

defmodule WraftDoc.TemplateAssets.DataTemplate do
  @moduledoc """
  Schema for DataTemplate in wraft_json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [:title, :title_template]

  embedded_schema do
    field(:title, :string)
    field(:title_template, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
  end
end
