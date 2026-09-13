# Stage 5.9: approved Health & Life design

Approved 2026-09-13: option A, the smaller initial category set, Health last in Quick Add, and health entries in Recent. Weight entry defaults to lb, as requested; kg remains available.

## Navigation

Keep the five primary tabs. Pets → a pet → Care / Health uses a segmented picker. Care keeps the existing care history and calorie totals. Health has date-grouped newest-first history, an All health/category filter, tap-to-edit rows, and an Add health entry button that preselects the pet.

Home Quick Add order is Food, Medicine, Litter, Health. Quick Add Health opens an editor requiring a pet selection. A saved health entry appears in Recent; tapping it opens that pet's Health timeline.

Recent combines care and health rows in time order. It keeps the latest entry per pet/category from the last seven days, excluding future timestamps. Each health category is separate, so weight does not hide a recent vet visit or general note.

## Initial records

| Category | Fields beyond the shared fields | Example |
| --- | --- | --- |
| Weight | Finite positive value and explicit lb/kg unit | 9.5 lb |
| Vet visit | Optional clinic/provider | Annual exam |
| Procedure | Optional clinic/provider; details in title/notes | Dental cleaning or surgery |
| General note | Title and notes | Recovery progress or adoption milestone |

Shared fields: stable ID, required pet ID, happened-at date/time, immutable created-at time, updated-at time, title, notes, and optional clinic/provider text. All entries require a nonblank title. Weight starts with the title “Weight”; changing category replaces the default category title while preserving a custom title.

Values retain their entered unit; changing lb/kg does not convert the number. Editing preserves ID/created-at and replaces only that health entry. Health entries do not affect food calorie totals, saved care options, or reminder history.

## Implementation and acceptance

- Separate `HealthEntry`/typed weight data, SwiftData record, and health repository.
- Pet-scoped timeline, category filter, empty state, required-pet add form, and historical editor.
- Health Quick Add at the end and mixed chronological Recent with links to pet Health.
- Explicit save errors keep the editor open for retry; Cancel writes nothing.
- Test required pet/title and positive finite weight, unit retention, category changes, edit identity, pet isolation, Recent grouping/cutoff, disk persistence, and the Quick Add/Recent/edit/relaunch UI path.
- Include health records in test-data and development reset while preserving existing care workflows.

Follow-up reminders, charts, attachments/photos, imports, custom categories, and provider integrations are deferred. Vaccinations, conditions, symptoms, and structured test results are not separate initial categories; they can be described in general notes.

Medication interaction checking has been removed from scope at the user's request. No interaction proposal or implementation is planned.
