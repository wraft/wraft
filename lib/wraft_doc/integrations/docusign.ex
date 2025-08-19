defmodule WraftDoc.Integrations.DocuSign do
  @moduledoc """
  DocuSign API client using Authorization Code Grant flow.
  """

  require Logger

  alias WraftDoc.Client.Minio
  alias WraftDoc.Documents
  alias WraftDoc.Integrations

  @auth_base_url "https://account-d.docusign.com"
  @api_base_url "https://demo.docusign.net/restapi/v2.1"

  # defp get_config do
  #   Application.get_all_env(:document_signing) |> Enum.into(%{})
  # end

  # === Step 1: Authorization URL ===
  def get_authorization_url(org_id) do
    config = get_config(org_id)

    code_verifier = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

    WraftDoc.SessionCache.put("code", code_verifier)

    code_challenge = Base.url_encode64(:crypto.hash(:sha256, code_verifier), padding: false)

    query =
      URI.encode_query(%{
        response_type: "code",
        scope: "signature",
        client_id: config.config["client_id"],
        redirect_uri: config.config["redirect_uri"],
        code_challenge: code_challenge,
        code_challenge_method: "S256"
      })

    "#{@auth_base_url}/oauth/auth?#{query}"
  end

  def handle_callback(user, org_id, %{"code" => code}) do
    case exchange_code_for_token(code, org_id) do
      {:ok, token_data} ->
        # Auth.save_token(user, "docusign", token_data)
        WraftDoc.Integrations.update_metadata(
          get_config(org_id),
          token_data
        )

        Logger.info("DocuSign callback successful for user #{user.id}")
        # Redirect to home or any other page
        {:ok, "/"}

      {:error, reason} ->
        Logger.error("DocuSign callback error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # === Step 2: Exchange code for token ===

  def get_config(org_id) do
    Integrations.get_integration_by_provider(
      org_id,
      "docusign"
    )
  end

  def exchange_code_for_token(code, org_id) do
    config = get_config(org_id)
    {:ok, code_verifier} = WraftDoc.SessionCache.get("code")
    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    body =
      URI.encode_query(%{
        grant_type: "authorization_code",
        code: code,
        client_id: config.config["client_id"],
        client_secret: config.config["client_secret"],
        redirect_uri: config.config["redirect_uri"],
        code_verifier: code_verifier
      })

    token_url = "#{@auth_base_url}/oauth/token"

    case HTTPoison.post(token_url, body, headers) do
      {:ok, %{status_code: 200, body: body}} -> Jason.decode(body)
      {:ok, %{status_code: status, body: body}} -> {:error, "Failed: #{status}: #{body}"}
      {:error, error} -> {:error, inspect(error)}
    end
  end

  # defp generate_code_verifier do
  #   Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
  # end

  # defp create_code_challenge(code_verifier) do
  #   Base.url_encode64(:crypto.hash(:sha256, code_verifier), padding: false)
  # end

  # === Step 3: Send document for signing ===

  def send_document(document_id, org_id, signers_param) do
    document = Documents.get_instance(document_id, %{current_org_id: org_id})
    account_id = "40730823"
    access_token = get_config(org_id).metadata["access_token"]

    path =
      "organisations/#{org_id}/contents/#{document.instance_id}/#{document.instance_id}-v1.pdf"

    # Normalize signers into a list
    signers =
      case signers_param do
        %{"email" => _, "name" => _} = single -> [single]
        list when is_list(list) -> list
        _ -> []
      end

    with file_data <- Minio.get_object(path) do
      encoded = Base.encode64(file_data)

      envelope = %{
        emailSubject: "Please sign this document",
        documents: [
          %{
            documentBase64: encoded,
            name: "#{document.instance_id}.pdf",
            fileExtension: "pdf",
            documentId: "1"
          }
        ],
        recipients: %{
          signers:
            Enum.map(Enum.with_index(signers, 1), fn {%{"email" => email, "name" => name} =
                                                        signer, i} ->
              anchor = Map.get(signer, "anchor", "SIGN_HERE")

              %{
                email: email,
                name: name,
                recipientId: "#{i}",
                tabs: %{
                  signHereTabs: [
                    %{
                      anchorString: anchor,
                      anchorXOffset: "0",
                      anchorYOffset: "0",
                      anchorUnits: "pixels",
                      documentId: "1",
                      recipientId: "#{i}",
                      tabLabel: "SignHereTab"
                    }
                  ]
                }
              }
            end)
        },
        status: "sent"
      }

      headers = [
        {"Authorization", "Bearer #{access_token}"},
        {"Content-Type", "application/json"}
      ]

      url = "#{@api_base_url}/accounts/#{account_id}/envelopes"

      case HTTPoison.post(url, Jason.encode!(envelope), headers,
             timeout: 30_000,
             recv_timeout: 60_000
           ) do
        {:ok, %{status_code: 201, body: body}} ->
          Jason.decode(body)

        {:ok, %{status_code: status, body: body}} ->
          {:error, "Error: #{status} - #{body}"}

        {:error, err} ->
          {:error, inspect(err)}
      end
    end
  end

  # === Step 4: Get envelope status ===

  def get_envelope_status(access_token, account_id, envelope_id) do
    url = "#{@api_base_url}/accounts/#{account_id}/envelopes/#{envelope_id}"

    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"}
    ]

    case HTTPoison.get(url, headers) do
      {:ok, %{status_code: 200, body: body}} -> Jason.decode(body)
      {:ok, %{status_code: _status, body: body}} -> {:error, body}
      {:error, error} -> {:error, inspect(error)}
    end
  end

  # === Step 5: Download the signed document ===

  def download_document(access_token, account_id, envelope_id, document_id \\ "1") do
    url =
      "#{@api_base_url}/accounts/#{account_id}/envelopes/#{envelope_id}/documents/#{document_id}"

    headers = [
      {"Authorization", "Bearer #{access_token}"}
    ]

    case HTTPoison.get(url, headers) do
      {:ok, %{status_code: 200, body: pdf}} ->
        {:ok, pdf}

      {:ok, %{status_code: status, body: body}} ->
        {:error, "Failed to download document: #{status} - #{body}"}

      {:error, err} ->
        {:error, inspect(err)}
    end
  end
end
