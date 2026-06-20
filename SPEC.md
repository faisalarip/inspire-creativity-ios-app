# Spec — <Feature Name>

> **How to use this file (spec-driven workflow):**
> 1. Copy this template per feature (e.g. `docs/specs/<feature>.md`) or fill it in here for the active piece of work.
> 2. Fill it out **before** writing code. Keep it short — a spec is a contract, not an essay.
> 3. Drive Claude with it: `/superpowers:brainstorming` → refine this spec → enter **plan mode** (Shift+Tab) → `/superpowers:executing-plans`.
> 4. Commit the spec alongside the code so the "why" stays reviewable in git.
> 5. Delete sections that don't apply. An empty heading is a smell — either fill it or cut it.

---

## 1. Problem / Goal
<!-- One paragraph. What user need or product gap does this close? Why now? -->


## 2. Non-Goals
<!-- Explicitly out of scope. This is what stops scope creep. -->
-

## 3. User Stories / Acceptance Criteria
<!-- Testable statements. "As a <user>, I can <action>, so that <outcome>." Each should map to a test. -->
- [ ] As a …, I can …, so that …
- [ ] Given … when … then …

## 4. UX / Design
<!-- Figma link, screens affected, new vs. modified views. Note dark-mode, Dynamic Type, accessibility. -->
- Figma:
- Screens / views touched:
- Empty / loading / error states:

## 5. Architecture & Affected Code
<!-- This app is MVVM + light Clean Architecture, single Xcode target (iOS 17+). Map the change onto the layers. -->

| Layer | File(s) | New / Modified | Notes |
|-------|---------|----------------|-------|
| Presentation (SwiftUI `View`) | `InspireCreativityApp/Features/…` | | |
| ViewModel (`@MainActor ObservableObject`) | | | `@Published` state, no view imports |
| Domain (value-type entities) | `InspireCreativityApp/Models/…` | | structs/enums, no framework deps |
| Repository (protocol + impl) | `InspireCreativityApp/Repositories/…` | | protocol first, then concrete |
| Design System | `InspireCreativityApp/DesignSystem/…` | | reuse `Theme`, existing components |
| Services / Backend | `InspireCreativityApp/Auth`, `Store`, `supabase/` | | |

**Data flow:** View → ViewModel → Repository (protocol) → concrete impl (in-memory / UserDefaults / Supabase).

## 6. Data & Backend
<!-- Supabase tables, RLS, migrations, seed data. Reference supabase_schema.sql / supabase/. -->
- New / changed tables:
- RLS policy changes:
- Migration needed? (Y/N):
- Local model ↔ row mapping:

## 7. Edge Cases & Risks
<!-- iOS 17 vs 18 (MeshGradient/aurora), offline, auth-expired, purchase-restore, empty catalog, race conditions. -->
-

## 8. Test Plan
<!-- This repo uses XCTest in InspireCreativityAppTests/. Name the tests you'll add. TDD: write the failing test first. -->
- Unit:
- ViewModel:
- Repository (with mock):
- Manual / simulator check (iOS 18 sim recommended):

## 9. Rollout / Done Criteria
<!-- What "done" means. Build green, tests pass, design matches, no new warnings. -->
- [ ] `Cmd-B` clean build, no new warnings
- [ ] All new + existing tests pass
- [ ] Matches Figma / design intent
- [ ] Acceptance criteria in §3 all checked

## 10. Open Questions
<!-- Anything blocking. Resolve before implementation, or note the assumption you're proceeding on. -->
-
