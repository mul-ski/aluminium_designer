# Verified Sources

Every fabrication fact seeded into ALUVIS must trace to an identified
source document. This file is the citation record: what was taken from
where, how it was extracted, and — just as important — what the source
does **not** state. Absence means "unknown": it is never filled with an
estimate, a value from another system, or domain-knowledge "typical"
numbers (`thermalBreak: null` ≠ `false`; `Profile.width/depth/weightPerMeter
== 0` = not stated, not a measured zero).

## How to read this ledger

Adoption procedure and source-priority tiers are defined in
`.opencode/skills/source-verification/SKILL.md`. Conventions used
throughout the records below:

- **Units** are millimetres unless a column/table says otherwise (inertias
  are cm⁴, coating thicknesses µm, roulette loads kg).
- **Directly stated vs derived**: every value below is directly stated on
  the cited page unless explicitly marked "derived" or "sub-dim" with the
  derivation shown.
- **Source grade** follows the skill's priority list; the S-1 document is
  tier 1 (manufacturer technical documentation) with its embedded
  certificates at tier 2.

## S-1: Descriptif Coulissant Série 14 600 — MAGHREB EXTRUSION

| | |
|---|---|
| **File** | `6 - 14600 SERIES COULISSANTES.pdf` (31 pages, client-supplied) |
| **Identity** | Title page text: "DESCRIPTIF COULISSANT SERIE 14 600 MAGHREB EXTRUSION". Descriptif signed Larache, 14/10/2024. Contact block: Maghreb Extrusion, 95 rue Brahim Nakaï, Mâarif, Casablanca (contact@maghrebextrusion.com). |
| **Certificates included in the same PDF** | Certificat d'alliage EXTRUMAROC 2 S.A.R.L (14/10/2024); Certificat de laquage EXTRUMAROC, licence QUALICOAT N° 1106 mention SEASIDE (07/03/2025); Certificat d'anodisation EXTRUMAROC, licence QUALANOD N° 1902; Avis technique TECNITAS-Maroc réf AE/SC/BGC N° 1627/2016, 09/05/2016 ("série 14-600 Coulissante de la gamme PERIAL ALUMINIUM agréée"); system summary sheet (TECNITAS BGC N° 1627/2016, AEV classes, DIM). |
| **Seeded as** | manufacturer `builtin-maghreb-extrusion` "Maghreb Extrusion (ME)", system `builtin-me-14600` "Série 14600 Coulissant". |

### Extraction method

- PDF pages 1–3 and 26–31 have a text layer (extracted with `pdftotext`).
- PDF pages 4–25 and 27 are image-only drawings (PROFILOSCOPE sheets,
  coupes, débitage table). They were rendered to PNG with `pdftoppm`
  (110 dpi first pass, 150 dpi re-renders for every ambiguous label) and
  transcribed **visually** — no OCR tooling was used or needed.
- Any value that was unclear at 110 dpi was re-read at 150 dpi before
  being accepted. Two first-pass readings were corrected this way and
  are recorded below under "Corrections during transcription".

### Page map

