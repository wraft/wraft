defmodule WraftDoc.Enterprise.Plan.Limits do
  @moduledoc """
  The `Limits` model defines rate limits for various actions.

  Each field follows the convention controller_name_action to specify limits on a per-action basis. This naming convention allows
  for intuitive and targeted rate-limiting based on both the controller and action.

  ## Fields

    - `instance_create`: Limit for creating instances in the `Instance` controller.
    - `content_type_create`: Limit for creating content types in the `ContentType` controller.
    - `organisation_create`: Limit for creating organizations in the `Organisation` controller.
    - `organisation_invite`: Limit for inviting users to an organization in the `Organisation` controller.

  This structure helps rate-limiting plugs capture specific limits based on the context of each controller action.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @fields [
    :instance_create,
    :content_type_create,
    :organisation_create,
    :organisation_invite
  ]
  @derive {Jason.Encoder, only: @fields}

  embedded_schema do
    field(:instance_create, :integer)
    field(:content_type_create, :integer)
    field(:organisation_create, :integer)
    field(:organisation_invite, :integer)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, @fields)
    |> validate_required(@fields)
  end
end
