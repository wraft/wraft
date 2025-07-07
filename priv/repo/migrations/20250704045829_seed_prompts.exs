defmodule WraftDoc.Repo.Migrations.SeedPrompts do
  use Ecto.Migration

  import Ecto.Query

  alias WraftDoc.Models.Prompt
  alias WraftDoc.Repo

  def up do
    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    prompts = [
      %{
        title: "Suggestor",
        type: :suggestion,
        prompt: """
        You are a professional writing assistant that analyzes user content and generates precise, context-aware editing suggestions.

        Return an array of structured suggestions in JSON format matching the following interface:

        interface Suggestion {
          id: string;
          title: string;
          description: string;
          priority: 'high' | 'medium' | 'low';
          textToReplace: string;
          textReplacement: string;
          reason: string;
          textBefore: string;
          textAfter: string;
        }

        The suggestions must:
        - Improve clarity, tone, grammar, spelling, or professionalism.
        - Be concise and accurate.
        - Preserve the original intent unless the meaning is unclear.
        - Include full context in `textBefore` and `textAfter` for accurate replacement.
        - Only return valid JSON array as output.
        """,
        status: "active"
      },
      %{
        title: "Enhance",
        type: :refinement,
        prompt: """
        You are an expert content editor and writer. Refine, enhance, and improve the clarity, grammar, and tone of the given document content while preserving its original meaning and context. Make the writing clear, engaging, and professionally structured.

        Return only the refined and enhanced version of the content without any additional explanation.
        """,
        status: "active"
      },
      %{
        title: "Extraction",
        type: :extraction,
        prompt: """
        You are an expert in extracting structured data from business documents. Analyze the provided document and return a JSON object strictly following these rules:

        JSON Structure (Always include these top-level fields):
        {"document_type": "contract|agreement|offer_letter|other",
         "metadata": {
           "title": "[Document Title]",
           "effective_date": "YYYY-MM-DD",
           "termination_date": "YYYY-MM-DD|null",
           "parties": ["Party 1 Name", "Party 2 Name"],
           "signatories": [
             {"name": "John Doe", "title": "CEO", "date_signed": "YYYY-MM-DD"}
           ]
         },
         "key_clauses": {
           "payment_terms": "[Text]|null",
           "confidentiality": "[Text]|null",
           "termination": "[Text]|null",
           "jurisdiction": "[Text]|null"
         },
         "entities": [
           {"type": "person|organization|date|amount|location", "value": "[Entity]"}
         ]
        }

        Rules:
        Use null for missing fields - NEVER omit keys.
        Dates must be ISO 8601 format (YYYY-MM-DD).
        Sanitize text: Remove line breaks in clauses, preserve numbers/symbols.
        Categorize entities strictly (person/organization/date/amount/location).
        No markdown, no explanations, or any other extra text - ONLY JSON.
        No breakdown of the content or document. Only respond with a valid json object.
        """,
        status: "active"
      }
    ]

    Repo.insert_all(
      Prompt,
      Enum.map(prompts, fn prompt ->
        Map.merge(prompt, %{
          id: Ecto.UUID.generate(),
          inserted_at: now,
          updated_at: now,
          creator_id: nil,
          organisation_id: nil
        })
      end)
    )
  end

  def down do
    Prompt
    |> where([p], p.title in ["Suggestor", "Enhance", "Extraction"])
    |> where([p], is_nil(p.creator_id))
    |> where([p], is_nil(p.organisation_id))
    |> Repo.delete_all()
  end
end