| PDF page | Content |
|---|---|
| 1–3 | Descriptif: product, alloy (6063 via EXTRUMAROC), dormants 44/66, montants 56/69/41, vitrage feuillure 26 / verre 6–22, drainage, AEV classes CEBTP, laquage 60 µ QUALICOAT, anodisation 15 µ QUALANOD |
| 4 | PROFILOSCOPE — DORMANTS: 14 626, 14 627, 14 628 |
| 5 | PROFILOSCOPE — DORMANTS: 14 617, 14 640, 14 618 |
| 6 | PROFILOSCOPE — DORMANTS FRAPPE: 14 818, 14 820 |
| 7 | PROFILOSCOPE — MONTANTS LATERAUX: 14 632, 14 633, 14 622, 14 623 |
| 8 | PROFILOSCOPE — MONTANTS CENTRAUX: 14 619, 14 620, 14 630, 14 650 |
| 9 | PROFILOSCOPE — TRAVERSE HAUTE ET BASSE: 14 621, 14 631; CAPOT DE FINITION: 14 604, 14 603 |
| 10 | PROFILOSCOPE — FINITION GALANDAGE: 14 639; CHICANE 4 VANTAAUX 2 RAILS: 14 624; CHICANE POUR CHASSIS D'ANGLE: 14 634, 14 635 |
| 11 | PROFILOSCOPE — DORMANT MONO RAIL: 14 638; DORMANT COULISSE / FIXE: 14 637; COMPLEMENT MULTI RAILS: 14 625; PROFILE FINITION COULIFIX: 14 610; MONTANT CENTRAL COULIFIX: 14 643 |
| 12 | PROFILOSCOPE — PROFILES DE LIAISON: 14 827, 14 817, 85 627; PARCLOSES: 14 810, 14 809, 14 809/1, 14 819; COUVRES JOINTS: 14 601, 14 602 |
| 13 | Configurations (elevations, no profile numbers) |
| 14 | COUPE — galandage mono rail (dims 55, 92) |
| 15 | COUPE — assembly dims (35.4/56/46/44.5; 41.3/19.3/115.5; 69.2/28.8; 41.3/18.9/101.5; 60.3; 41.3/75) |
| 16 | COUPE — cross-sections (context) |
| 17 | COUPE — VUE PROFILE COULIFIX, VUE PROFILE D'ANGLE (no dims) |
| 18 | COUPE — rail widths 87 / 87 / 108.3 / 108.3 / 110.4 |
| 19 | COUPE — galandage 2 rails (dim 96) / 3 rails (accessory TC1040) |
| 20 | COUPE — COULISSANT 2 VANTAAUX: TRAVERSE (L−64)/2 formulas; leaf dims 63, 98.4, 33.6/36.8/35.4, 7.7; AC-822 deflecteur refs |
| 21 | COUPE — COULISSANT 2 VANTAAUX (variant): confirms 14 632 = 69.2 deep, 14 620 = 41.3 face/31.3 sub, 14 626 in frame |
| 22 | COUPE — DORMANT AVEC CACHE RAIL: labels 14 603, 14 604 |
| 23 | Inertia table: per-profile IXX values + 8 assembly combinations (see below) |
| 24 | DEBITAGE table (cut lengths per configuration — see below) |
| 25 | ACCESSOIRES: AC-600…AC-650, joints JO-609…JO-624 (not seeded — no `Profile` model fit; listed here for the record) |
| 26 | TECNITAS avis technique BGC N° 1627/2016 |
| 27 | System summary: "Serie : 14600 PERIAL ALUMINIUM — DIM : 1600 x 1800 / 2500 x 2500", AEV classes, thermal/acoustic isolation levels, alloy "6060 AFNOR" note |
| 28–31 | (text layer) certificates listed above + contact block |

## System-level facts (stored in `ProfileSystemMetadata`)

