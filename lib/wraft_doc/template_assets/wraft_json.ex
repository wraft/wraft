defmodule WraftDoc.TemplateAssets.WraftJson do
  @moduledoc """
  Schema for wraft.json
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias WraftDoc.TemplateAssets.DataTemplate
  alias WraftDoc.TemplateAssets.Flow
  alias WraftDoc.TemplateAssets.Layout
  alias WraftDoc.TemplateAssets.Metadata
  alias WraftDoc.TemplateAssets.Theme
  alias WraftDoc.TemplateAssets.Variant

  schema "wraft_json" do
    field(:version, :string)
    field(:frame, :string)

    embeds_one(:metadata, Metadata)
    embeds_one(:theme, Theme)
    embeds_one(:layout, Layout)
    embeds_one(:flow, Flow)
    embeds_one(:variant, Variant)
    embeds_one(:data_template, DataTemplate)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:version, :frame])
    |> cast_embed(:metadata, required: true)
    |> cast_embed(:theme, with: &Theme.changeset/2, required: false)
    |> cast_embed(:layout, with: &Layout.changeset/2, required: false)
    |> cast_embed(:flow, with: &Flow.changeset/2, required: false)
    |> cast_embed(:variant, with: &Variant.changeset/2, required: false)
    |> cast_embed(:data_template, with: &DataTemplate.changeset/2, required: false)
  end
end

defmodule WraftDoc.TemplateAssets.Metadata do
  @moduledoc """
  Schema for validating wraft.json metadata
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:description, :string)
    field(:type, :string)
    field(:updated_at, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name, :description, :type, :updated_at])
    |> validate_required([:name, :description, :type])
    |> validate_inclusion(:type, ["template_asset"])
  end
end

defmodule WraftDoc.TemplateAssets.Theme do
  @moduledoc """
  Schema for Theme in wraft_json
  """

  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [:name]

  embedded_schema do
    field(:name, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name])
    |> validate_required(@required_fields)
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

  @required_fields [:name, :slug, :slug_file, :description, :engine]
  @valid_engines ["pandoc/latex", "pandoc/typst"]

  embedded_schema do
    field(:name, :string)
    field(:slug, :string)
    field(:slug_file, :string)
    field(:description, :string)
    field(:engine, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name, :slug, :slug_file, :description, :engine])
    |> validate_required(@required_fields)
    |> validate_inclusion(:engine, @valid_engines,
      message: "must be one of: pandoc/latex, pandoc/typst"
    )
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

  @required_fields [:color, :name, :description, :prefix]

  embedded_schema do
    field(:color, :string)
    field(:name, :string)
    field(:description, :string)
    field(:prefix, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:color, :name, :description, :prefix])
    |> validate_required(@required_fields)
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
