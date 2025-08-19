defmodule WraftDoc.Integrations.Documenso do
  @moduledoc """
  Documenso client with coordinate-based signing flow:
  * Accepts single or multiple signers
  * Uses explicit coordinates (x, y, page) for signature fields
  * Combines create, upload, field placement, and send
  """
  require Logger
  alias WraftDoc.Client.Minio
  alias WraftDoc.Documents

  @base_url "https://app.documenso.com/api/v1"

  defp api_token,
    do: Application.get_env(:wraft_doc, :documenso_api_token, "api_lcver61xyuodpzv9")

  defp headers,
    do: [
      {"Authorization", "Bearer #{api_token()}"},
      {"Content-Type", "application/json"}
    ]

  @doc """
  Create document, upload file, add signature fields at given coordinates, then send.
  - `signers` is a list of maps:
    %{
      email: "user@example.com",
      name: "User Name",
      page: 1,
      x: 150,
      y: 300,
      width: 150,
      height: 50
    }
  """
  def create_and_send(document_id, org_id, msg, signers) do
    document = Documents.get_instance(document_id, %{current_org_id: org_id})

    path =
      "organisations/#{document.organisation_id}/contents/#{document.instance_id}/#{document.instance_id}-v1.pdf"

    file_data = Minio.get_object(path)

    with {:ok, %{"id" => doc_id, "recipients" => recps} = resp} <-
           create_document(document.instance_id, msg, normalize_signers(signers)),
         {:ok, _} <- upload_to_s3(resp["uploadUrl"], file_data),
         :ok <- add_fields(doc_id, recps, signers),
         {:ok, send_resp} <- send_document(doc_id) do
      {:ok, send_resp}
    else
      error -> error
    end
  end

  defp normalize_signers(signers) do
    signers
    |> Enum.with_index(1)
    |> Enum.map(fn {signer, idx} ->
      %{
        "email" => signer["email"],
        "name" => signer["name"],
        "role" => "SIGNER",
        "signingOrder" => idx
      }
    end)
  end

  defp create_document(name, msg, signers) do
    payload = %{
      "title" => name,
      "recipients" => signers,
      "meta" => %{
        "subject" => "Please sign: #{name}",
        "message" => msg,
        "timeZone" => "Etc/UTC",
        "signingOrder" => "PARALLEL"
      }
    }

    case HTTPoison.post("#{@base_url}/documents", Jason.encode!(payload), headers()) do
      {:ok, %{status_code: 200, body: body}} ->
        Jason.decode(body)

      {:ok, %{status_code: code, body: body}} ->
        {:error, "Documenso create_document error #{code}: #{body}"}

      {:error, err} ->
        {:error, "HTTP error: #{inspect(err)}"}
    end
  end

  defp upload_to_s3(upload_url, file_content) when is_binary(file_content) do
    case HTTPoison.put(upload_url, file_content, []) do
      {:ok, %{status_code: st}} when st in [200, 204] -> {:ok, :uploaded}
      {:ok, %{status_code: code, body: body}} -> {:error, "S3 upload failed: #{code} #{body}"}
      {:error, err} -> {:error, "S3 upload HTTP error: #{inspect(err)}"}
    end
  end

  # Add coordinate-based signature fields
  defp add_fields(document_id, recipients, signers) do
    # Map recipients by email to get recipientId
    recp_map =
      Enum.reduce(recipients, %{}, fn recp, acc ->
        Map.put(acc, recp["email"], recp["id"])
      end)

    fields =
      Enum.map(signers, fn signer ->
        %{
          "recipientId" => recp_map[signer["email"]],
          "type" => "SIGNATURE",
          "pageNumber" => signer["page"],
          "x" => signer.x,
          "y" => signer.y,
          "width" => Map.get(signer, "width", 150),
          "height" => Map.get(signer, "height", 50)
        }
      end)

    case HTTPoison.post(
           "#{@base_url}/documents/#{document_id}/fields",
           Jason.encode!(fields),
           headers()
         ) do
      {:ok, %{status_code: 200}} ->
        :ok

      {:ok, %{status_code: code, body: body}} ->
        {:error, "Documenso add_fields failed: #{code} #{body}"}

      {:error, err} ->
        {:error, "HTTP add_fields HTTP error: #{inspect(err)}"}
    end
  end

  defp send_document(document_id) do
    case HTTPoison.post("#{@base_url}/documents/#{document_id}/send", "", headers()) do
      {:ok, %{status_code: 200, body: body}} ->
        Jason.decode(body)

      {:ok, %{status_code: code, body: body}} ->
        {:error, "Documenso send_document failed: #{code} #{body}"}

      {:error, err} ->
        {:error, "HTTP send error: #{inspect(err)}"}
    end
  end
end
