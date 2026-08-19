# Changa data retention policy

Status: draft baseline for the REG-01 remediation (see
`Changa_Engineering_audit.md`). Written to give the platform a defensible,
stated retention schedule where none existed before — not yet reviewed by
counsel or entered into the Terms of Service / Privacy Policy text shown
in the mobile app. Treat the periods below as the engineering default
until a compliance review confirms or adjusts them.

## Why this exists

The platform aggregates member funds and moves them through mobile money
(M-Pesa, Airtel Money), which the Kenyan Data Protection Act and typical
PSP/CBK due-diligence review both treat as requiring a stated lawful basis,
a retention schedule, and a mechanism for erasure. Before REG-01, nothing
in the codebase set a retention period or supported erasure — this
document plus the `audit_events`, `kyc_profiles` and `consent_records`
tables it describes are the baseline that makes those obligations
answerable.

## Schedule

| Data category | Examples | Retention | Basis |
|---|---|---|---|
| Financial / transaction records | `contributions`, `budgets`, `budget_expenses`, the append-only `audit_events` rows tied to them | 7 years from the transaction date | Standard financial record-keeping expectation for a payments-adjacent platform; matches typical CBK/PSP guidance and Kenyan tax record requirements. |
| Security & authentication logs | `revoked_access_tokens`, `refresh_tokens` (post-expiry), structured request logs (see OBS-01) | 1 year from the event | Long enough to investigate a delayed-discovery incident; short enough that stale credential metadata isn't kept indefinitely. |
| Consent records | `consent_records` | Retained for the lifetime of the account, plus 7 years after account closure | This is itself the evidence that consent was given — deleting it on closure would remove the proof the record exists to provide. |
| KYC / identity data | `kyc_profiles` (once a real verification flow exists — currently unenforced scaffolding, see REG-01) | 5 years after the account is closed, or per applicable AML guidance at the time a verification flow ships | Placeholder — no identity documents are collected today, so nothing in this category currently holds real data. Revisit before enforcing any tier limit. |
| Everything else (profile info, chama/project metadata not tied to a settled transaction) | `users` (non-financial fields), `chamas`, `chama_members`, unresolved/cancelled projects | Deleted or anonymised within 90 days of account closure | Nothing regulatory requires holding this once the account is gone and there's no open financial record referencing it. |

## Erasure / account closure

Not yet implemented in application code. When it is, it needs to:

1. Anonymise (not hard-delete) any `User` row referenced by a financial
   record inside its 7-year retention window — replace `full_name`,
   `email`, `phone`, `avatar_url` with placeholders, keep the row so
   `contributions`/`audit_events` foreign keys stay valid.
2. Hard-delete rows with no retention obligation once their window closes
   (see table above).
3. Never delete or mutate `audit_events` rows themselves — anonymise the
   `before`/`after` JSON payloads' PII fields in place if needed, but the
   row, `actor_id` reference, and timeline must survive. This is why
   production deploys should `REVOKE UPDATE, DELETE ON audit_events FROM`
   the application's database role — see the docstring in
   `backend/app/models/audit.py`.

## What this document does not cover

- KYC tier enforcement itself — deliberately deferred, see the docstring
  on `KycProfile` in `backend/app/models/compliance.py`.
- A working data-export/portability endpoint (Data Protection Act
  portability right) — not built in this pass.
- Legal review of the actual retention periods above, or syncing them into
  the Terms of Service / Privacy Policy text in
  `mobile/changa/lib/features/auth/presentation/screens/policy_view_screen.dart`.
