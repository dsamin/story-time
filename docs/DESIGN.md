# Visual Design Spec — Story Time, Your Turn

Agreed direction: **"Lamplit Storybook."** Reviewed against the non-negotiable
bar (calm / audio-first / errorless / age-4) and accepted — it uses a muted,
lamp-warmed palette, expresses a wrong tap as a soft-blue "let me show you again"
re-model (never red/buzzer/X/shake), has no scores/stars/timers/confetti/nags, and
sizes every target for an imprecise 4-year-old. Two alternatives (bright-primary
"Sesame" palette; high-contrast dark mode) were rejected as too stimulating/stark.

The implementation's `Palette`, `Motion`, and per-screen views follow this spec.

## 1. Color palette (exact hex)

| Role | Hex |
|---|---|
| App background (warm paper) | `#EDE7DC` |
| Surface / card base | `#F4F0E8` |
| Surface alt (banner, drop wells) | `#E2DACB` |
| Deep ink (parent-gate text only) | `#4A4A4A` |
| Active spoken-word highlight (gold) | `#E6C36A` |
| Active glow halo | `#F2E0AE` |
| Correct-confirmation tint (sage) | `#8FB9A8` |
| Re-model / try-again tint (soft blue, **never red**) | `#A9C8E0` |
| Secondary accent (1·2·3 dots, quiet UI) | `#C9A8D8` |
| Already-spoken (settled word) | `#9A9183` |
| Unspoken word / caption ink | `#6A6258` |

Re-model uses soft blue, not amber/red: "let me show you again," not "wrong."

## 2. Typography

System font, rounded design (`.rounded`) for warmth.
- Parent gate / Settings (adult, readable): `.title2`/`.semibold`, rows `.body`, helper `.footnote`, ink `#4A4A4A`.
- Optional decorative story caption: `size 22, .medium, .rounded`, `#6A6258` — always also spoken, never required.
- Word chips: `size 34, .semibold, .rounded`.
- No body paragraphs in the child flow. Dynamic Type only in Settings.

## 3. Per-screen layout (landscape, safe-area aware)

- **Story Shelf** — `ScrollView` → `LazyVGrid` (2×3–4) of large square wordless `StoryTile`s (~280–320pt, 28pt spacing), each a `ZStack` of cast art on `#F4F0E8` with soft shadow. No titles. A small lavender gear in the bottom-trailing safe-area opens the parent gate.
- **Story Player** — `VStack`: top ~62% illustration; middle ~22% word-chip line (centered, wrapping); bottom ~16% a large circular **Replay** control (88×88, gold ring). Tap-a-word lives in the chip row.
- **Question Card** — story art animates to a slim top banner (~18%, `#E2DACB`); centered pulsing gold **sound-wave orb** = "listen"; bottom ~60% a `Grid` of 2–4 picture-answer cards (~300pt, 24pt gaps).
- **Sequencing Board** — top `HStack` of 2–3 shuffled draggable beat-cards (~240pt); below, oversized drop wells (`#E2DACB`, soft dashed) each tagged by a `1·2·3` lavender dot. A quiet replay orb trailing.
- **End Card** — quiet `ZStack`: final illustration washed under `#EDE7DC` ~50%, one soft sage "home" glyph, single tap anywhere → Shelf. No score/stars/nag/text.
- **Parent Settings** — adult `NavigationStack`/`Form` after the gate (voice volume, story management, reset). The **gate**: press-and-hold (0.6s) **then** horizontal drag to reveal.

## 4. Motion (all `easeInOut`, no spring/bounce)

- Word-highlight advance: crossfade + scale `1.0→1.06`, gold glow `0→0.4`, `0.45s`; previous chip eases to settled gray over `0.4s`.
- Correct confirmation: chosen card border → sage, one slow breath `1.0→1.04→1.0` over `0.7s`, soft sage wash. No pop/particles.
- Re-model (wrong tap): wrong card eases back to rest over `0.5s` (no shake); correct card slow soft-blue pulse (`opacity 0.7→1.0`, scale `1.03`) over `0.8s`, synced to the voice.
- Card drag/drop: finger-tracked; drop glides `easeInOut(0.5)`; invalid drop eases home `0.5s`.
- Sequencing replay: beats fade/scale in 1→2→3, ~0.6s each w/ ~0.2s overlap, voice narrating. Calm montage.
- Global transition: `.opacity.combined(with: .scale(0.98))` at `0.5s`.

## 5. Word-highlight treatment

- Unspoken: `#6A6258`, no fill, `.semibold`.
- Currently spoken: `#4A4A4A` text on a filled gold `#E6C36A` 16pt capsule + `#F2E0AE` glow, scale `1.06`. Exactly one gold at a time.
- Already spoken: dims to `#9A9183`, no fill.
- Tap-a-word: tapping a chip eases it to gold, re-speaks just that word, settles back `0.4s`; a `1.03` lift on touch-down signals tappable.

## 6. Errorless, expressed visually

Wrong tap: card depresses slightly (`0.98`), then eases calmly back to rest over
`0.5s` — no color change, no red, no X, no shake, no sound sting. Simultaneously
the **correct** choice does a slow soft-blue (`#A9C8E0`) re-model pulse while the
one warm voice re-speaks the answer. Retries are unlimited and unremarked; nothing
ever says "you failed," only "here, let's look together."
