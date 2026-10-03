# Fliptide — Google Play listing draft (owner's voice; edit freely)

Status: READY TO PASTE (files only, no Console work done). Package `com.tsorostudios.fliptide`. Owner registers the app +
upload key in Play Console (DEMAND 02e-6, by 30 Sep 2026). Nothing here is submitted.

## App name (≤ 30 chars)
Fliptide: One-Tap Gravity Run

## Short description (≤ 80 chars)
One tap flips gravity. Same course for everyone today. How far can you get?

## Full description (≤ 4000 chars)
Fliptide is a one-tap gravity runner. Tap to fall to the ceiling, tap to drop back to the
floor, and thread a corridor of spikes, blocks and pits that is the same for every player in
the world that day.

DAILY COURSE
Every day there's one course and everyone plays the same one. Clear it, or see exactly how far
you got as a percentage — then compare with friends.

DIE, RESTART, GO
Restart takes well under a second. A ghost of your best run plays beside you and an X marks
where you last died, so every attempt teaches you something.

SHARE YOUR RUN
When you're done, share a small text card with your result and the course code. A friend can
enter the code and play the exact course you died on.

COURSE CODES
Every course has a six-character code. Type one in on the title screen to play any course,
today's or any other.

NO ACCOUNT. NO TIMERS. NO ENERGY.
Fliptide is free to play in full. If you enjoy it, an optional one-time Supporter purchase
unlocks a set of skins and helps us make more.

Made by Tsoro Studios, the team behind Emberdelve.

## Category / tags
Category: Games → Arcade. Tags: one-tap, runner, gravity, daily challenge, casual.

## Content rating
Questionnaire answers drafted in docs/play-store/content-rating.md. Expected: Everyone / PEGI 3.
Target audience: 13+ (declare in "Target audience and content"; do NOT tick under-13 — that
would pull the app into Families policy).

## Data safety (expected)
Phase 1 build: no analytics SDK, no account, no network calls other than fetching the app's
own assets. Save data is on-device only. Once Play Billing lands: purchase history is handled
by Google Play, not by us. Once AdMob lands: declare Advertising ID + AdMob's data collection
per Google's published data-safety mapping for AdMob.

## Graphics assets (all present, sizes checked)
- App icon 512×512 PNG: docs/crazygames/icon-512.png (reuse)
- Feature graphic 1024×500 PNG: docs/play-store/feature-graphic-1024x500.png (tool/art/feature_graphic.py)
- Phone screenshots 1080×1920 ×8: docs/play-store/screens/1-title … 8-cleared.png — real frames from the
  live Pages build (ababe10) via tool/webtest/play_shots.py, HUD visible, no mock-ups. Order for the
  listing: 1 title · 3 first run · 4 on the ceiling · 5 mid-course · 6 death overlay · 7 attempt 2 · 8 cleared · 2 code entry.
  Recapture after any visual change.
- 7-inch / 10-inch tablet screenshots: optional, not made

## Store listing contact
Email: tapiwamakandigoner@gmail.com (as given in DEMAND 02i; same as the privacy page).
Privacy policy URL (live): https://tapiwamakandigona.github.io/fliptide-ci/privacy/
Developer name: Tsoro Studios. Address on file: Tapiwa Makandigona, Kwekwe, Zimbabwe.
Developer website: https://tapiwa.me (directive 02k-8). AdMob requires `app-ads.txt` at the root
of that domain — https://tapiwa.me/app-ads.txt — with exactly this line:

    google.com, pub-5182383335652302, DIRECT, f08c47fec0942fa0

The website field in the Console must be this domain (AdMob crawls the developer website
from the store listing); publish the file before the listing goes live, then verify in AdMob
→ Apps → Fliptide → app-ads.txt (crawl can take up to 24 h).

## Release notes (first production release)
First release. One-tap gravity runner with a daily course, ghost runs, instant restart and
shareable course codes.