| Fact | Value | Source |
|---|---|---|
| Frame (dormant) depth options | 44 mm ou 66 mm (text); exact sheet values 44.00 / 66.34 | pp. 1–3; pp. 4–6 |
| Sash lateral stile depth options | 56 mm ou 69 mm (text); exact sheet values 56.00 / 69.20 | pp. 1–3; p. 7 |
| Central mullion | "tubulaire de 41 mm" — this is the tube **face** (41.3 on sheets). The mullion *depth* is not stated as a system value, so `sashMeetingStileDepthMm` stays `null` rather than holding a face value under a depth name | pp. 1–3; pp. 8, 21 |
| Glazing rebate (feuillure) | 26 mm | pp. 1–3 |
| Glass thickness | 6 à 22 mm | pp. 1–3 |
| Thermal break | **not stated anywhere in the document** → `thermalBreak: null` | (absence) |
| Assembly | dormants assemblés en coupe d'onglet avec équerres; ouvrant à prise en feuillure des vitrages en portefeuille | pp. 1–3 |
| Drainage | trous oblongs sur la traverse basse du dormant + busettes à clapets anti-retour | pp. 1–3 |
| Finish | laquage 60 µ QUALICOAT (licence N° 1106 SEASIDE) / anodisation 15 µ QUALANOD (N° 1902) | pp. 1–3; pp. 28–31 |
| Alloy | 6063 (EXTRUMAROC certificat d'alliage). **Discrepancy noted:** the p. 27 summary sheet says "alliaged'aluminium 6060 suivant normes AFNOR". Both statements are transcribed verbatim into `finishNote`; neither is "corrected". | p. 1–3 + certificat; p. 27 |
| Certified test dimensions | "DIM : 1600 x 1800 / 2500 x 2500" → stored as the two documented envelopes in `dimensionLimits`. This is the **only** dimension-limit statement in the whole document; no per-configuration max table exists. | p. 27 |
| AEV (not seeded — no model field) | air A1–A4; eau E1A–E9A, E1B–E7B; vent V1A–V5A/V1B–V5B/V1C–V5C (flèche A 1/150, B 1/200, C 1/300); banc CEBTP | pp. 1–3; p. 27 |
| Acoustic (not seeded) | AC1/28 dB – AC4/40 dB | p. 27 |

## Profile transcription (38 profiles, stored in `ProfileSystem.profiles`)

Conventions: **width** = visible face dimension, **depth** = wall-plane
dimension, as drawn on the profile's own sheet. `0` = the sheet does not
label that dimension (unknown). `weightPerMeter` = 0 for all (no sheet
states weights). `type` follows the sheet's own section heading.
Inertias are in cm⁴ as printed ("Inertie en cm4") and ARE seeded as
`Profile.inertiaIxxCm4`/`inertiaIyyCm4` since the model gained the
fields: 20 of 38 profiles carry both printed values; 17 state no
inertia (seeded 0/0); **14 650's single printed "69.47" has no axis
attribution on the sheet, so both fields stay 0 until an external
source confirms which axis it is** — storing it as IXX would be
inference (open verification item).

| Réf | Type | width | depth | IXX / IYY | Sheet | Notes |
|---|---|---|---|---|---|---|
| 14 626 | dormant | 44.66 | 66.34 | 7.9 / 26.14 | p. 4 | |
| 14 627 | dormant | 44.4 | 66.34 | 6.66 / 23.16 | p. 4 | |
| 14 628 | dormant | 44.4 | 66.34 | 10.24 / 27.22 | p. 4 | |
| 14 617 | dormant | 44.4 | 44.00 | 4.95 / 13.65 | p. 5 | |
| 14 640 | dormant | **0 (unlabeled)** | 68.15 | 6.7 / 17.07 | p. 5 | Under the sheet's DORMANTS heading. Only horizontal dims labeled: 68.15 overall, 42.00 clip-stem spacing (no model field). p. 20 coupe shows it used at a galandage corner with the TRAVERSE (L−64)/2 formula. |
| 14 618 | dormant | 44.4 | 44.00 | 9.13 / 16.90 | p. 5 | |
| 14 818 | dormant | 42.75 | 66.34 | 3 / 13.35 | p. 6 | DORMANTS FRAPPE |
| 14 820 | dormant | 42.70 | 44.00 | 3.67 / 6.51 | p. 6 | DORMANTS FRAPPE |
| 14 638 | dormant | 44.66 | 42.00 | 4.37 / 4.067 | p. 11 | DORMANT MONO RAIL |
| 14 637 | dormant | 44.61 | 68.35 | 6.21 / 22.6 | p. 11 | DORMANT COULISSE / FIXE |
| 14 632 | montant | 33.4 | 69.2 | 7.1 / 14.7 | p. 7 | MONTANTS LATERAUX |
| 14 633 | montant | **0 (unlabeled)** | 69.2 | 20.16 / 23.3 | p. 7 | Reinforced companion of 14 632; face width not labeled (sheet dims: 26 sub-dim, 28 hook) |
| 14 622 | montant | 33.00 | 56 | 6.95 / 4.8 | p. 7 | |
| 14 623 | montant | **0 (unlabeled)** | 56 | 10.93 / 13.44 | p. 7 | Reinforced companion of 14 622; face width not labeled |
| 14 619 | mullion | 41.3 | 33.60 | 4.67 / 3.405 | p. 8 | |
| 14 620 | mullion | 41.3 | **0 (unlabeled)** | 13.80 / 5.7 | p. 8 | Demi-rond; p. 21 confirms 41.3 face / 31.3 sub-dim |
| 14 630 | mullion | 41.3 | **0 (unlabeled)** | 37 / 10.23 | p. 8 | |
| 14 650 | mullion | **0 (unlabeled)** | 96.19 | 69.47 | p. 8 | Only the vertical 96.19 is labeled |
| 14 643 | mullion | 40.00 | 41.80 | — | p. 11 | MONTANT CENTRAL COULIFIX |
| 14 621 | traverse | **0 (unlabeled)** | 63 | 4.24 / 9.52 | p. 9 | Pairs with 56-face stiles (débitage p. 24, red pairing) |
| 14 631 | traverse | **0 (unlabeled)** | 63.00 | 4.93 / 10.2 | p. 9 | Pairs with 69.2-face stiles (débitage p. 24); sub-dims 1.80/1.50 |
| 14 640 | — | see dormant row above | | | | Classified dormant per its sheet heading |
| 14 603 | other | 0 | 0 | — | p. 9 | Cache rail intérieur et extérieur; no dims on sheet |
| 14 604 | other | 0 | 0 | — | p. 9 | Cache rail intérieur; no dims on sheet |
| 14 639 | other | 28.50 | 16.90 | — | p. 10 | FINITION GALANDAGE |
| 14 624 | other | 25.80 | **0 (unlabeled)** | — | p. 10 | CHICANE 4 VANTAAUX 2 RAILS; single labeled dim |
| 14 634 | other | 26.30 | 42.70 | — | p. 10 | CHICANE POUR CHASSIS D'ANGLE; sub-dim 14.00 (top clip, no model field) |
| 14 635 | other | **0 (unlabeled)** | 63.70 | — | p. 10 | CHICANE POUR CHASSIS D'ANGLE; single labeled dim |
| 14 625 | other | 44.4 | 42.00 | 3.2 / 8.12 | p. 11 | COMPLEMENT MULTI RAILS (own heading → `other`) |
| 14 610 | other | 41.00 | 23.10 | — | p. 11 | PROFILE FINITION COULIFIX |
| 14 827 | other | 44.00 | 8.70 | — | p. 12 | PROFILES DE LIAISON |
| 14 817 | other | 47.90 | **0 (unlabeled)** | — | p. 12 | PROFILES DE LIAISON; single labeled dim |
| 85 627 | other | 0 | 0 | — | p. 12 | PROFILES DE LIAISON; no dims on sheet |
| 14 810 | other | 22.5 | 19.5 | — | p. 12 | PARCLOSES |
| 14 809 | other | 16 | 19.5 | — | p. 12 | PARCLOSES |
| 14 809/1 | other | 12.5 | 19.5 | — | p. 12 | PARCLOSES |
| 14 819 | other | 4.50 | **0 (unlabeled)** | — | p. 12 | PARCLOSES; single labeled dim |
| 14 601 | other | **0 (unlabeled)** | 26 | — | p. 12 | COUVRES JOINTS; only height labeled |
| 14 602 | other | **0 (unlabeled)** | 33.1 | — | p. 12 | COUVRES JOINTS; only height labeled |

Assembly inertia combinations (p. 23, not seeded — recorded for future
structural work): IXX = 138.74, 136.50, 74, 74, 41.67, 27.60, 18.47,
9.34 cm⁴ for the drawn montant-central combinations of 14 650 / 14 630 /
14 620 / 14 619.

## Débitage (cut-length) table — p. 24, transcribed and now fully encoded as rules

The débitage table gives real cut formulas per configuration (2 vantaux /
3 vantaux avec fixe / 4 vantaux; L = unit width, H = unit height):

| Profile | 2 vantaux | 3 vantaux (avec fixe) | 4 vantaux | Pairing (red schema on p. 24) |
|---|---|---|---|---|
| Dormant 14 617 / 14 627 | 2+2 × (L ; H) | 2+2 × (L ; H) | 2+2 × (L ; H) | — |
| Dormant 14 618 / 14 628 (+ 14 626) | 2+2 × (L+46 ; H+46) | same | same | "DOUBLE EQUERRE POUR 14627 / 14628 / 14626" |
| Montant latéral 14 622/623/632/633 | 2 × (H−74) | 2 × (H−74) | 4 × (H−74) | crochet AC-608 pour 14622/14623; AC-608/C pour 14632/14633 |
| Montant central 14 619/620/630 | 2 × (H−74) | 2 × (H−74) | 4 × (H−74) | bouchon AC-630 pour 14 630; AC-620/AC-621 pour 14 620 |
| Traverse 14 621 | 4 × (L−64)/2 | 6 × (L−25)/3 | 8 × (L−60)/4 | 14 621 ↔ montants 14 622/14 623 (56 face) |
| Traverse 14 631 | 4 × (L−85)/2 | 6 × (L−47)/3 | 8 × (L−106)/4 | 14 631 ↔ montants 14 632/14 633 (69.2 face) |
| Chicane 14 624 | — | — | 1 × (H−92) | |

p. 20 additionally labels TRAVERSE (L−64)/2 on the 2-vantaux coupe
(galandage corner variant with 14 640 / 14 623), consistent with the
table. Accessories on p. 24: AC-600 équerre ×4, AC-604 kit étanchéité,
verrou encastré (AC-605+AC-608 ou AC-606+AC-608), roulettes AC-6001
30 kg → AC-6005 220 kg ("AC-6001/AC-6002/AC-6003 uniquement pour 14 631"),
gâche AC-607, joint brosse JO-609/JO-609F, joint vitrage JO610–JO624
(6–24 mm glass).

**Encoding status** (C5 → C6a → C6b → C6c): the COMPLETE débitage table
is now a real `SystemRuleSet` (`meSerie14600RuleSet`,
`lib/core/data/me_14600_rule_set.dart`) — all three configuration
columns ("2 vantaux", "3 vantaux (avec fixe)", "4 vantaux"), all seven
rows, every documented cell:

- Dormant 14 617 / 14 627: `2+2 × (L ; H)` — four role-scoped rules
  per column (top/bottom → L, left/right → H), one piece per placement.
- Dormant 14 618 / 14 628 / 14 626: `2+2 × (L+46 ; H+46)` (double-équerre
  row) — same four-role mapping. **Source-text tension recorded:** the
  pairing note reads "DOUBLE EQUERRE POUR 14627 / 14628 / 14626" while
  the row itself names 14 618 / 14 628 / 14 626 (14 627 belongs to the
  `(L ; H)` row). Both statements are kept verbatim above; neither is
  corrected, and the encoded reference set follows the ROW HEADERS
  ({14 618, 14 628, 14 626}) because the lengths live on the row, not
  the note.
- Montant latéral 14 622/623/632/633: `2 × (H−74)` — left/right rules,
  one piece per placement.
- Montant central 14 619/620/630: `2 × (H−74)` — intermediate-role rule;
  one placement covers both meeting stiles (fixed(2) per placement).
  Mullions 14 650 / 14 643 are NOT named by this row and stay unmatched;
  the row's accessory notes (bouchons AC-630, AC-620/AC-621) are
  hardware and not encoded.
- Traverse 14 621: `4 × (L−64)/2` at 2 vantaux / `6 × (L−25)/3` at 3
  vantaux / `8 × (L−60)/4` at 4 vantaux — top/bottom rules; one
  placement spans every panel's track segment, so fixedCount = panels
  (2, 3 or 4) per placement.
- Traverse 14 631: `4 × (L−85)/2` at 2 vantaux / `6 × (L−47)/3` at 3
  vantaux / `8 × (L−106)/4` at 4 vantaux — same placement mapping as
  14 621.
- Chicane 14 624: `1 × (H−92)` — 4-vantaux-only row; the ONLY rule
  without a role condition, because the source states no position for
  the chicane and gating it to a role would fabricate a positional
  claim the table never makes (any placed usage yields its documented
  piece; multiples compose via `usage.quantity`). Its pairing/accessory
  context on p. 24 is hardware, not encoded.

At 4 vantaux the montant rows double per unit (`4 × (H−74)` each):
latéraux map to fixed(2) per side placement (one side placement covers
both leaves on that side) and centraux to fixed(4) per intermediate
placement — DERIVED decompositions of the printed totals, same doctrine
as the traverse spanning mappings.

**"3 vantaux (avec fixe)" modeling decision (C6b):** represented as ONE
ouvrant coulissante section with `vantauxCount = 3`. The source does not
state which third of the unit is fixed, its rail arrangement, or the
fixed panel's framing membership — and no encoded cut length depends on
any of that — so the fixed-third position is deliberately NOT
represented (recorded limitation until a verified rule needs it). A
hypothetical plain-3v unit without a fixed panel is not documented by
the table and is likewise indistinguishable in this model; the
manufacturer's own column header defines the 3-vantail configuration as
the avec-fixe one.

Quantity mapping: the table counts pieces per unit; AluVis rules count
per matched `ProfileUsage` placement, so unit totals emerge from
placements (see `CutQuantity`'s doc). Dormant/montant/mullion rules are
duplicated per vantaux column (their formulas coincide at 2 and 3
vantaux; exact-column gating keeps each rule tied to its printed row).
Angles are NOT stated per row on p. 24; the 45° mitre is DERIVED from
the descriptif's assembly statement "Dormants assemblés en coupe d'onglet
avec équerres" (pp. 1–3). That statement names the DORMANTS; applying
the same mitre to sash members is an extension of it — hence every rule
description carries "angles dérivés pp. 1-3" so cut-level provenance
does not overstate p. 24. Every rule carries an exact
`VantauxCountCondition` AND `OpeningTypeCondition(coulissante)` — only
the documented coulissant configurations are covered; any other opening
type or leaf count surfaces as a honest `noRuleMatched` issue — plus
`ProfileReferenceCondition` where the row names exact references.

**Nothing left unencoded:** every cell the p. 24 table documents is now
represented by an exact-column-gated rule; configurations outside the
three documented columns (other vantaux counts, other opening types,
profiles absent from the rows) surface as honest `noRuleMatched`
issues, never wrong cuts.

Earlier decision text (C4b–C4e era, superseded by the C5 partial
encoding above but kept for the record): the table was left entirely
unencoded because the engine selected rules by ProfileType + section
conditions only -- it could not distinguish 14 621 from 14 631 nor gate
on configuration. That blocker was removed by
`ProfileReferenceCondition` (C5a).

Scope note on existing installs (updated when the adoption mechanism
landed): `withBuiltInCatalogSeed` merges by addition only, so an install
seeded before a system's real rules existed would keep
`ruleSetId: 'generic-placeholder'` forever under pure add-only merging.
`adoptBuiltInRuleSets` (called from `CatalogStore.load` on every load)
is the narrow, deliberate exception: for a PRESENT record matching a
shipped built-in by id with `isBuiltIn == true` that still stores the
placeholder id, ONLY `ruleSetId` is refreshed to the shipped value and
the change is persisted; user-created systems, non-placeholder stored
values, and deleted records are untouched. Fresh installs get the real
rule set directly.

## Corrections during transcription

- p. 20 first pass read the traverse formula as "(L−54)/2"; the 150 dpi
  re-render shows **(L−64)/2** (twice, including next to 14 623/14 640).
- p. 24 first pass read "(L−80)/4" and "(L−95)/2"; the 150 dpi re-render
  shows **(L−60)/4** and **(L−85)/2**.
- p. 7's 14 623 "unclear depth" resolved at 150 dpi: depth 56, face not
  labeled (like its companion 14 633).

## Removed seed entries (record for existing installs)

Earlier seed generations shipped name-only placeholder records:
Aluminium du Maroc / Cuzco 713 OM (`builtin-aluminium-du-maroc`,
`builtin-cuzco-713-om`), Sepalumic Maroc / Coulissant 8800, 6700 (TB),
6900 (TB) (`builtin-sepalumic*`), Menara Profil / Targa Plus
(`builtin-menara-*`) and Maghreb Extrusion / DOMAL (`builtin-me-domal`).
None had verified numeric data. They are no longer seeded now that the
Maghreb Extrusion document provides a fully verified catalog. The merge
is add-only and never deletes, so installs that already persisted those
records keep them until the user removes them through the catalog UI;
their ids remain reserved in the sense that the seed will never re-add
them.

---

## M-2: SEPALUMIC — Série 4200 (verification gate OPENED)

| | |
|---|---|
| **File** | `~/Downloads/CAT4200_ED05.pdf` (199 pages; Sepalumic "Catalogue Technique" Série 4200, **Édition 05 — Septembre 2019**; AutoCAD-plotted sheets with text layer; visual hi-dpi verification of every encoded table) |
| **Identity** | Sepalumic (groupe Sepalumic, France/Maroc). Série **4200** = gamme traditionnelle à frappe : fixes, ouvrants à la française 1–2 vantaux, oscillo-battants, soufflets, vasistas, projetés, portes, châssis composés (sheet A030). Dormant tubulaire **aluminium 6060, base 40 mm**, assemblé en coupe d'onglet par équerre à pion ; ouvrant à feuillure portefeuille ; **vitrage 6 à 24 mm** ; joint EPDM battue/vitrage ; NF EN 14351-1 (A030/A040). |
| **Structure** | A Généralités (A010–A060) · B Profilés (B010–B080) · C Accessoires · D Informations · **E Débits & Nomenclatures** (drawing sheet + table sheet per configuration) · F Feuillures · G Usinages · H Éclatés · I Assemblages. Pictogramme legend (A020) defines the table symbols (Débit, Longueur, Coupe 45°, Ix/Iy cm⁴, Section…). |
| **Source grade** | Tier 1 (manufacturer technical documentation — fabricator catalogue). |
| **Seeded as** | manufacturer `builtin-sepalumic` "Sepalumic", system `builtin-sepalumic-4200` "Série 4200". |

### B-section profile transcription (sheets B020–B080; width = face, depth = wall-plane; `0` = not labeled)

| Réf | Type (sheet heading) | width | depth | Sheet | Notes |
|---|---|---|---|---|---|
| 4220 | Dormants | 40 | 49 | B020 | sans couvre-joint; sub-dim 22 |
| 4221 | Dormants | 40 | 49 | B020 | avec couvre-joint; +25 clip sub-dim |
| 4211 | Ouvrants | 50 | 37.5 | B030 | étroit; subs 26/18 |
| 4219 | Ouvrants | 50 | 49 | B030 | subs 26/18 |
| 4244 | Ouvrants | 49.5 | 67.5 | B030 | subs 26/18 |
| 4254 | Ouvrants | 50 | 76 | B030 | subs 36/72/22/18 |
| 4206 | Ouvrants | 52 | 40 | B040 | battue centrale; subs 8.9/17.7/35.5 |
| 4413 | Traverses intermédiaires | 40 | 44 | B050 | subs 35/22/22 |
| 4405 | Traverses intermédiaires | 40 | 26 | B050 | subs 35/22/22 |
| 2656 | Traverses intermédiaires | 26 | 62 (derived 19+24+19) | B050 | sub 29.5 |
| 4243 | Traverses renforcées | 40 | 44 | B060 | reinforcement tube drawn at 122; subs 35/22/22 |
| 4233 | Traverses intermédiaires | 26 | 26 | B050 | reinforcement tube 84×70 |
| 4253 | Traverses intermédiaires | 26 | 26 | B050 | reinforcement tube 95×70 |
| 4464 | Parcloses | 5.4 | 22 | B070 | |
| 4418 | Parcloses | 9.4 | 22 | B070 | |
| 5026 | Parcloses | 14.3 | 22 | B070 | |
| 5120 | Parcloses | 18.2 | 22 | B070 | |
| 5016 | Parcloses | 22 | 22 | B070 | |
| 4250 | Parcloses | 7.9 | 22 | B070 | |
| 4252 | Parcloses | 12.1 | 26.7 | B070 | |
| 4251 | Parcloses | 15.8 | 26.7 | B070 | |
| 3380M | Complémentaires | 0 (unlabeled) | 30 | B080 | |
| 4080 | Complémentaires | 0 (unlabeled) | 30 | B080 | |
| 4081 | Complémentaires | 0 (unlabeled) | 45 | B080 | |
| 4082 | Complémentaires | 0 (unlabeled) | 60 | B080 | |
| 2648 | Complémentaires | 30 | 0 (28/42 chain, no total) | B080 | |
| 463 | Complémentaires | 45 | 7 | B080 | |
| 4582 | Complémentaires | 52 | 20 | B080 | |
| 5067 | Complémentaires | 35 | 15 | B080 | |
| 4568 | Complémentaires | 20 | 12 | B080 | |
| 412 | Complémentaires | 19.6 | 4.5 | B080 | |

### E-section débitage — encoded families (drawing + table sheet pairs)

Variables **L** = whole dormant-frame width, **H** = whole dormant-frame height (each drawing sheet's elevation). Dormant/ouvrant cuts 45°/45°; traverse/battue cuts 90°/90°. Every table carries "Ce tableau est donné à titre indicatif…" — recorded, treated as the table's own scope caveat.

**Châssis fixe** (E030/E050 — pdf pp. 39–42): dormant **4220** `2×L + 2×H` (45°/45°) OU **4221** `2×(L+50) + 2×(H+50)`; option traverse intermédiaire `1×(L−54.5)` 90°/90° in **4405 ou 4413**.

**OF 1 vantail** (tables E070=4211 pdf p.44, E090=4219 p.46, E110=4244 p.48, E130=4254 p.50; each configuration spans a drawing sheet + table sheet pair whose sheet ids differ — e.g. the 4219 1v drawing is E080 p.45, its table E090 p.46): dormant 4220/4221 exactly as fixe; ouvrant `2×(L−43.5) + 2×(H−43.5)` 45°/45° — **same deductions for all four ouvrant refs**; option traverse `1×(L−deduction)` 90°/90° with deduction **per sibling ouvrant ref**: 4211→**117** (2656), 4219→**141** (2656), 4244→**177** (2656), 4254→**187** (4405 ou 4413). Each sheet offers exactly ONE traverse-ref family; the dormant "OU" branch never changes the traverse deduction (E030 vs E050 both print L−54.5 for the fixe).

**OF 2 vantaux** (tables E150=4211 p.52, E170=4219 p.54, E190=4244 p.56, E210=4254 p.58): dormant as above; ouvrant `4×(L/2−24) + 4×(H−43.5)` 45°/45° (same deductions all refs); **battue centrale 4206** `1×(H−102)` 90°/90°; option traverse `2×(L/2−deduction)` 90°/90°: 4211→**98**, 4219→**122**, 4244→**158** (all 2656), 4254→**168** (4405 ou 4413). Parclose rows (per-ref `4×(L/2−168)` traverse + `4×(H−231)` montant etc.) are glass-configuration-dependent — NOT encoded (blocker 3 below).

The eight (traverse ref × sibling ouvrant ref) cells above are ENCODED as of the paired-profile milestone (see blocker 2): the deduction is a pure lookup on the châssis's ouvrant reference — no arithmetic relation links the deductions to any traverse dimension (verified against every sheet).

### Vocabulary / routing identifications

- **OF = Ouvrant à la Française** → routed to `OpeningType.francaise`. Evidence: descriptif A030 pairs "Kit crémone fermeture haute et basse pour **OF** 1 ou 2 vantaux" with the "ouvrants à la française" range; accessories list "Paumelles réversible pour OF" (paumelles = inward side-hinges); the abbreviation itself.
- **O.B. identification UNRESOLVED — do not route on either reading.** The catalogue never expands "O.B.". Two candidate readings exist and the evidence does not settle between them: (a) *à la belge* (outward side-hung) — O.B. kits use "compas" friction stays; (b) *oscillo-battant* — compas are also characteristic of O.B.-style hardware, and the A030 range explicitly includes oscillo-battants. Against (b): the accessories list a "kit verrouillage intégré **ouvrant à l'anglaise**" separately from "Point de fermeture réglable pour O.F. et O.B.", and A030 says "Fermeture multi-points pour les oscillo-battants" while the O.B. kit is "sans crémone". Both readings are recorded; neither is adopted; no rule routes on O.B. Resolving this requires an external source (Sepalumic confirmation or the E-sheet typology drawings at higher resolution).

### Deliberately NOT encoded (blockers on record)

0. **Single-châssis-per-construction scope limit**: every encoded L/H refers to the WHOLE dormant-frame elevation of ONE châssis (each E drawing sheet's L/H). A construction mixing a fixe section and an OF section (or any multi-châssis composition) is NOT covered by these tables — the tables' arithmetic has one L/H pair per unit. Users must model one châssis per AluVis construction until a multi-frame scope condition exists; assigning 4200 profiles across sibling sections would apply the whole-unit L/H to each section's cuts (a confident wrong number, not a noRuleMatched).
1. **OB (à la belge OU oscillo-battant — identification unresolved, see above), Soufflet, Projeté, Porte large, Châssis composé families** — E-sheets exist and tables are present, but no honest `OpeningType` exists for any candidate reading of O.B., soufflet, or projeté, and portes/châssis composés need door & multi-panel modeling decisions. Smallest future extension: new enum values + picker support, one milestone each.
2. **~~Traverse intermédiaire options for OF 1v/2v~~ — RESOLVED (paired-profile milestone, C8)**: the deduction depends on the SIBLING ouvrant reference (117/141/177/187 at 1v; 98/122/158/168 at 2v) — a cross-usage dependency the rule engine could not evaluate (conditions saw one usage's context). Now encoded as 8 companion-gated rules via `CompanionProfileReferenceCondition`: a rule matches only when the evaluated traverse usage's SECTION SIBLINGS establish the sash identity — universal quantifier over "sash carriers" (resolved `ProfileType.ouvrant` usages at non-intermediate roles; the intermediate slot is excluded by placement doctrine because battue 4206 is ouvrant-typed per its own B040 heading yet coexists with traverses), exact `Profile.reference` equality, fail-closed on every missing/ambiguous input (no carrier, mixed sash, wrong ref, carrier in another section, unresolvable carrier). Siblings are DERIVED per calculation from existing usages + catalog resolution — nothing persisted. A mixed-sash section matches no rule (plain `noRuleMatched` skip) instead of tying two rules into `AmbiguousRuleMatchException`. Correction of an earlier wording on this page: the Série 14600 traverse/montant pairing note is COMPATIBILITY documentation, not a cut dependency — every p. 24 débitage row there is keyed by the member's OWN reference, which is why that table never needed this mechanism. The genuinely same-shape case is ME 14800 frappe (see S-2 preliminary note below).
3. **Parclose cut rows**: selection among 8 refs depends on glass configuration ("ou") — no glass domain exists. Parclose PROFILES are seeded; their cuts are not.
4. Hardware, joints, glass-dimension and usinage tables: component/machining domains, out of scope.

### Examined earlier (insufficient; superseded as working source by this catalogue)

Official Coulissant 8800 brochure (marketing descriptif only) and the GUIDE PROGES index (trade-hosted copy) — recorded during the C7 planning pass; the 4200 ED05 catalogue is the first Sepalumic source carrying fabrication data.

---

## S-2 (PRELIMINARY EVIDENCE NOTE — not a seeded system): ME Catalogue Général, Série 14800 frappe parclose rows

| | |
|---|---|
| **File** | `~/Downloads/855704418-Catalogue-General-Series-Maghreb-Extrusion-compressed-3.pdf` (146 pp, client-supplied; text layer present) |
| **Identity** | "FORMULES DE COUPES — DÉBITAGE FENÊTRE À FRAPPE SÉRIE 14.800 (1 VANTAIL)", pdf p. 65 |
| **Extraction** | `pdftotext -layout` full-document dump + `pdftoppm` 110 dpi visual render of p. 65 to confirm the row structure (the text layer scrambles the merged cells) |
| **Source grade** | Tier 1 (manufacturer technical documentation) |
| **Status** | NOT seeded, NO values adopted into code — recorded as the second-manufacturer evidence that motivated the paired-profile engine capability (M-2 blocker 2 resolution). Full 14800 transcription + seeding remains the C9 candidate. |

What p. 65 shows, verbatim in structure: two "Pareclose à coupe droite" rows (90°, Quantité 2+2) whose **Ref column carries the SIBLING OUVRANT reference**, not the parclose's own — row "14.802" (Ouvrant fenêtre context): parcloses 14.809 (Simple vitrage) / 14.810 (Double vitrage), Débitage `L − 117,6` / `H − 157,6`; row "14.805" (Ouvrant porte et fenêtre extérieur context): same parclose refs, Débitage `L − 217,4` / `H − 257,4`. The glazing choice is expressed through the parclose reference (14.809 vs 14.810), so these specific cuts are determined by (own parclose ref, sibling ouvrant ref) alone — no glass-thickness model needed for THIS table, unlike Sepalumic 4200's parclose "ou"-lists (M-2 blocker 3). The same sheet's VITRAGE block ("Débitage pour ouvrant 14.802 → L−132/H−132; pour ouvrant 14.805 → L−185/H−185") is glass sizing — a separate, still-out-of-scope domain. The main 14.800/14.801/14.802/14.805 profile rows on p. 65 are keyed by each member's OWN reference (no companion dependency).
