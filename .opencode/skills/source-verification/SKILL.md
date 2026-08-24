---
name: source-verification
description: Finding and validating external manufacturer/technical information for AluVis - source priority, citation requirements, conflict handling. Use when researching profile dimensions, débitage formulas, certifications, or any engineering fact before it enters the codebase.
---

# Source verification (AluVis)

Procedure for finding and validating external technical/manufacturer
information. A fact is only adoptable after it survives this procedure.

## Source priority

1. Manufacturer technical documentation (descriptifs, PROFILOSCOPE sheets,
   débitage tables, technical drawings)
2. Official certifications / technical assessments (QUALICOAT, QUALANOD,
   TECNITAS avis technique, CEBTP)
3. Official system manuals
4. Official manufacturer product documentation (their own site/brochures)
5. Authoritative industry documentation (standards, AFNOR/EU norms)
6. Trade references, distributor listings, forums — supporting evidence
   only; NEVER the sole basis for an engineering value

## Recording an adopted fact

Every adopted technical fact gets recorded in `docs/VERIFIED_SOURCES.md`
with:

- manufacturer
- system/series
- exact profile/product reference (e.g. "14 621", not "the traverse")
- value/formula, with units
- source document (title, identity, date)
- page/section
- URL or file path (for local PDFs: path + how extracted)
- source grade (which priority tier above)
- directly stated vs derived (if derived: show the derivation)

## Formulas — extra care

- Verify every symbol and operator at high resolution; re-render/re-read
  rather than guess a digit (this project has already corrected two
  low-resolution misreads of cut formulas).
- Verify units on every term.
- Verify the exact profile/configuration the formula applies to —
  manufacturer tables are frequently per-variant (e.g. one deduction per
  montant pairing).
- Verify all stated conditions and exceptions.
- Reproduce published examples when the document provides any; a formula
  that cannot reproduce its own example is not verified.

## Conflicts

- Never silently pick one value.
- Report the conflict explicitly (see the 6063-vs-6060 alloy discrepancy in
  `docs/VERIFIED_SOURCES.md` for the expected treatment: transcribe both,
  cite both, choose nothing).
- Prefer the stronger source per the priority list.

## Hard rules

- When verified information enters the codebase, update
  `docs/VERIFIED_SOURCES.md` in the same change.
- Never turn weak evidence into a hardcoded engineering rule. Weak evidence
  may at most justify a clearly-labelled placeholder.
- Absence of a source means the value stays unknown (see the
  `aluminium-domain` skill's unknown markers).
