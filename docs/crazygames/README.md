# CrazyGames submission package — Fliptide

Everything the owner needs for a CrazyGames **Basic Launch** (free, non-exclusive, no SDK).
Submission is the owner's action at https://developer.crazygames.com.

| File | What |
|---|---|
| `fliptide-web.zip` | HTML5 build. Relative base href (runs from any folder), renderer self-hosted (no gstatic), no service worker. 44 files, 35.8 MB unzipped / 14.1 MB zip (built from commit 198a1d6; sha256 `a0b99dd254ba24f8a284d497e928f5a3ded5502e37f18b0eb77f9962a49fe8e7`). Rebuild: `scripts/build_crazygames.sh`. |
| `cover-1920x1080.png`, `cover-1280x720.png` | 16:9 cover (original art, code-drawn). |
| `icon-512.png` | 512×512 icon (original art). |
| `description.md` | Listing text in the owner's voice — edit freely. |

Checks done on this build (2026-09-02, commit 198a1d6): unzipped under a nested path
(`/cdn/games/abc123/v7/`) and served with every non-first-party host blocked — the only host
requested is the serving host itself (no `fonts.gstatic.com`, no CDN, no analytics). 0 page errors;
title, run and death screens render with the bundled Inter font; solver autoplay clears the Daily.
Single page, no external calls at all. Controls: tap / click / Space / ↑ / W. Landscape and
portrait both work; death-screen buttons sit in the bottom fifth, any other tap retries.

Known cosmetic in this package: on the CLEARED screen the HUD percent shows "100 %" on two
lines (KP-5, fixed in source at ababe10). Not rebuilt on purpose — owner said don't rebuild
twice; if the package is rebuilt before submission, the fix comes along automatically.

Suggested CrazyGames form values: Category *Casual* (or *Skill*), tags: one-button, gravity,
runner, daily challenge, hard. Orientation: both. Mobile-friendly: yes. Multiplayer: no.
