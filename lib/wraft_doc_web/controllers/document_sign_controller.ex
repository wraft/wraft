defmodule WraftDocWeb.Api.V1.DocumentSignController do
  use WraftDocWeb, :controller

  alias WraftDoc.Integrations.Documenso
  alias WraftDoc.Integrations.DocuSign

  action_fallback(WraftDocWeb.FallbackController)

  def send_document(conn, %{"id" => document_id, "type" => type, "signers" => signers}) do
    org_id = conn.assigns.current_user.current_org_id

    case handle_document(document_id, type, org_id, signers) do
      {:ok, integration} ->
        conn
        |> put_status(:created)
        |> render("show.json", integration: integration)

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  # def doc_status(conn, %{"id" => id}) do
  #   org_id = conn.assigns.current_user.current_org_id

  #   case DocuSign.doc_status(id, org_id) do
  #     {:ok, stats} ->
  #       render(conn, "show.json", stats: stats)

  #     {:error, reason} ->
  #       conn
  #       |> put_status(:not_found)
  #       |> json(%{error: reason})
  #   end
  # end

  # def download(conn, %{"id" => id}) do
  #   organisation_id = conn.assigns.current_user.current_org_id

  #   case DocuSign.download_document(id, organisation_id) do
  #     {:ok, file_data} ->
  #       send_download(conn, {:binary, file_data}, filename: "#{id}.pdf")

  #     {:error, reason} ->
  #       conn
  #       |> put_status(:not_found)
  #       |> json(%{error: "Document not found: #{inspect(reason)}"})
  #   end
  # end

  defp handle_document(document_id, type, org_id, signers) do
    case type do
      "docusign" ->
        DocuSign.send_document(document_id, org_id, signers)

      "documenso" ->
        Documenso.create_and_send(
          document_id,
          org_id,
          "Please sign",
          signers
        )
    end
  end
end
