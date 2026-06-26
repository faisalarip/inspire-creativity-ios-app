# Enhancement backlog

A human-seeded queue of enhancement ideas for the autonomous dev loop
(`docs/loop/README.md`). The loop pulls the top unblocked item to **propose**
(it still waits for your approval before implementing). Reorder freely; keep
items small and shippable. Delete or check off as they ship.

Format per item: a one-line outcome, then optional notes / the test that proves
it. Keep each to a single, scoped change.

## Candidates (top = next)

- [ ] **Finish code-egress (export `.swift` / copy-without-imports / deep link).**
      In-progress on branch `feat/code-export` (rebase onto `main` first). This
      is the roadmap flagship — "win on code egress, not catalog size."
      Test: `CodeExportTests` (filename sanitization, import-stripping, deep links).
- [ ] **Verify `is_pro` purchase gating fails *closed*, not open.** Revenue bug
      from the pre-submission roadmap — a failed entitlement check must lock Pro
      features, never unlock them. Test: a ViewModel test with a throwing/empty
      entitlement source asserting Pro stays locked.
- [ ] *(add more — one scoped, testable outcome per line)*

## Shipped

<!-- Move items here with the build number once they land in TestFlight, e.g.
- [x] <thing> — build #N -->

---

> The first few loop cycles should be **TestFlight-only** and ideally trivial,
> safe changes — prove the pipeline before trusting it with anything that
> auto-submits toward App Review.
