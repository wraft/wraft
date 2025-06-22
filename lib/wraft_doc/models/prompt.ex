defmodule WraftDoc.Models.Prompt do
  @moduledoc """
    Prompt model for storing and managing prompts.
  """

  use WraftDoc.Schema
  import Ecto.Changeset

  alias WraftDoc.Account.User
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Models.Model

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  schema "prompt" do
    field(:status, :string)
    field(:title, :string)
    field(:prompt, :string)
    field(:type, Ecto.Enum, values: [:extraction, :suggestion, :refinement])

    belongs_to(:ai_models, Model, foreign_key: :model_id)
    belongs_to(:creator, User)
    belongs_to(:organisation, Organisation)

    timestamps()
  end

  @doc false
  def changeset(prompts, attrs) do
    prompts
    |> cast(attrs, [:title, :prompt, :status, :type, :model_id, :creator_id, :organisation_id])
    |> validate_required([
      :title,
      :prompt,
      :type,
      :status,
      :model_id,
      :creator_id,
      :organisation_id
    ])
    |> validate_inclusion(:type, [:extraction, :suggestion, :refinement])
  end
end
