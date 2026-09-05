# Fliptide visual card polish

One focused PR stacked on the course-code pause fix. Preserve the neon
geometry/palette, bottom-fifth buttons, corridor retry passthrough, death guard,
percentage agreement and delayed CLEARED fade.

Plan: make the central title/result treatment fit narrow phones without
wrapping the wordmark, give it a small geometric gravity motif and a restrained
dark backing so instructional text remains legible over the corridor. No new
asset download, shader, dependency, tracking or gameplay rule.

Verification: existing full public suite untouched; add real-Inter before/after
title/death plates and a one-line wordmark check at 300/360px. Keep explicit
Android timing/human play/release gates open.

## Baseline evidence

VERIFIED: public run 33950195263 at 8eec9f9, analyzer clean; 105 passed / 3 failed.
New checks exposed:
`Expected: <1>` / `Actual: <null>` for the unbounded title at both widths; and
`A RenderFlex overflowed by 9.7 pixels on the right.` at 300px with real Inter.
The source proposal sets single-line title behavior and reduces only the narrow
button horizontal padding (22 to 16), without shrinking text or vertical targets.
Before plates are genuine widget renders, not generated UI mockups.
