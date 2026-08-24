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
Inertias are in cm⁴ as printed ("Inertie en cm4") — recorded here
because the `Profile` model has no field for them; they are NOT seeded.

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

## Débitage (cut-length) table — p. 24, transcribed but NOT seeded into rules

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

**Encoding status** (updated when the first rows were encoded as C5):
the "2 vantaux" column of this table is now a real `SystemRuleSet`
(`meSerie14600RuleSet`, `lib/core/data/me_14600_rule_set.dart`):

- Dormant 14 617 / 14 627: `2+2 × (L ; H)` — four role-scoped rules
  (top/bottom → L, left/right → H), one piece per placement.
- Montant latéral 14 622/623/632/633: `2 × (H−74)` — two role-scoped
  rules (left/right), one piece per placement.
- Traverse 14 621: `4 × (L−64)/2` — top/bottom rules, TWO pieces per
  placement (one placement spans both leaves' track halves).

Quantity mapping: the table counts pieces per unit; AluVis rules count
per matched `ProfileUsage` placement, so unit totals emerge from
placements (see `CutQuantity`'s doc). Angles are NOT stated per row on
p. 24; the 45° mitre is DERIVED from the descriptif's assembly statement
"Dormants assemblés en coupe d'onglet avec équerres" (pp. 1–3) applied to
frame and sash alike. Every rule carries `VantauxCountCondition(2)` — only
the 2-vantaux column is documented for these formulas — plus
`ProfileReferenceCondition` where the row names exact references.

**Still deliberately unencoded** (usages surface as honest
`noRuleMatched` issues, never wrong cuts): dormant +46 variants
(14 618 / 14 628 / 14 626), traverse 14 631 (`(L−85)/2`, `(L−47)/3`,
`(L−106)/4`), traverse 14 621 at 3/4 vantaux (`(L−25)/3`, `(L−60)/4`),
montants centraux 14 619/620/630 (`ProfileType.mullion` row), chicane
14 624 (`H−92`). The formulas themselves are verified above; encoding
awaits its own milestone so each configuration column lands with its own
quantity-semantics analysis.

Earlier decision text (C4b–C4e era, superseded by the C5 partial
encoding above but kept for the record): the table was left entirely
unencoded because the engine selected rules by ProfileType + section
conditions only -- it could not distinguish 14 621 from 14 631 nor gate
on configuration. That blocker was removed by
`ProfileReferenceCondition` (C5a).

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
