defmodule WraftDoc.Workflows.Adaptors.TemplateAdaptor do
  @moduledoc """
  Template adaptor for WraftDoc workflows.
  """

  @behaviour WraftDoc.Workflows.Adaptors.Adaptor

  alias WraftDoc.Documents
  alias WraftDoc.Repo

  require Logger

  @impl true
  def execute(config, input_data, _credentials) do
    template_id = config["template_id"]
    template = WraftDoc.DataTemplates.get_data_template(template_id)

    input_tables = input_data["tables"] || %{}

    merged_serialized =
      if map_size(input_tables) > 0 do
        # We pass the input_tables as context. The handler expects a map where keys are table names,
        # or a map with "smart_tables" key.
        # Since input_tables is %{"TableName" => data}, we can pass it directly if we adjust the handler
        # OR we pass %{"smart_tables" => input_tables}.
        # The handler supports both.

        # We need to process the "data" field of serialized which is a stringified JSON.
        # But TokenEngine.replace expects a map for Prosemirror adapter.
        # So we need to decode, replace, and encode back.

        doc = Jason.decode!(template.serialized["data"])

        updated_doc =
          WraftDoc.TokenEngine.replace(
            doc,
            WraftDoc.TokenEngine.Adapters.Prosemirror,
            %{"smart_tables" => input_tables}
          )

        %{template.serialized | "data" => Jason.encode!(updated_doc)}
      else
        template.serialized
      end

    params =
      %{}
      |> Documents.do_create_instance_params(%{template | serialized: merged_serialized})
      |> Map.merge(%{"type" => 3, "doc_settings" => %{}})

    current_user =
      input_data["user_id"]
      |> WraftDoc.Account.get_user_by_uuid()
      |> Map.put(:current_org_id, input_data["org_id"])

    instance =
      current_user
      |> Documents.create_instance(
        template.content_type,
        params
      )
      |> Repo.preload(:versions)

    # TODO: Implement logic to handle errors during document generation
    # Documents.build_doc(instance, template.content_type.layout)

    Documents.bulk_build(current_user, instance, template.content_type.layout)

    %{id: document_id, build: document_url} =
      instance
      |> Repo.preload(:versions)
      |> Documents.get_built_document()

    {:ok,
     %{
       generated_at: DateTime.utc_now(),
       document_id: document_id,
       document_url: document_url,
       metadata: %{}
     }}
  end
end
