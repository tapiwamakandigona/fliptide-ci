# Fliptide — Play Console content-rating questionnaire (IARC), drafted answers

Files only; nothing entered in the Console. Answer from the build as it is when you submit —
the two "update when" lines below flip once ads / IAP code lands (phase 2).

## Category
Game.

## Violence
| Question | Answer | Why |
|---|---|---|
| Does the game contain violence? | **No** | The avatar is an abstract rounded block. Hazards are abstract spikes, blocks and pits. On contact the block bursts into a few coloured squares and the run ends. No blood, no gore, no characters that could be read as people or animals being hurt. |
| Realistic-looking violence / weapons | No | — |
| Violence towards fantasy/realistic characters | No | — |

## Sexuality, nudity, language, controlled substances, gambling
All **No**. No text beyond fixed UI strings, no dialogue, no simulated gambling, no loot boxes,
no chance-based rewards.

## Fear / horror
No.

## User interaction
| Question | Answer | Why |
|---|---|---|
| Can users interact or exchange content with other users? | **No** | No chat, no accounts, no leaderboards, no multiplayer. |
| Does the app share user-generated content? | **No** | The Share button hands a text/image of the player's own run to the OS share sheet; nothing is published inside the app. Course codes are six alphanumeric characters derived from a number — they carry no user text. |
| Does the app share the user's location? | No | — |
| Can users purchase digital goods? | **Yes** | One optional one-time Supporter unlock via Google Play Billing (no ads + skins). **Update when:** answer "Yes" only once the IAP code ships; the v0.x build has no purchase. |

## Advertising
| Question | Answer | Why |
|---|---|---|
| Does the app display ads? | **v0.x: No. Android with AdMob: Yes** | The web build has no ads at all. The Android build gets AdMob interstitials/rewarded ads in phase 2 (between attempts only, never inside a run, none in the first minutes after install, ≤ 1 interstitial per 90 s). **Update when:** flip to "Yes" in the same release that ships the AdMob SDK. |
| Ads are age-appropriate / from an ad network that supports content filtering | Yes (AdMob) | — |

## Miscellaneous
| Question | Answer |
|---|---|
| Contains user-generated content | No |
| Can share personal information | No |
| Uses location | No |
| Web browsing / links to external sites | Only the share text carries a link to the game's own site; no in-app browser |
| Digital purchases | See above |

## Expected outcome
ESRB Everyone · PEGI 3 · USK 0 · IARC generic 3+. Target audience declaration: **13 and over**
(do not select any under-13 group — that pulls the app into the Families policy, which
changes the ad and privacy requirements).

## Data-safety form pointers (separate section, but asked together)
- App itself collects nothing; save data on-device only.
- Once AdMob ships: declare Device or other IDs (advertising ID), Approximate location (IP-derived), App interactions / ad-performance data — "collected", "shared with Google for advertising", "not optional" except via the Supporter unlock. Follow Google's published AdMob data-safety mapping at submission time; do not guess it from memory.
- Once Play Billing ships: purchase history is handled by Google Play; declare "Purchase history — collected by Google Play, not by the developer" per Google's Play Billing guidance.
- Privacy policy URL: https://tapiwamakandigona.github.io/fliptide-ci/privacy/
