defmodule WraftDoc.Models.Prompt do
  @moduledoc """
    Prompt model for storing and managing prompts.
  """

  use WraftDoc.Schema
  import Ecto.Changeset

  alias WraftDoc.Account.User
  alias WraftDoc.Enterprise.Organisation

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  @fields [:title, :prompt, :status, :type, :creator_id, :organisation_id]

  schema "prompt" do
    field(:status, :string)
    field(:title, :string)
    field(:prompt, :string)
    field(:type, Ecto.Enum, values: [:extraction, :suggestion, :refinement])

    belongs_to(:creator, User)
    belongs_to(:organisation, Organisation)

    timestamps()
  end

  @doc false
  def changeset(prompts, attrs) do
    prompts
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> validate_inclusion(:type, [:extraction, :suggestion, :refinement])
    |> foreign_key_constraint(:creator_id)
    |> foreign_key_constraint(:organisation_id)
  end
end
