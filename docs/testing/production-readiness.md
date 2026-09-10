# Closed-test recruitment and production readiness

## Goal and evidence rules

Recruit **20 willing players** as a planning target, giving room above Google's
minimum. This target is not an observed tester count.

Keep these stages separate:

1. Invitation published/sent.
2. Person voluntarily joins the Google Group.
3. Person explicitly opts in to the game's **closed** test.
4. Person plays, returns and supplies feedback.
5. Play Console confirms the continuous testing requirement is met.
6. Production access is applied for and approved.
7. A verified production release is submitted and becomes available.

Never convert impressions, group members, email deliveries, self-reported
installs or internal testers into verified closed-test eligibility.

## Verified checkpoint

- **Release blocker:** owner reports Google Play **0.3.0** and its predecessor
  crash before the first screen on an itel S26 Ultra. Root cause and device
  Android version are not verified. Pause new Fliptide recruitment pushes and
  all production promotion while investigating; preserve saves. Play vitals
  currently has no matching issue rows, and pre-launch reports are unavailable;
  neither absence disproves this report. [owner report and Play vitals/pre-launch DOM, 2026-09-09]
- **Fliptide closed Alpha:** exactly release **0.3.0 (4)** and the tester-group
  setting `emberdelve@googlegroups.com, testers-community@googlegroups.com`
  were submitted; **submission 4 is now Published** and **0.3.0 is available
  to selected testers**. This supersedes the in-review checkpoint, not the
  unverified device-compatibility gate. No production action was taken. [Play submission activity and Alpha track, 2026-09-09 04:39 UTC]
- **Existing community:** Emberdelve Testing has **38 members**; membership
  is public/self-service, conversation posting is owner-only. No member
  roster was exported or bulk-added. [Google Groups conversation and About pages, 2026-09-09]
- **Eligibility baseline:** Fliptide and Pyregrove each showed **1 opted-in
  tester** with production application disabled. Refresh the dashboard
  before reporting current counts. [Play Console app dashboards, 2026-09-08]
- **Automation gates:** Existing F3 Android restart measurement and F7 human
  playthrough remain false. CI is not a real-device or human-play result.
  A field report can inform work but does not silently pass these gates. [features.json at 85056cc, 2026-09-09]

## Recruitment started

- [Pinned invitation in the existing tester group](https://groups.google.com/g/emberdelve/c/mkqB5nGpJYY).
  Verified published text, exact test links and Unpin control. This is one
  announcement to a group, not evidence that every member read it. [Google Groups published-conversation readback, 2026-09-09]
- [Public LinkedIn invitation](https://www.linkedin.com/feed/update/urn:li:activity:7503305527771320320/).
  Verified successful post and own-activity article. Uses the owner's voice;
  invitations are voluntary and version status is explicit. [LinkedIn post-success and published article, 2026-09-09]
- Permission-first outreach to GameOn/TechVillage's public community contact
  asks to share the invitation with interested players, not provide personal
  contact lists. Gmail confirmed one matching sent message. A sent message is
  not a partnership or recruitment result. [Gmail send confirmation and exact Sent search, 2026-09-09]
- Reddit: inspect community rules and account access before posting. Initial
  access and one cooldown retry were rate-limited; no Reddit post was made. Do not evade limits
  or promise reciprocal phone testing that has not been performed.

## Returning-player loop

Store identifiable contact details and consent records privately, **not in
this repository**. Use an anonymous tester reference in issue summaries.

- On a voluntary reply, clarify chosen game/device and help with opt-in errors.
- Ask permission for short private check-ins. Do not automatically enroll
  group members in a separate mailing list.
- Around days 3 and 7, ask one concrete question about controls, difficulty or
  a defect the person reported; explain any fix with an actual commit/build.
- Around day 14, ask about overall experience and continued interest. Do not
  pressure a person to stay, buy, click ads or leave a positive review.
- Maintain aggregate counters for volunteered / self-reported opt-in /
  Console-observed eligibility / feedback received. Do not invent per-user
  Play telemetry that the product does not collect.
- Acknowledge useful feedback and report which changes it produced.
  Never promise a fixed response time, reward or new feature without capacity
  and approval to deliver it.

## Production application

Google requires at least **12 testers continuously opted in for the preceding
14 days** for the applicable app. It also asks about recruitment, actual
engagement, feedback, fixes and production readiness. Meeting a counter alone
does not guarantee approval. [Google Play Help 14151465, read directly 2026-09-09]

Before applying:

- Refresh Play Console eligibility and confirm the test is still active.
- Summarize real feedback and the fixes it prompted, with honest limits.
- Verify device behavior, accessibility, signing, store-policy declarations,
  and purchase/restore checks where applicable.
- Preserve existing feature criteria; do not mark human/device tests passing
  on the basis of CI or a production eligibility badge.
- Submit only an authorized production scope. Closed-Alpha approval does not
  authorize production or unrelated account changes.

References:
[Google production-access requirements](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en) ·
[Test track and opt-in rules](https://support.google.com/googleplay/android-developer/answer/9845334?hl=en) ·
[Player onboarding guide](closed-test-guide.md).
