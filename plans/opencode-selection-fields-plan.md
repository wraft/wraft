# Plan: Adding Selection Fields to Internal Form Models

## Overview
This plan outlines the progressive implementation of selection fields (specifically a "Select" field type) for the internal Form models in WraftDoc. The approach ensures full backend functionality, maintains backward compatibility, and avoids breaking existing interactions. Implementation starts with core backend changes, followed by frontend integration.

## Current State Analysis
- **Form Structure**: Forms (`WraftDoc.Forms.Form`) associate with fields via `FormField`, linked to `Field` and `FieldType`.
- **Existing Selection Support**: Field types like "Radio Button", "Drop Down", and "Checkbox" support selections via the "options" validation rule in `ValidationType.cast/1`.
- **Backend Readiness**: Validation and form handling already support options, but no dedicated "Select" field type exists.
- **Frontend Context**: The form builder at `http://localhost:3000/forms/:id` (assumed SPA) consumes `/api/v1/forms` endpoints.
- **Progressive Strategy**: Backend-first to minimize risk, with frontend as a separate phase.

## Implementation Phases

### Phase 1: Backend Changes (Non-Breaking)
1. **Add "Select" Field Type**:
   - Update `priv/repo/migrations/20230808094548_create_basic_field_types.exs` to include:
     ```
     %{
       name: "Select",
       meta: %{"allowed validations": ["required", "options"]},
       description: "A select field for single-choice selections",
       validations: [],
       inserted_at: NaiveDateTime.local_now(),
       updated_at: NaiveDateTime.local_now()
     }
     ```
   - This leverages existing validation logic.

2. **Validation Enhancements**:
   - Confirm `ValidationType.cast/1` handles "options" (already does).
   - Ensure `Forms.create_form_field/3` enforces allowed validations per field type (already implemented).

3. **Form CRUD Compatibility**:
   - No changes to `FormController` or `Forms` context required, as they support arbitrary field types.
   - Verify with API tests for `/api/v1/forms` endpoints.

4. **Form Entry Support**:
   - `FormEntry` and `Forms.create_form_entry/3` already process selection fields.
   - Ensure submissions store selected values correctly.

### Phase 2: Frontend Integration (Progressive)
1. **Form Builder UI Updates**:
   - Add "Select" as a field type option in the builder at `/forms/:id`.
   - Implement options input UI for "Select", "Radio Button", "Drop Down", and "Checkbox" fields.
   - Submit options via `validations` (e.g., `{"rule": "options", "value": ["opt1", "opt2"], "multiple": false}`).

2. **Form Rendering**:
   - Render "Select" fields as `<select>` elements with options from validations.

3. **Client-Side Validation**:
   - Validate selections against defined options.

### Phase 3: Testing and Rollout
1. **API Testing**: Extend `test/wraft_doc/forms/` to cover "Select" fields.
2. **Integration Testing**: Test full CRUD and submissions.
3. **Migration**: Apply seed changes without data impact.

## Gherkin Specs for Form Builder
These BDD scenarios build on existing form features.

### Feature: Form Builder with Selection Fields

**Scenario: Create a form with a Select field**
  Given the user is on the form builder page at `/forms/new`
  When the user adds a new field of type "Select"
  And defines options: "Option A", "Option B", "Option C"
  And sets it as required
  And saves the form
  Then the form is created successfully
  And the Select field appears in the form preview with the defined options

**Scenario: Edit an existing form to add Select field**
  Given the user is editing an existing form at `/forms/{form_id}`
  When the user adds a Select field with options
  And updates the form
  Then the form is updated without breaking existing fields
  And the new Select field is available for form entries

**Scenario: Submit form entry with Select field**
  Given a form with a Select field exists
  When the user submits an entry selecting "Option B"
  Then the entry is saved successfully
  And the selected value is stored in the form data

**Scenario: Validate Select field options**
  Given a form with a Select field having defined options
  When the user tries to submit with an invalid option
  Then validation fails with error "Invalid selection"

**Scenario: Delete a Select field from form**
  Given a form with a Select field
  When the user removes the Select field
  And saves the form
  Then the form is updated
  And existing entries remain valid

**Scenario: Progressive enhancement - existing forms unaffected**
  Given an existing form without Select fields
  When the user views or edits the form
  Then no changes occur to existing fields or functionality
  And Select fields can be added optionally

## Risks and Mitigations
- **Breaking Changes**: Minimal risk due to reuse of existing structures; test thoroughly.
- **Frontend Dependency**: Phase frontend separately to avoid blocking backend.
- **Data Migration**: Seed update is safe; no schema changes needed.

## Next Steps
- Review and approve Phase 1 backend changes.
- Implement frontend in parallel.
- Integrate BDD tests using the Gherkin specs.
