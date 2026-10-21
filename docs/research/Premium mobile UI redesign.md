# Strip the defaults, then engineer the feel

In 2025–2026 a mobile app reads as premium when every visible choice looks deliberate and the app responds instantly. Decoration matters much less. The sources agree on a short list. Use layered, tinted neutrals with a single accent ramp. Keep to few type sizes and two weights, pairing a display face with a text face. Build depth from small steps in surface lightness and barely visible shadows. Hold strict shared edges on a 4-pt grid and use one icon family. Engineer the "feel" through springs, graded haptics, skeleton loaders, optimistic updates, and designed empty and error states. The YouTube design educators (chiefly Kole Jain and Chris Raroque), 2026 trend writing and the reference apps (Linear, Things 3, Revolut, Monzo, Copilot Money, Notion, Superhuman, Attio, Airbnb, Flighty, Cash App, Wise) now define "premium" *against* AI-generated and template output. Apple and Google say the same thing in different words: expressive motion, colour and glass belong at the edges (navigation, hero moments, primary actions), and content and repeated flows stay calm and legible. **Reddit was inaccessible to the researchers.** It was blocked at the network level, so community sentiment here comes from practitioner blogs, GitHub tooling, Nielsen Norman Group (NN/g), the design press and app reviews, and the report contains no Reddit quotes. For SmartBroker, this points to a thin custom token layer on Material 3 in Flutter, not stock Material and not a Liquid Glass clone. That layer has five parts:

- tinted teal-grey neutrals with one deep-teal accent;
- Menbere display type over Inter and Noto Sans Ethiopic text, with tabular figures;
- a six-size type scale, squircle radii and tonal elevation;
- two motion tiers, plus haptics with fallbacks for older Android;
- a labelled floating pill navigation with a separate capture button for dictation.

Business-app users judge speed, offline reliability, search and forgiving forms before visuals, so those belong in the premium spec too. The brand colour, every hex value and most Ethiopia-specific choices are inferred rather than sourced, and they are flagged below. No research covers how Ethiopian brokers perceive "premium" or which Android devices they use, so both need local testing.

## Premium in 2026 is defined against defaults and AI output

The evidence base is uneven, and that shapes how much weight each claim can bear. YouTube watch pages returned bot-protection pages, so creators' spoken advice was recovered from third-party transcript and summary sites. Kole Jain is well covered with concrete numbers. Chris Raroque, Tim Gabe and Michal Malewicz are partly covered. Learn UI Design (Erik Kennedy) is covered by chapter titles only. No usable transcripts were found for Flux Academy, DesignCourse, Mizko, Sajid, Rick Mulder, Jesse Showalter or Design with Arash, and Juxtopposed is represented only by video titles. **Reddit could not be reached at all**: page fetches were blocked, Reddit-restricted search was rejected, and the proxy refused direct and mirror requests. Any "Reddit consensus" about which apps designers admire therefore remains unverified. Several other sources carry caveats. Many 2026 "trend" articles are agency marketing content. Google's Material 3 Expressive research is vendor-run. John Gruber's praise of Copilot Money ran in a week Copilot sponsored his site ([Daring Fireball](https://daringfireball.net/linked/2025/12/28/)).

With those caveats, the sources agree to a striking degree that "premium" now means **the visible absence of defaults**. Kole Jain lists the giveaways of a "vibe-coded" app: emojis used as icons, clashing AI-chosen colours, gradient avatar circles with initials, and busy cards. His advice is blunt: "Get rid of the emojis" and "never let an AI choose your layout either" ([Kole Jain](https://sozai.app/transcript/saas-ui-ux-mistakes-vibe-code/)). An open-source audit tool ranks the tells by severity. Its worst tier is a purple-blue gradient, "Inter everywhere", untouched shadcn zinc greys and reflexive glassmorphism. Its next tier is `rounded-2xl shadow-lg` on every surface, and its third is flat, uniform spacing ([avoid-ai-design](https://github.com/funboy322/avoid-ai-design)). Another critique argues the trap is the defaults rather than the library: "the starting kit is the same starting kit everyone else got" ([freedesignmd](https://freedesignmd.com/blog/shadcn-looks-generic)). A designer's field guide reads Inter with only a system fallback as a sign that "no one made a choice" ([Mania Design](https://www.mania.design/blog/spot-the-slop-a-ui-designers-guide-to-fixing-ai-defaults/)). Malewicz gives the theory behind this: "Structural is systemic, so easy to copy. Emotional is unpredictable". Because AI copies structure easily, differentiation now lives in the emotional layer ([Malewicz](https://michalmalewicz.medium.com/the-future-of-ui-design-past-2026-4f199c3d370b)).

Tasteful styles are also becoming clichés. LogRocket says "almost every SaaS website looks the same" in the Linear style and that its appeal is "starting to wear off due to oversaturation" ([LogRocket](https://blog.logrocket.com/ux-design/linear-design)). Copying Linear's surface now "produces the default look that AI builders generate" ([BuildMVPFast](https://www.buildmvpfast.com/blog/linear-aesthetic-tokens-density-keyboard-first-ux-2026)). The audit repo already lists cream-plus-terracotta and monochrome as the *new* AI defaults ([avoid-ai-design](https://github.com/funboy322/avoid-ai-design)). The durable lesson is to copy a trend's principles (hierarchy, restraint, tokens) and never its palette. The formula that holds up is Gruber's description of a Mac app that is "distinctive and branded, while looking and feeling in every way like a standard Mac app": native behaviour plus one brand move ([Daring Fireball](https://daringfireball.net/linked/2025/12/28/)).

For business apps, robustness sits underneath visual style. Salesforce Mobile reviewers praise the fact that "Clicking an address deep-links directly into Google Maps" and call the app "Fast and reliable". They complain that "the app does not retain the details for the leads I am working on", that reports don't open in a mobile view, that the "Search function needs to be enhanced", and that forms make them fill every box ([TrustRadius](https://www.trustradius.com/products/salesforce-mobile/reviews/all)). An agency guide to banking UX lists similar frictions: slow balances, forms that don't save, buried frequent tasks, and uncertainty about whether an action went through. Its statistics are unsourced ([YUJ Designs](https://www.yujdesigns.com/blog/mobile-banking-ux/)). Copilot Money's founder ties the premium feel to native code and local data: "having a native app makes a difference the moment you start interacting with it" ([Apple Developer](https://developer.apple.com/articles/copilot-money)). In 2026, then, "cheap" means a lack of decisions or a lack of robustness. A redesign that adds glass, gradients and bounce without fixing tokens, states and speed will look *more* AI-made, not less.

## Colour, type and depth now come with numbers attached

### Neutrals do the work, and the accent is a ramp used sparingly

Kole Jain gives the most concrete colour system. He describes Vercel's palette as "like 90% black, 8% white, and 2% red". He argues product UI needs "about four background layers, at least one stroke (often two), and about three text variants" rather than the 60-30-10 rule. In light mode, surfaces step about **2% in lightness**. Card edges use roughly 85% white instead of thin black borders. Text sits at about 11% lightness for headings, 15–20% for body and 30–40% for subtext. The accent is a *ramp*: 500/600 as the main colour, 700 for hover and 400–500 for links. On mobile, which has no hover, a slightly darker shade marks the pressed state. In dark mode the primary moves to 300–400 and surface steps widen to **4–6%**, because "surfaces get lighter as they elevate". To theme neutrals, he drops OKLCH lightness by 0.03, raises chroma by 0.02, and shifts the hue toward the brand ([Kole Jain](https://www.youtube.com/watch?v=66oOi9OLMCw)). Linear reached the same idea at product scale. It rebuilt its themes in the perceptually uniform LCH colour space, replacing **98 hand-set variables with three inputs: base, accent and contrast**. It deliberately uses the accent less, and it builds elevation from black and white opacities ([Linear](https://linear.app/now/how-we-redesigned-the-linear-ui)). An analysis of Linear's dark theme found depth built from tiny lightness steps (#0f1011 → #141516 → #18191a), "not drop shadows", with hairline borders meant to "read as texture". It also found that Linear's faintest grey reaches only **3.6:1**, below the WCAG AA minimum ([BuildMVPFast](https://www.buildmvpfast.com/blog/linear-aesthetic-tokens-density-keyboard-first-ux-2026)).

The sources disagree in two places. Kole Jain says pure-white backgrounds are fine (Notion's is 100%) ([Kole Jain](https://www.youtube.com/watch?v=66oOi9OLMCw)). A UX Planet essay says premium UIs "never use a pure neutral" and that #FFFFFF, #F5F5F5 and #000000 make a UI feel "assembled" ([UX Planet](https://uxplanet.org/the-one-color-decision-that-makes-a-ui-look-expensive-d6890efe11ba)). Both agree that text and borders should never be pure black. Kole Jain also contradicts himself on 60-30-10: one video recommends it and a later, more detailed one rejects it for product UI ([transcript](https://sozai.app/transcript/7-color-mistakes-ruin-ui-designs/)). His layered-neutral system looks like the evolved position. His other colour rules are consistent:

- Destructive actions stay red even when the brand colour is not red.
- Icons stay uncoloured, with colour reserved for status.
- Five or more accent colours across cards is "confusing".
- Gradients should use "variations of the same color, or none" ([Kole Jain](https://www.youtube.com/watch?v=AH_ugxmLeUM)).
- Dark mode is its own palette, not an inversion: dim the text, brighten the borders and lighten the elevated cards ([transcript](https://sozai.app/transcript/7-color-mistakes-ruin-ui-designs/)).

Whether dark mode should be the *default* is a separate question. Enterprise guidance says to offer it as a toggle and not to make it the default for productivity or regulated products, citing better proofreading in light mode ([Fuselab](https://fuselabcreative.com/ui-ux-design-trends-2026-modern-ui-trends-ux-trends-guide/)). Another source warns that "dark-by-default is a preference, not a proven upgrade" ([BuildMVPFast](https://www.buildmvpfast.com/blog/linear-aesthetic-tokens-density-keyboard-first-ux-2026)).

### Type: fewer sizes, two weights, and a display face doing the talking

The numeric rules are consistent. Malewicz: "3-4 sizes per screen maximum. 2 weights per screen maximum" ([Malewicz on X](https://x.com/michalmalewicz/status/1778813465638908279)). Kole Jain caps landing pages at about **six font sizes**. He keeps dashboard text at or below **24px**, tightens heading tracking by **−2% to −3%** and sets heading line height to **110–120%** ([Kole Jain](https://www.youtube.com/watch?v=EcbgbKtOELY)). He also makes the data larger than its label. In his billing redesign, the cost per month grows and the plan name shrinks ([transcript](https://sozai.app/transcript/saas-ui-ux-mistakes-vibe-code/)). The reference apps pair a display cut with a workhorse text face:

- Linear moved headings to **Inter Display** and kept Inter for text ([Linear](https://linear.app/now/how-we-redesigned-the-linear-ui)).
- Monzo pairs Oldschool Grotesk with Monzo Sans ([Monzo](https://monzo.com/blog/weve-had-a-little-makeover)).
- Cash App commissioned Cash Sans ([Abduzeedo](https://cms.abduzeedo.com/node/88974)).
- Wise pairs its own **Wise Sans (342 languages)** with Inter. It cut its type system from **22 styles to 14** (4 display, 4 title, 6 body) and tunes line height per language ([TYPE01](https://type-01.com/wise-sans-the-font-update-shaping-wises-visual-identity/)).

Wise is the closest analogue to SmartBroker's bilingual problem. Both platforms moved the same way in 2025. Material 3 Expressive gave every type style an *Emphasized* twin ([MDC Typography](https://gitea.com/784622644/material-components-android/src/branch/master/docs/theming/Typography.md)). Apple added emphasized weights to its Dynamic Type specs in December 2025 and still advises against Ultralight, Thin and Light weights ([HIG Typography](https://developer.apple.com/design/human-interface-guidelines/typography.md)). Heavier weights for key headings and actions are now a cross-platform cue. Monzo enlarges key amounts in what it calls "Exaggerated UI" ([Monzo](https://monzo.com/blog/weve-had-a-little-makeover)). Tabular (fixed-width) figures for money are a documented design-system convention, for example Maersk's "monospaced numbers" guideline ([Maersk](https://designsystem.maersk.com/content/numbers/monospaced-numbers/)). None of the fintech apps studied document their own numeral rules.

### Depth, spacing and icons reward subtraction

On depth, Kole Jain's rule is that "if the shadow is the first thing you notice on a design, you're not using it right". Lower the opacity, raise the blur, and give cards lighter shadows than popovers ([Kole Jain](https://www.youtube.com/watch?v=EcbgbKtOELY)). He prefers "outlines on dark modes and background colors on light mode". He avoids nested borders and stacked rounded containers, and he lists items plainly instead of boxing each one ([dashboard guide](https://sozai.app/transcript/build-dashboard-ui-beginner-guide/); [weirdly perfect UI](https://sozai.app/transcript/secret-weirdly-perfect-ui-designs/)). Material 3 formalised the same move: "Surface with elevation overlay has been replaced with tonal surface colors" ([MDC Color](https://gitea.com/784622644/material-components-android/src/branch/master/docs/theming/Color.md)). UX Planet adds three refinements: tint shadows with the colour of the casting element, use one light source, and layer a large soft shadow with a small tight one ([UX Planet](https://uxplanet.org/shadows-in-ui-design-tips-tricks-6cce062896d3)). Where glass is used, the restrained recipe is a translucent fill, a background blur, a 1px light border and an inner highlight. The Hype4 generator defaults to a **20px blur, 15% white fill, 1px border at 30% white and a 20px radius** ([Hype4](https://hype4.academy/tools/glassmorphism-generator)).

Layout polish comes from alignment more than from whitespace. Kole Jain's guidance:

- Use a 4-point spacing system and a four-column mobile grid ([Kole Jain](https://www.youtube.com/watch?v=EcbgbKtOELY)).
- Build every row so it creates an edge the next one aligns to.
- Left-align text to one edge and right-align numbers.
- Group by a meaningful criterion such as due date.
- Highlight one item by muting its neighbours rather than decorating it ([weirdly perfect UI](https://sozai.app/transcript/secret-weirdly-perfect-ui-designs/)).
- Make matching elements identical in size, radius and style, and use a **10px radius** for small components ([Kole Jain](https://www.youtube.com/watch?v=AH_ugxmLeUM)).

Malewicz's spacing ratio still holds. If a label sits X from its field, the next field should be 2–3X away and a heading 4–6X ([Malewicz](https://michalmalewicz.medium.com/5-research-based-ux-ui-tips-4c3e89fd758b)). Radius is contested. One Flutter guide recommends larger radii applied consistently ([Medium](https://medium.com/@ankii8946/how-i-made-my-flutter-app-feel-more-premium-541acc90ffcc)). The AI-tell catalogues flag one uniform radius on everything as a tell ([Mania Design](https://www.mania.design/blog/spot-the-slop-a-ui-designers-guide-to-fixing-ai-defaults/)). The two are reconcilable: use a radius *scale* tied to component type, applied consistently.

Icon rules are equally specific. Use one library, such as Phosphor, Lucide or Feather ([Kole Jain](https://www.youtube.com/watch?v=AH_ugxmLeUM)). Keep icons neutral, and show selection by moving from a thin outline to a filled variant. Raroque does exactly this with Heroicons' thin set in his budgeting app, avoids default SF Symbols as generic, and says "the most important thing to do when you do pick a style is to stay consistent with the style" ([Chris Raroque](https://youtubeds.com/@raroque/how-i-make-apps-feel-10x-better-5-design-secrets)). Icon size should match the text line height, for example 24px ([Kole Jain](https://www.youtube.com/watch?v=EcbgbKtOELY)). Empty states get custom illustrations or a mascot in several poses, not generic text ([Chris Raroque](https://youtubeds.com/@raroque/how-i-make-apps-feel-10x-better-5-design-secrets)). Airbnb's 2025 redesign made icons, 3D work and illustration in-house and gave icons meaning-bearing motion ([It's Nice That](https://www.itsnicethat.com/articles/airbnb-app-redesign-140525)).

## Feel is engineered through response, springs, haptics and designed endings

Raroque names five levers that make apps "FEEL 10x better":

- animated transitions, where the new page slides over the old one;
- custom empty-state illustrations;
- varied haptics;
- a consistent, non-default icon style;
- constant exposure to good design ([Chris Raroque](https://www.youtube.com/watch?v=8mMH6Pq8qnE)).

His dictation button is a useful template for SmartBroker. Send rotates into a checkmark, the background expands from the mic, and "listening" text fades in on a spring. He builds sequences like this from sub-animations rather than trying to "oneshot" them ([transcript](https://youtubeds.com/@raroque/how-i-make-apps-feel-10x-better-5-design-secrets)). His 2026 follow-up has chapters on "invisible craft" using a dictation example, but only the chapter list was verified ([YouTube](https://www.youtube.com/watch?v=MXLF8b15GhQ)). Kole Jain's playful pop-over spring is **500ms, stiffness 636, damping 24**. Buttons shrink while pressed, and tooltips wait **1,000ms** ([Kole Jain](https://sozai.app/transcript/micro-animations-level-up-ui-free-figma/)). A Flutter practitioner suggests about **300ms** transitions and press feedback that scales to **0.96 over ~120ms** ([Medium](https://medium.com/@ankii8946/how-i-made-my-flutter-app-feel-more-premium-541acc90ffcc)).

The platforms supply the production values. Material's duration tokens run from 50ms to 1000ms, and its easing curves include standard (0.2, 0, 0, 1) and emphasized decelerate (0.05, 0.7, 0.1, 1). Its standard springs use damping 0.9 at stiffness 1400, 700 and 300 for fast, default and slow spatial motion. Colour and opacity use effects springs with damping 1, "where the property's value should not be overshot" ([MDC Motion](https://github.com/material-components/material-components-android/blob/master/docs/theming/Motion.md)). Google splits motion into a `standard` scheme "for utilitarian UI elements and recurring interactions" and an `expressive` scheme "for prominent UI elements and hero interactions" ([Compose MotionScheme](https://composables.com/jetpack-compose/androidx.compose.material3/material3/interfaces/MotionScheme.md)). That split is the most useful idea in the motion research. Three cautions bound it:

- Trend writers report that "Over-animated interfaces feel oddly aggressive" and that 2026 favours "motion that explains" ([Envato](https://elements.envato.com/learn/ux-ui-design-trends)).
- NN/g judged iOS 26's wiggling, morphing controls harshly: "Motion for motion's sake is not usability. It's distraction with a side of nausea" ([NN/g](https://www.nngroup.com/articles/liquid-glass/)).
- Apple's Reduce Motion guidance asks apps to tighten springs, track gestures directly, and replace axis transitions with fades ([HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility.md)). WCAG 2.2 adds a AAA criterion that interaction-triggered motion "can be disabled" ([W3C](https://www.w3.org/TR/WCAG22/)).

Haptics follow the same restraint. Apple's rules:

- Use system patterns according to their meanings.
- Pair each haptic with visible feedback and match its intensity to the animation.
- "Avoid overusing haptics". The best haptic experience "is one that people may not be conscious of, but miss when it's turned off".
- Make haptics optional ([HIG Haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics.md)).

Raroque grades them: "Not all haptic feedback is equal". He uses light haptics for repetitive taps such as logging transactions and heavier ones for significant actions ([Chris Raroque](https://youtubeds.com/@raroque/how-i-make-apps-feel-10x-better-5-design-secrets)). The sources disagree on tab changes: Raroque uses a heavier impact, while Apple's taxonomy has a separate "selection" type for values that are changing. Things 3, praised in 2017, fires haptics on drag, on its Magic Plus button and on pull-to-search ([MacStories](https://www.macstories.net/reviews/things-3-beauty-and-delight-in-a-task-manager/)). Material 3 Expressive pairs a spring "detach" of a dismissed notification with a haptic rumble ([Android Authority](https://www.androidauthority.com/google-material-3-expressive-features-changes-availability-supported-devices-3556392/)).

The last layer is states and endings. Kole Jain wants loaders that are "short, looping, and fluid" and shimmer skeletons ([transcript](https://sozai.app/transcript/7-ui-components-design-unicorn-ai/)). He also wants optimistic updates that change the UI before the server confirms, and progressive disclosure through swipe actions, citing Apple Reminders ([dashboard guide](https://sozai.app/transcript/build-dashboard-ui-beginner-guide/); [dashboard flaws](https://sozai.app/transcript/dashboard-ui-flaws-never-built-one/)). Tim Gabe applies the peak-end rule: "Pick just one spot in the journey to spark it". He also designs a deliberate ending such as a checkmark or summary card, and warns that "negative moments are as memorable as positive ones" ([Tim Gabe](https://sozai.app/transcript/tiny-design-rule-top-apps/)). Flighty's team states the same principle for a high-stress domain: "We really have to shine when things go awry" ([Apple Developer](https://developer.apple.com/news/?id=970ncww4)). Airbnb's design lead adds that "The delightful moments always have a utility behind them" ([Design Week](https://www.designweek.co.uk/it-was-a-bit-nuts-teo-connor-on-designing-the-new-airbnb-app/)).

## Reference apps share a native skeleton and one signature move

Official sources for the reference apps almost never publish radii, hex values or type sizes for their native mobile apps. What they do publish is structure and philosophy, and that turns out to be the more useful material. The shared baseline has six parts:

- native performance;
- neutral surfaces with one accent;
- a display-plus-text type pairing;
- triage verbs (done, snooze, remind) on swipe;
- creation in sheets;
- purposeful micro-motion.

Each app stands apart through one signature idea. Several primary sources are old: the Things 3 review dates from 2017, and the Revolut and Monzo sources from 2022–2023. Third-party token extractions for Revolut and Copilot are low-confidence and are left out of the table below.

| App | Sourced premium signal | What SmartBroker should borrow |
|---|---|---|
| Linear | Inter Display headings; LCH themes from three inputs (base, accent, contrast); accent under-used; elevation via black/white opacities ([Linear](https://linear.app/now/how-we-redesigned-the-linear-ui)). Native Swift/Kotlin mobile app with "Tap to take action, swipe to delete, snooze" ([Linear mobile](https://linear.app/mobile)) | A three-input theme generator that also yields a high-contrast theme; swipe-to-snooze follow-ups |
| Things 3 | White-space-dominated, bold type, "thoughtful splashes of color"; draggable Magic Plus; tapped to-dos pop out as cards; haptics on drag and capture; Upcoming shows 7 days individually, then weeks; past calendar events turn grey (2017) ([MacStories](https://www.macstories.net/reviews/things-3-beauty-and-delight-in-a-task-manager/)) | Overdue/Today/Upcoming grouping; a capture button; greyed past events |
| Revolut | Revolut 10 (2023): key products one tap from home, home widgets, themes ([Revolut](https://www.revolut.com/news/revolut_launches_revolut_10_as_it_targets_primary_accounts_and_passes_35m_customers_worldwide)); "a clear hierarchy and minimal clutter" ([Marketing-Interactive](https://www.marketing-interactive.com/fintech-company-revolut-overhauls-look-in-global-brand-refresh)) | One-tap frequent actions; customisable home sections in a later phase |
| Monzo | Hot coral, deep navy, soft white; "Exaggerated UI" for key amounts ([Monzo](https://monzo.com/blog/weve-had-a-little-makeover)). Home tested on 8M+ people; "Simplicity isn't the absence of things, it's bringing order to complexity"; snoozable upgrade prompt ([Monzo Home](https://www.monzo.com/blog/how-we-built-the-new-home-screen)) | One enlarged hero number per screen; never interrupt a task |
| Copilot Money | ADA 2024 finalist; native UIKit/SwiftUI; local data makes it "really responsive"; charts as core UI ([Apple Developer](https://developer.apple.com/articles/copilot-money)) | Local-first reads for instant first paint |
| Notion | Tabbed mobile navigation (Home, AI Chats, Meeting Notes, Inbox) that "drastically reduces the 'taps to task'" ([Matthias Frank](https://matthiasfrank.de/en/notion-updates/new-tabbed-mobile-navigation/)) | Few top-level destinations, each a job rather than an object type |
| Superhuman | Sep 2026 redesign: bottom bar (Inbox, Calendar, Search); pull-down-anywhere search; swipe-anywhere back; "larger fonts, higher contrast", "warmer colors"; Liquid Glass on iOS, Material 3 on Android ([Superhuman](https://blog.superhuman.com/we-redesigned-superhuman-mail-for-ios-and-android/)). Swipe left Done, right Remind ([help](https://help.superhuman.com/article/461-mobile-customizing-swipes-and-triage-bar)) | Pull-down search; consistent swipe verbs; native chrome per OS |
| Attio | Mobile CRM on iOS 26+/Android 13+; Tasks in the bottom bar; swipeable record tabs (Emails, Calls, Notes, Tasks); "+" creates records, notes and tasks; call transcripts and summaries ([Attio](https://attio.com/help/reference/tools-and-extensions/attio-on-mobile)) | Swipeable record tabs; Tasks as a top-level destination |
| Airbnb | May 2025: "Fun, alive, and simple"; rounder; in-house animated icons; Trips as a "living itinerary" by the hour; 2×2 key-facts grid; 18 months and ~200 designers ([Design Week](https://www.designweek.co.uk/it-was-a-bit-nuts-teo-connor-on-designing-the-new-airbnb-app/); [It's Nice That](https://www.itsnicethat.com/articles/airbnb-app-redesign-140525)) | Hour-by-hour viewing itinerary; 2×2 key facts on the contact record |
| Flighty | ADA 2023 Interaction winner ([Apple](https://www.apple.com/newsroom/2023/06/apple-announces-winners-of-the-2023-apple-design-awards)); "boringly obvious"; "one line per flight" like airport boards; countdowns; assumes connectivity is lost ([Apple Developer](https://developer.apple.com/news/?id=970ncww4)) | One row per lead, task and viewing; a countdown to the next viewing; offline-first states |
| Cash App | Nov 2025: Cash Sans; "Hyper Neon Green"; 650+ geometric icons; 3D imagery; custom micro-animations; Moneybot acts only after confirmation ([Abduzeedo](https://cms.abduzeedo.com/node/88974)) | Confirm-before-act for any AI-drafted note, task or message |
| Wise | Wise Sans (342 languages) with Inter; 22 → 14 styles; line height tuned per language ([TYPE01](https://type-01.com/wise-sans-the-font-update-shaping-wises-visual-identity/)) | A lean multilingual type system with per-script metrics |

The CRM-specific apps agree on a record anatomy SmartBroker can adopt directly. HubSpot shows the name with a tappable stage chip beneath it and Call, Email and Text quick actions. It adds tabs such as About and Associations, a filterable timeline that starts with add note, add task and log activity, and a board where users **swipe horizontally between pipeline stages** ([HubSpot](https://knowledge.hubspot.com/records/work-with-records-in-the-hubspot-mobile-app?app=wp)). Attio puts Tasks in the bottom bar and uses swipeable record tabs ([Attio](https://attio.com/help/reference/tools-and-extensions/attio-on-mobile)). Close keeps the profile and notes visible during calls ([Close](https://close.com/blog/close-mobile-app)). folk's mobile app captures contacts with voice-to-text notes and a business-card scanner ([folk](https://www.folk.app/changelog/introducing-contacts-by-folk-our-mobile-app)). No credible source ranks these CRMs on visual quality, so calling any of them "best-in-class" is unverified.

## Apple and Google both say expressive at the edges, calm at the core

Material 3 Expressive (May 2025) is an update to Material 3, not a new version. It adds:

- spring physics;
- a library of **35 shapes** with morphing;
- emphasized type;
- richer colour;
- about **15 new or refreshed components**, including button groups, split buttons, a floating pill toolbar and a FAB menu ([Android Authority](https://www.androidauthority.com/google-material-3-expressive-features-changes-availability-supported-devices-3556392/)).

Google backs it with its own research: **46 studies and more than 18,000 participants**. Key elements were spotted **up to 4x faster**, users aged 45+ performed on par with younger users, and preference reached **87% among 18–24-year-olds** ([Google Design](https://design.google/library/expressive-material-design-google-research)). The 4x example is telling: it came from a large, coloured Send button placed just above the keyboard, not from decoration ([Chrome Unboxed](https://chromeunboxed.com/google-leaks-the-reason-and-process-behind-their-new-material-3-expressive-design-language)). Google's own caveats matter more for a CRM than its headline figures. Expressiveness is "not a one-size-fits-all solution", and a banking interface is named as a poor fit. Removing text labels and breaking familiar patterns hurt usability, and "a strong minority of users preferred calmer, less intense designs" ([Google Design](https://design.google/library/expressive-material-design-google-research)). Google VP Vanessa Cho gives paying a parking ticket as a case where playfulness is wrong ([Dezeen](https://www.dezeen.com/2025/05/28/google-ushers-in-age-of-expressive-interfaces-with-material-design-update/amp/)).

Flutter cannot simply import any of this yet. In May 2025 the Flutter team said it would "not be accepting contributions for Expressive features" ([flutter#168813](https://github.com/flutter/flutter/issues/168813)). In August 2026 Material and Cupertino were split out of the framework into standalone `material_ui` and `cupertino_ui` packages. The September announcement says "work is already underway on official implementations of Liquid Glass and Material 3 Expressive", with no date given ([Flutter blog](https://flutter.dev/blog/decoupling-material-cupertino)). `material_ui` 1.8.0 shipped on 20 October 2026 with a `dart fix` migration ([pub.dev](https://pub.dev/packages/material_ui)). Very Good Ventures advises teams to consider their own UI package for branded designs ([VGV](https://verygood.ventures/blog/a-new-era-for-app-design-and-what-it-means-for-flutter/)).

Apple's Liquid Glass (WWDC 2025, iOS 26) teaches the same lesson from the other side. Apple says glass "is best reserved for the navigation layer that floats above the content of your app". Its other rules from the same session:

- "Always avoid glass on glass."
- The Clear variant needs a dimming layer.
- "Tinting should only be used to bring emphasis to primary elements and actions".
- "If you want to imbue color into your app, do it in the content layer instead" ([WWDC25](https://developer.apple.com/videos/play/wwdc2025/219/?time=89)).

NN/g nonetheless concluded that "Apple is prioritizing spectacle over usability". It cited text over images and text, wiggling controls, crowded tab bars, and targets that move and resize unpredictably ([NN/g](https://www.nngroup.com/articles/liquid-glass/)). Apple then retreated in steps:

- a Tinted option that "increases opacity" in iOS 26.1 ([TechCrunch](https://techcrunch.com/2025/10/20/apple-will-let-users-roll-back-the-liquid-glass-look-with-new-tinted-option));
- an option to disable highlights in iOS 26.4 ([TechRadar](https://www.techradar.com/phones/ios/liquid-glass-isnt-going-anywhere-in-ios-27-but-theres-good-news-for-its-readability));
- in iOS 27, a material that "diffuses complex content behind it much more effectively", plus a transparency slider ([BGR](https://www.bgr.com/2191219/ios-27-liquid-glass-fix-customization/)).

Enterprise guidance draws the practical line: test glass on navigation and overlays, but **skip it where users read numbers** and on tabular and form screens ([Fuselab](https://fuselabcreative.com/ui-ux-design-trends-2026-modern-ui-trends-ux-trends-guide/)). Superhuman's 2026 redesign shows the cross-platform answer in practice: Liquid Glass on iOS and Material 3 on Android ([Superhuman](https://blog.superhuman.com/we-redesigned-superhuman-mail-for-ios-and-android/)).

Under both systems sits an accessibility floor that a premium redesign must not trade away.

| Requirement | WCAG 2.2 | Android | Apple HIG |
|---|---|---|---|
| Text contrast | 4.5:1; 3:1 for large text (18pt, or 14pt bold) ([W3C](https://www.w3.org/TR/WCAG22/)) | 4.5:1 below 18sp (or 14sp bold), else 3:1 ([Android](https://developer.android.com/guide/topics/ui/accessibility/apps)) | WCAG AA in light and dark; offer an Increase Contrast scheme ([HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility.md)) |
| UI component contrast | 3:1 against adjacent colours ([W3C](https://www.w3.org/TR/WCAG22/)) | — | — |
| Target size | 24×24 CSS px at AA ([W3C](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html)) | 48×48dp, "Larger is even better" ([Android](https://developer.android.com/guide/topics/ui/accessibility/apps)) | 44×44pt default ([HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility.md)) |
| Text resize | 200% without loss ([W3C](https://www.w3.org/TR/WCAG22/)) | Up to 200%, non-linear, since Android 14; use sp for text only ([Android 14](https://developer.android.com/about/versions/14/features)) | At least 200% ([HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility.md)) |
| Motion | Interaction motion can be disabled (AAA) ([W3C](https://www.w3.org/TR/WCAG22/)) | "Remove animations" maps to Flutter's `disableAnimations` ([Flutter](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html)) | Reduce Motion: tighten springs, swap axis moves for fades ([HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility.md)) |

The cross-platform vocabulary of 2025–26 is now clear. Both systems use a floating pill navigation or toolbar, a large primary action within thumb reach, emphasized weights for key text, and calm springs for routine motion with bouncier ones reserved for hero moments. An Android-first Flutter app can speak that vocabulary without cloning either platform's chrome.

## Ethiopic script, older Androids and patchy networks reshape the brief

The Ethiopic font choice is clearer than expected:

- **Noto Sans Ethiopic** is the safest UI face. It is OFL-licensed, variable from weight 100 to 900 and width 62.5 to 100, and covers 566 glyphs across the Ethiopic blocks ([Fontsource](https://fontsource.org/fonts/noto-sans-ethiopic/about)).
- **Menbere** is the most "modern UI" option. Its Ethiopic is by Aleme Tadesse and its matched Latin by Eben Sorkin. It is OFL-licensed, variable from 100 to 700, and described as "a modernized, low-contrast design built on traditional Ethiopic forms" for "corporate, print, screen, and UI use" ([Fontsource](https://fontsource.org/fonts/menbere/about)).
- **Abyssinica SIL** is calligraphic and suits long-form or traditional text ([SIL](https://software.sil.org/abyssinica/)).
- **Nyala** (Microsoft) and **Power Geez** should not be bundled, because their licences are proprietary.
- Satoshi and General Sans are free but "still controlled by an ITF EULA" that does not address app embedding ([ITF](https://www.indiantypefoundry.com/news/introducing-fontshare)).
- **Inter** is OFL and supports `tnum` (tabular figures) ([rsms.me](https://rsms.me/inter/)).

A small, recent Flutter package, `ethiopic_typography`, already pairs Manrope with Noto Sans Ethiopic as a fallback "so mixed English and Amharic text renders correctly without manual font switching" ([pub.dev](https://pub.dev/packages/ethiopic_typography)).

Three engineering facts follow. First, Flutter's `fontFamilyFallback` resolves glyph by glyph, and the Android default family is Roboto ([TextStyle](https://api.flutter.dev/flutter/painting/TextStyle-class.html)). Bundling the Ethiopic font makes rendering deterministic and avoids variation in OEM system fonts. That last point is an inference. Second, Latin and Ethiopic fonts have different ascent and descent metrics, so mixed lines can grow taller and list rows can jitter. Explicit `height` values with `TextLeadingDistribution.even`, or a forced strut, normalise them ([TextLeadingDistribution](https://api.flutter.dev/flutter/dart-ui/TextLeadingDistribution.html); [startdebugging](https://startdebugging.net/2026/01/flutter-text-the-leadingdistribution-detail-that-changes-how-your-ui-breathes/)). Third, a fallback font inherits the span's style. Latin-style negative tracking on a heading style is therefore applied to Amharic glyphs too, unless the style is chosen per script.

The W3C's Ethiopic layout draft adds four conventions:

- "Latin text is often set in a heavier weight to match Ethiopic text".
- Both scripts share a baseline.
- Lines should not start with Ethiopic punctuation such as ። or ፣.
- "Modern practice is shifting to Western numerals" ([W3C elreq](https://www.w3.org/TR/elreq/)).

That last convention lets SmartBroker use Inter's tabular Western digits for money and phone numbers. **No source gives measured minimum sizes or line heights for Ethiopic on screens.** The 16sp body size and 1.5 line height below are inferred starting points for testing with native readers.

The device and rendering constraints are concrete:

- Impeller is Flutter's renderer on Android API 29+. Older devices fall back to the legacy GL path ([Flutter docs](https://docs.flutter.dev/perf/impeller); [Flutter 3.32](https://flutter.dev/blog/whats-new-in-flutter-3-32)).
- `saveLayer`, clipping and `Opacity` inside animations are expensive on mobile GPUs ([Flutter performance](https://docs.flutter.dev/perf/best-practices)).
- Flutter's new success, warning and error haptics do nothing on Android below API 30 ([Flutter commit](https://flutter.googlesource.com/mirrors/flutter/+/c0e052941af58233d0b962e26fcfc03c8fb1124f%5E%21)).

The research found **no data on the Android device mix in Ethiopia** and no study of how Ethiopian users perceive "premium" UI. The assumption that many brokers use mid- to low-range phones on older API levels is plausible but unverified. Blur, springs and haptics therefore need fallbacks and must be tested on an API 28 device.

Connectivity matters for the same reason. Flighty designs on the assumption that connectivity is lost in flight ([Apple Developer](https://developer.apple.com/news/?id=970ncww4)). Copilot keeps "all the data… locally, so the app is really responsive" ([Apple Developer](https://developer.apple.com/articles/copilot-money)). Salesforce users punish lost state ([TrustRadius](https://www.trustradius.com/products/salesforce-mobile/reviews/all)). For a broker moving between viewings on mobile data, local-first behaviour is part of looking premium.

Several locale needs fall *outside* the research notes and are flagged as inferences to verify with users:

- Ethiopia's own calendar and its convention of counting hours from dawn, which affect the calendar and task screens.
- The prominence of Telegram as a messaging channel, which affects quick actions.
- Ethiopic is a unicase script with no capital letters, so uppercase "eyebrow" labels and case-based hierarchy have no Amharic equivalent.
- Search should match Amharic names from Latin transliterations.

## Fourteen principles for a premium SmartBroker

The principles below turn the research into rules SmartBroker's designers and developers can apply screen by screen. The "Basis" column marks each as **S** (stated by the cited sources), **A** (adapted: a sourced principle with a SmartBroker-specific application) or **I** (inferred, with no direct source).

| # | Principle | What it means in SmartBroker | Basis |
|---|---|---|---|
| 1 | Tokens before screens | Every colour, size, radius, shadow, duration and haptic is a named token decided once. No widget ships with Material defaults ([freedesignmd](https://freedesignmd.com/blog/shadcn-looks-generic); [Medium](https://medium.com/@ankii8946/how-i-made-my-flutter-app-feel-more-premium-541acc90ffcc)) | S |
| 2 | One accent, earned | Deep teal appears only on the primary action, focus, selection and the active nav item. Secondary actions are neutral ([freedesignmd](https://freedesignmd.com/blog/shadcn-looks-generic); [Linear](https://linear.app/now/how-we-redesigned-the-linear-ui)) | S |
| 3 | Neutrals carry the hierarchy | Tinted teal-grey layers about 2% apart in light mode and 4–6% in dark; three text tones; no pure-black text ([Kole Jain](https://www.youtube.com/watch?v=66oOi9OLMCw)) | A |
| 4 | Numbers lead | One hero number per screen; tabular figures in every list; numbers right-aligned; labels smaller than data ([Kole Jain](https://sozai.app/transcript/secret-weirdly-perfect-ui-designs/); [Monzo](https://monzo.com/blog/weve-had-a-little-makeover)) | A |
| 5 | One row per thing | Each lead, task and viewing reads in one row: who, what's next, when ([Flighty](https://developer.apple.com/news/?id=970ncww4)) | A |
| 6 | Fast is the first luxury | Local-first reads, instant paint from cache, optimistic writes, no lost state, a visible offline queue ([Copilot](https://developer.apple.com/articles/copilot-money); [TrustRadius](https://www.trustradius.com/products/salesforce-mobile/reviews/all)) | A |
| 7 | Structure, not containers | Grouped lists with shared edges, no card inside a card; cards only for objects you act on ([Kole Jain](https://sozai.app/transcript/secret-weirdly-perfect-ui-designs/)) | S |
| 8 | Calm core, expressive edges | Near-critically-damped motion for repeated actions; bounce only for capture, deal-won and first-run moments ([MotionScheme](https://composables.com/jetpack-compose/androidx.compose.material3/material3/interfaces/MotionScheme.md); [Google Design](https://design.google/library/expressive-material-design-google-research)) | S |
| 9 | Haptics are semantic and optional | Selection, threshold, success and error only; never on scroll; an off switch in Settings ([HIG](https://developer.apple.com/design/human-interface-guidelines/playing-haptics.md)) | S |
| 10 | Glass only on floating chrome | The nav pill may be frosted; no text or numbers sit on glass; always a solid fallback ([WWDC25](https://developer.apple.com/videos/play/wwdc2025/219/?time=89); [Fuselab](https://fuselabcreative.com/ui-ux-design-trends-2026-modern-ui-trends-ux-trends-guide/)) | A |
| 11 | Labels stay, targets grow | Nav keeps text labels; 48dp minimum and 56dp for primary actions; layouts survive 200% text ([Google Design](https://design.google/library/expressive-material-design-google-research); [NN/g](https://www.nngroup.com/articles/liquid-glass/)) | S |
| 12 | Bilingual by construction | Every component is designed and tested with Amharic strings first, with per-script metrics and no Latin-only tricks ([W3C elreq](https://www.w3.org/TR/elreq/); [Wise](https://type-01.com/wise-sans-the-font-update-shaping-wises-visual-identity/)) | A |
| 13 | Design the unhappy paths | Empty, offline, syncing, error and permission-denied states are designed with real copy ([Mania Design](https://www.mania.design/blog/spot-the-slop-a-ui-designers-guide-to-fixing-ai-defaults/); [Tim Gabe](https://sozai.app/transcript/tiny-design-rule-top-apps/)) | S |
| 14 | One signature move | Menbere's matched Ethiopic-Latin display type plus a commissioned illustration set, used consistently ([freedesignmd](https://freedesignmd.com/blog/shadcn-looks-generic) on a "signature token"; [Raroque](https://youtubeds.com/@raroque/how-i-make-apps-feel-10x-better-5-design-secrets) on illustration) | A/I |

## A proposed SmartBroker design system

### Fonts for Latin and Ethiopic

The recommended stack has three roles. **Menbere** (OFL, wght 100–700) is the *display* face for screen titles, section headers and the contact name in both scripts. It is SmartBroker's signature move because it is a typeface designed for Ethiopic with a Latin drawn to match, which no generic template ships. **Inter** (OFL, with `tnum`) is the *text* face for all body, labels and numbers, with **Noto Sans Ethiopic** (OFL, wght 100–900) as its glyph fallback for Amharic. Hero numerals use Inter with tabular figures, because Menbere's tabular-figure support was not verified.

The Inter/Menbere pairing mirrors the display-plus-text pattern of Linear, Wise and Monzo. Inter's "AI default" reputation attaches to *undecided* Inter, not to Inter inside a deliberate pairing with tuned tracking and figures. Two fallbacks exist if Menbere's headings test poorly with Amharic readers. One is Menbere for everything: a single family with no metric mismatch, but weights stop at 700, its Latin is humanist and tabular figures are unverified. The other is the `ethiopic_typography` pairing of Manrope and Noto Sans Ethiopic.

Bundle every font as an asset, never fetch at runtime, and register the OFL licence texts. Ship only the weights used (400 and 600, plus 500 if testing shows the scripts need weight balancing) to control APK size. *(Basis: fonts and licences sourced; the role assignment is inferred.)*

### Colour tokens with light and dark values

The palette follows Kole Jain's structure (four background layers, a border family, three text tones, one accent ramp, semantic colours) and Linear's restraint. The brand seed is a **deep "Nile teal"**, chosen to avoid the purple-blue and Tailwind-blue AI defaults and to sit with the "earthy" palettes trend writers favour ([Bubble](https://bubble.io/blog/web-design-trends/)). **The seed hue and every hex value below are inferred placeholders**, generated in OKLCH with neutrals at hue 195 (chroma 0.004–0.012) and the accent at hue 192. Contrast ratios were computed with the WCAG formula for this report. If SmartBroker has an existing brand colour, regenerate the ramp from it using the same lightness targets.

| Token | Light | Dark | Use | Contrast (light / dark) |
|---|---|---|---|---|
| canvas | `#F3F7F6` | `#0E1414` | Scaffold background | — |
| surface | `#FFFFFF` | `#151D1D` | Cards, list groups, record header blocks | — |
| surfaceRaised | `#FFFFFF` + e2 shadow | `#1D2626` + border | Floating nav, menus, sheets, dialogs | — |
| fill | `#E8EEEE` | `#252D2D` | Inputs, unselected chips, segmented track, quick-action tiles, skeleton base | — |
| fillPressed | `#DEE4E4` | `#2D3636` | Pressed neutral rows and controls (mobile has no hover) | — |
| borderSubtle | `#DFE4E4` | `#273030` | Dividers; dark-mode card edges | Decorative |
| border | `#CBD3D2` | `#394242` | Outlines on filled inputs and chips | Decorative (≈1.4–1.8:1) |
| borderStrong | `#7E8988` | `#6D7777` | Checkbox rings, radios, unfilled input outlines | 3.3 / 4.0 on canvas (meets 3:1 for components) |
| textPrimary | `#141C1C` | `#E5EDED` | Names, titles, body | 16.0 / 15.7 |
| textSecondary | `#4D5858` | `#ACB7B6` | Second lines, metadata, unselected nav labels | 6.8 / 9.0 |
| textTertiary | `#737D7C` | `#7E8988` | Disabled and purely decorative text only | 3.9 / 5.2 (fails 4.5 in light mode) |
| accent | `#047270` | `#66D2CE` | Primary button, links, focus ring, selection | 5.3 / 10.3 on canvas |
| onAccent | `#FFFFFF` | `#00201F` | Text and icons on accent | 5.8 / 9.5 |
| accentPressed | `#065C5A` | `#37BAB6` | Pressed primary | 7.8 (white on it) / — |
| accentContainer | `#D2F3F1` | `#023634` | Selected chip, nav indicator, "today" in the calendar | — |
| onAccentContainer | `#023B3A` | `#AAE5E2` | Text on accentContainer | 10.6 / 9.5 |
| danger | `#C22826` | `#F47B74` | Overdue, destructive actions, errors | 5.4 / 7.0 |
| dangerContainer | `#FEEBE9` | `#451E1C` | Overdue chip, error banner | danger text on it 5.0 / 5.5 |
| warning | `#995B03` | `#F0BA59` | Due today, attention | 5.1 / 10.5 |
| warningContainer | `#FEF0D4` | `#38280A` | Warning chip or banner | 4.8 / 8.0 |
| success | `#287C42` | `#76CF8A` | Closed-won, saved, synced | 4.8 / 9.8 |
| successContainer | `#E3F6E6` | `#15301B` | Success chip or banner | 4.6 / 7.5 |

Use the light-mode `textTertiary` only for disabled and decorative text; it never carries meaning. Scrims are `#141C1C` at 32% opacity in light mode and black at 56% in dark mode. Shadows use a teal ink (`#0B2A2A`) rather than black, following the tinted-shadow advice ([UX Planet](https://uxplanet.org/shadows-in-ui-design-tips-tricks-6cce062896d3)).

If SmartBroker ever needs charts (pipeline by stage, say), use Kole Jain's method: fix lightness and chroma, then step the hue by 30 ([Kole Jain](https://www.youtube.com/watch?v=66oOi9OLMCw)). That gives light `#0A8C89`, `#1C87A5`, `#4C7DB4`, `#7172B4`, `#8E68A5` and dark `#51BFBB`, `#5AB9D8`, `#7CAFE8`, `#A1A3E9`, `#C099D9`. Deal stages should otherwise be *neutral* chips with text, with colour only for Closed (success), Lost (textTertiary plus strikethrough) and Overdue (danger). Kole Jain warns that five or more accent colours is "confusing" ([transcript](https://sozai.app/transcript/7-color-mistakes-ruin-ui-designs/)).

The app follows the system theme with light as the fallback, so dark mode is offered rather than imposed, in line with Fuselab's advice. The dark palette is its own design: surfaces lighten as they rise, borders replace shadows, and the accent moves to the 300 step. A high-contrast variant comes from regenerating with `contrastLevel: 1.0`, following Linear's base/accent/contrast model. *(Basis: structure S/A; all values I.)*

### Type scale

The scale uses six sizes and two weights per screen (400 and 600), following Malewicz's and Kole Jain's caps. Sizes respect Android's sp rule and stay at or below 24sp except for the single hero number.

| Role | Flutter slot | Size / line (sp) | Weight | Latin tracking | Font | Use | Basis |
|---|---|---|---|---|---|---|---|
| numHero | `displaySmall` | 36 / 40 (1.1) | 600 | −0.72 (−2%) | Inter, `tnum` | One hero number per screen | A |
| titleScreen | `headlineSmall` | 24 / 30 (1.25) | 600 | −0.36 (−1.5%) | Menbere | Large app-bar titles, contact name | A |
| titleSection | `titleLarge` | 20 / 26 (1.3) | 600 | −0.2 (−1%) | Menbere | Section headers, sheet titles | A |
| body | `bodyLarge`, `titleMedium` (600) | 16 / 24 (1.5) | 400; 600 for row titles and buttons | 0 | Inter + Noto Sans Ethiopic | List primary text, notes, buttons | A/I |
| secondary | `bodyMedium` | 14 / 20 (1.43) | 400 | 0 | Inter + Noto Sans Ethiopic | Second lines, metadata, timeline items | A |
| label | `labelLarge` | 13 / 18 (1.38) | 600 | +0.13 (+1%) | Inter + Noto Sans Ethiopic | Chips, nav and tab labels, timestamps | I |

Five rules apply across the scale:

- Negative tracking applies to Latin strings only. Amharic strings get 0.
- No size below 13sp, because the Ethiopic minimum is unknown. Material allows 11sp ([MDC Typography](https://gitea.com/784622644/material-components-android/src/branch/master/docs/theming/Typography.md)).
- No uppercase eyebrows, since the hierarchy must survive in unicase Ethiopic.
- Every numeric run (prices, phone numbers, counts, times) uses `FontFeature.tabularFigures()` ([Flutter](https://api.flutter.dev/flutter/dart-ui/FontFeature/FontFeature.tabularFigures.html)).
- If native readers find mixed lines uneven, render Ethiopic one variable-weight step lighter (for example 550 against Latin 600), following elreq's weight-matching note. This is inferred and test-driven.

### Spacing, layout and radii

Spacing is a 4-pt scale, with layout constants built from it.

| Token | dp | Typical use |
|---|---|---|
| s1 | 4 | Label-to-value gap; icon-to-text inside chips |
| s2 | 8 | Between chips; avatar-to-text in dense rows |
| s3 | 12 | Row vertical padding; between related fields' labels |
| s4 | 16 | Screen gutter; row horizontal padding; between form fields (≈3× the label gap) |
| s5 | 20 | Card inner padding |
| s6 | 24 | Before a section header (≈4–6× the label gap); nav-to-content clearance extra |
| s8 | 32 | Between dashboard sections |
| s12 | 48 | Empty-state illustration margins |

The layout constants are these. Screen gutter 16dp. One-line rows at least 56dp. Contact and task rows 72dp with a 40dp avatar or a 24dp checkbox inside a 48dp target. Primary buttons 52dp tall. The floating nav is 64dp. List bottom padding equals nav height plus 24dp, so the last row clears the pill. *(Basis: 4-pt grid, ratios and 48dp minimum sourced; specific values A/I.)*

Radii form a scale tied to component type. They are not one uniform value.

| Token | dp | Applied to |
|---|---|---|
| r.xs | 6 | Status badges, tags |
| r.sm | 10 | Property thumbnails, small inner tiles (Kole Jain's small-component radius) |
| r.md | 14 | Text inputs, quick-action tiles, items inside cards |
| r.lg | 20 | Cards, list groups, the "Next up" card |
| r.xl | 28 | Bottom sheets (top corners), dialogs |
| r.full | pill | Buttons, chips, segmented controls, floating nav, capture button, avatars |

Nest radii by subtracting the padding. A 20dp card with 6dp inset holds 14dp tiles, and a 28dp sheet with 8dp inset holds 20dp groups. Render all of them with Flutter's `RoundedSuperellipseBorder`, the built-in squircle on Android and iOS since 3.32 ([Flutter 3.32](https://flutter.dev/blog/whats-new-in-flutter-3-32)). *(Basis: the scale sits inside Material's 4–48dp shape scale ([MDC Shape](https://gitea.com/784622644/material-components-android/src/branch/master/docs/theming/Shape.md)); the nesting rule and assignments are I.)*

### Elevation, borders and glass

| Level | Light | Dark | Used for |
|---|---|---|---|
| e0 | canvas, no shadow | canvas | Screen background |
| e1 | surface (`#FFFFFF`) on canvas, no shadow | surface + 1px borderSubtle | Cards, list groups |
| e2 | surfaceRaised + shadows `0 1 2` at 5% and `0 8 24` (spread −4) at 8%, ink `#0B2A2A` | surfaceRaised + 1px border, no shadow | Floating nav, capture button, menus, snackbars |
| e3 | surfaceRaised + shadows `0 2 6` at 6% and `0 16 40` (spread −8) at 14% | surfaceRaised + 1px border | Bottom sheets, dialogs |

Glass is allowed in one place, the floating nav pill, and only when the device is on API 29 or later. The recipe is surfaceRaised at **82% opacity** (light) or **86%** (dark), a **σ = 20** backdrop blur (the Hype4 default), and a 1px top highlight: white at 60% in light mode, white at 6% in dark. The fallback is the opaque e2 surface. Never put glass behind numbers, lists or forms. *(Basis: tonal elevation, borders in dark mode and glass placement sourced; shadow and opacity values A/I.)*

### Motion and haptics

| Token | Value | Use | Basis |
|---|---|---|---|
| press | Scale to 0.97 with a fillPressed or accentPressed colour, 100ms, standard easing (0.2, 0, 0, 1) | Every tappable row, tile and button | A |
| quick | 150–200ms, standard easing | Chip select, checkbox fill, icon outline→fill swap, colour changes | A |
| page | 300ms, emphasized decelerate (0.05, 0.7, 0.1, 1) in; 200ms emphasized accelerate (0.3, 0, 0.8, 0.15) out | Shared-axis push and pop; fade-through between tabs; container transform from row to record | S |
| spring.standard | Damping ratio 0.9, stiffness 700 | Sheets, expanding cards, reorder, nav indicator | S (Material default spatial) |
| spring.fast | Damping ratio 0.9, stiffness 1400 | Press release, toggles, swipe-action snap-back | S |
| spring.hero | `withDurationAndBounce(400ms, bounce 0.2)` | Capture button morph, dictation start, deal moved to Closed | A |
| stagger | 30–40ms interval, 200ms fade with 8% upward slide, first screenful only | First load of Home and lists | A |
| reduced | Zero duration, or a 150ms crossfade for state changes | When `disableAnimations` or iOS reduceMotion is on | S |

| Event | Flutter call (API 30+) | Fallback below API 30 | Basis |
|---|---|---|---|
| Tab change, segmented control, chip toggle, picker value | `selectionClick` | Same | S (HIG "selection") |
| Swipe action crosses its threshold; sheet snaps to a detent; pull-to-refresh arms | `lightImpact` | Same | A (Raroque: light for frequent actions) |
| Task checked off | `lightImpact` | Same | A |
| Note saved from dictation; deal moved to Closed | `successNotification` | `mediumImpact` | A |
| Validation fails on save; a user-initiated action fails | `errorNotification` | `heavyImpact` | A |
| Destructive confirmation shown | `warningNotification` | None | I |

Never fire haptics on scroll, on every list item, or for background sync. A Settings toggle turns all haptics off, and haptics never replace visible feedback ([HIG](https://developer.apple.com/design/human-interface-guidelines/playing-haptics.md); [Flutter HapticFeedback](https://api.flutter.dev/flutter/services/HapticFeedback-class.html)). Tab changes use `selectionClick`, not Raroque's heavier impact, because a CRM switches tabs constantly. That choice is inferred.

### Iconography and imagery

Use **Phosphor** (`phosphor_flutter` 2.1.0, MIT) in **Regular** weight everywhere, switching to **Fill** for selected nav items and active toggles ([pub.dev](https://pub.dev/documentation/phosphor_flutter/latest/)). Phosphor is the library Kole Jain names, and it avoids the "stock Android" read of default Material Symbols, which mirrors Raroque's objection to default SF Symbols. **Material Symbols Rounded** is the alternative if icon coverage runs short. It is the only option whose stroke weight is a continuous theme value (100–700) ([pub.dev](https://pub.dev/documentation/material_symbols_icons/4.2951.0/)). Never mix the two on one screen.

Icons are 24dp, matching the 24sp body line height, and 20dp inline in dense metadata. They are coloured textSecondary by default, textPrimary on actionable icon buttons, and accent only when selected. Avatars are real photos when the broker has one. Otherwise they show a monogram (the first Latin letter or the first fidel character) in textSecondary on fill, never a gradient circle. Property thumbnails are real photos at r.sm.

Commission one illustrator for a small base set of empty-state drawings: no contacts, an "all clear" for no tasks today, offline, and no search results. Derive variants from that set, as Raroque recommends ([Chris Raroque](https://youtubeds.com/@raroque/how-i-make-apps-feel-10x-better-5-design-secrets)). Avoid generic AI imagery, which trend writers call "instantly recognizable" ([Bubble](https://bubble.io/blog/web-design-trends/)). Write all copy natively in Amharic and English, never machine-translated. *(Basis: libraries and rules sourced; the choice of Phosphor over Material Symbols, and the localisation guidance, are I.)*

### Component patterns by screen

#### Floating navigation

A detached pill (r.full, e2) sits inset 16dp from each side and 12dp above the system gesture area, 64dp tall. It holds four labelled destinations, **Home, Contacts, Tasks and Calendar**, with Amharic labels written by native speakers and widths tested against the longer of the two strings. A **separate 56dp circular capture button** in the accent colour sits beside the pill. It echoes iOS 26's separated search tab ([Donny Wals](https://www.donnywals.com/exploring-tab-bars-on-ios-26-with-liquid-glass/)), Material 3 Expressive's floating toolbar, and Things 3's Magic Plus. It opens a capture sheet for dictating a note, adding a contact, adding a task or adding a viewing. A long press starts dictation straight away.

On the selected destination, the icon switches to Fill, the label turns textPrimary at weight 600, and an accentContainer indicator slides behind the icon on spring.standard, with a `selectionClick` haptic. Tabs change with a fade-through. Settings lives behind the broker's avatar on Home, not in the bar. Labels always show, because Google's research and NN/g both found that dropping labels hurt usability. **The bar does not shrink or hide on scroll**, which avoids the "hide-and-seek" controls NN/g criticised ([NN/g](https://www.nngroup.com/articles/liquid-glass/)). *(Basis: A; the no-hide decision and the long-press shortcut are I.)*

#### Home dashboard ("Today")

Home has one focus: what the broker must do today, following Kole Jain's "one focus per dashboard" ([dashboard guide](https://sozai.app/transcript/build-dashboard-ui-beginner-guide/)). From top to bottom:

- **Header.** A greeting with the date (a dual Gregorian/Ethiopian date line is inferred and needs verifying), the avatar for Settings, and a quiet sync line such as "Synced 2 min ago" or "Offline · 3 changes queued".
- **Hero number.** The count of follow-ups due today in numHero, with "2 overdue" beneath it in danger.
- **"Next up" card.** A Flighty-style single item: "Viewing · 3-bed, Bole · in 32 min", with the client's name and **Call** and **Directions** buttons that deep-link to the dialler and maps.
- **"Due today".** Tasks as plain rows with swipe actions.
- **Pipeline.** One horizontal stage strip with right-aligned tabular counts. No donut charts, and no bento grid unless tile size encodes importance ([Bubble](https://bubble.io/blog/web-design-trends/)).
- **Recently added contacts.**

First paint comes from the local cache, and skeletons appear only on a first-ever sync. Customisable sections in the Monzo and Revolut manner belong to a later phase. Fuselab warns against behaviour-driven layout changes because "shifting layouts break muscle memory" ([Fuselab](https://fuselabcreative.com/ui-ux-design-trends-2026-modern-ui-trends-ux-trends-guide/)). *(Basis: A.)*

#### Contacts list

The list sits under a `SliverAppBar.large` titled "Contacts", which collapses on scroll. Below the title are a search field (pulling down focuses search, as in Superhuman) and a horizontally scrolling row of filter chips: All, Buyers, Sellers, Tenants, Landlords, Hot. The segment names are inferred. The default sort is **"Needs follow-up"**, grouped as Overdue, Today, This week and Later, following Kole Jain's advice to group by a meaningful criterion. A–Z is an alternative sort, with section indexes for both scripts.

Each 72dp row shows a 40dp avatar and the name in body weight 600. A secondary line reads like "Buyer · 3-bed · Bole · ≤ 8M ETB" in textSecondary. A right-aligned tabular column shows the last-contact age ("2d") above a status dot. Dividers are inset to the text edge, so all text shares one left edge and no row is boxed in a card.

Swipe right means **Call**; swipe left means **Remind**. The rule across the whole app is right for the affirmative primary action and left for defer, so swipes work the same everywhere. Each swipe fires `lightImpact` at its threshold. A long press opens a context menu: Call, SMS, Telegram, Add task, Delete. Search is fuzzy across name, phone, area and notes, and should match "Abebe" to "አበበ" (inferred). The empty state pairs an illustration with "Add your first client", "Import from phone contacts" and "Scan a business card", the last borrowed from folk. *(Basis: A; segments, transliteration and Telegram are I.)*

#### Contact record

The header sits on the canvas, not inside a card. It shows a 64dp avatar, the name in titleScreen (Menbere), a tappable **stage chip** beneath it (the HubSpot anatomy) that opens a stage sheet, and one line of need and budget. Below the header is a row of four equal 56dp quick-action tiles on fill, each an icon with a label: **Call, SMS, Telegram, Directions**. Next comes an Airbnb-style **2×2 key-facts grid**: Budget (tabular ETB), Areas, Property type and Next follow-up, which turns danger-coloured when overdue.

Then come Attio-style **swipeable tabs** (Activity, Notes, Tasks, Properties) that pin under the app bar. Activity is a timeline grouped by day. Each entry has an icon for its type, a one-line summary and a right-aligned time, and a persistent filter chip follows HubSpot's pattern. A sticky "Add note" pill with a mic is bound to this contact.

Editing opens a full-height sheet with a forgiving form: only name and phone are required, answering the Salesforce complaint about filling every box. The avatar travels from the list row by `Hero`, or the whole row opens with a container transform. *(Basis: A.)*

#### Notes and dictation

The capture sheet opens full height with a drag handle. A language segmented control (አማርኛ / English) sits above a 72dp mic button at the bottom, with a text field for typed notes. Starting dictation runs the hero moment in Raroque's manner. The mic's background expands into an accentContainer wash on spring.hero, "Listening…" fades in, a simple level meter and a tabular elapsed timer appear, and `lightImpact` fires. Stopping morphs the mic into a checkmark.

Audio is **saved locally before upload**, so a dropped connection never loses a note. A "Transcribing…" state shows skeleton lines, which become static under reduced motion. The transcript lands as an **editable draft** with a contact chip and any suggested follow-up date or tasks shown as chips. These apply **only after the broker confirms**, following Cash App's confirm-before-act rule ([Abduzeedo](https://cms.abduzeedo.com/node/88974)).

Saving fires `successNotification` and gives the flow a designed ending: a summary toast such as "Note saved to Abebe K. · follow-up Thursday", applying Tim Gabe's peak-end rule. Notes read at body 16/24, so Amharic paragraphs stay legible. *(Basis: A; local-first audio and the specific flow are I.)*

#### Tasks

Tasks follow the Things 3 structure. **Overdue** comes first, with its header in danger text only and no red fills. Then **Today**, then **Upcoming**, showing the next seven days individually and later dates grouped by week. Each row has a circular 24dp checkbox ring in borderStrong (3:1) inside a 48dp target. The title is in body, the linked contact and time sit on a second line, and a right-aligned tabular time closes the row.

Checking a task fills the ring with accent, draws the check in 150ms and fires `lightImpact`. The text dims, and after about 600ms the row collapses on spring.standard, with an Undo snackbar. This is optimistic UI in Kole Jain's sense. Swipe right completes a task; swipe left reschedules it through a sheet of quick picks (Tomorrow, Next week, Pick date). A long press enters multi-select. *(Basis: A.)*

#### Calendar

The calendar is agenda-first. A week strip at the top has seven 48dp day cells: the selected day is an accent pill, today is outlined, and days with events carry a dot. Below it, the selected day is an **hour-by-hour itinerary** in Airbnb's manner. Each viewing card shows the address, client, property thumbnail and Directions. A current-time line runs in accent, and past events fade to textTertiary, as Things 3 does with past calendar events. Month view is a secondary toggle.

Showing Ethiopian dates beside Gregorian ones, and offering Ethiopian clock time in Amharic, are inferred needs to verify with brokers. A "next viewing in 32 min" countdown could surface as an ongoing Android notification or a home-screen widget, as the Android analogue of Flighty's Live Activities (inferred). *(Basis: A/I.)*

#### Settings

Settings is a grouped list: r.lg groups on surface over the canvas, with 56dp rows, neutral leading icons, and trailing values in textSecondary. It has no nested cards. The groups are:

- **Profile & agency.**
- **Language & region.** App language (አማርኛ / English, independent of the system), digits (Western by default, per elreq), calendar and clock style.
- **Appearance.** System, Light or Dark, with System as the default; a text-size preview showing a live Amharic and English sample; a high-contrast toggle.
- **Feedback.** Haptics on or off, as the HIG says haptics should be optional, and an in-app "reduce motion" switch that gates custom animations.
- **Data.** Offline and sync status, import contacts, export.
- **About.** Including the OFL font licences.

*(Basis: A/I.)*

### Flutter implementation notes

**Theme architecture.** Build both themes from one function. Use `ColorScheme.fromSeed(seedColor: nileTeal, brightness: b, dynamicSchemeVariant: DynamicSchemeVariant.fidelity)`. `fidelity` keeps the seed's character, whereas `tonalSpot` goes pastel. Then pin the exact tokens through the override parameters, because "the `seedColor` may not wind up as one of the ColorScheme colors" ([Flutter](https://api.flutter.dev/flutter/material/ColorScheme/ColorScheme.fromSeed.html)).

Put SmartBroker's semantic names in a `ThemeExtension<SbTokens>`, with a proper `lerp` so theme switches animate ([Flutter](https://api.flutter.dev/flutter/material/ThemeExtension-class.html)). The extension holds the canvas and surface roles, semantic and container colours, shadows (`BoxShadow.lerpList`), radii, spacing, and motion and haptic tokens. Components read the extension, not raw `ColorScheme` slots, because Material's container roles run in opposite directions in light and dark mode. Card colour maps to `surfaceContainerLowest` in light mode but `surfaceContainerLow` in dark ([Flutter color roles](https://docs.flutter.dev/release/breaking-changes/new-color-scheme-roles)). Turn off every stock elevation tint and shadow, since `surfaceTintColor` is already null by default in current Flutter.

**Fonts and text metrics.** Declare Inter, Menbere and Noto Sans Ethiopic under `fonts:` in pubspec. Skip runtime `google_fonts` fetching, or disable it, and register the OFL texts with `LicenseRegistry` ([google_fonts](https://pub.dev/documentation/google_fonts/latest/)). Set `fontFamilyFallback` on every text style, wrap the app in `DefaultTextHeightBehavior` with even leading, and choose tracking per script. The following sketch is untested:

```dart
const sbEthiopic = 'NotoSansEthiopic';
// Ethiopic blocks: U+1200–U+139F, U+2D80–U+2DDF, U+AB00–U+AB2F (literal range ends below)
final _ethiopicRe = RegExp(r'[ሀ-᎟ⶀ-⷟꬀-꬯]');

TextStyle sbStyle(TextStyle base, String text) =>
    _ethiopicRe.hasMatch(text) ? base.copyWith(letterSpacing: 0) : base;

final textTheme = TextTheme(
  displaySmall: const TextStyle(fontFamily: 'Inter', fontSize: 36, height: 1.1,
      fontWeight: FontWeight.w600, letterSpacing: -0.72,
      fontFeatures: [FontFeature.tabularFigures()]),
  headlineSmall: const TextStyle(fontFamily: 'Menbere', fontSize: 24, height: 1.25,
      fontWeight: FontWeight.w600, letterSpacing: -0.36),
  bodyLarge: const TextStyle(fontFamily: 'Inter', fontSize: 16, height: 1.5),
  // ... remaining roles from the type table
).apply(fontFamilyFallback: const [sbEthiopic]);

// In MaterialApp.builder:
// DefaultTextHeightBehavior(
//   textHeightBehavior: const TextHeightBehavior(
//       leadingDistribution: TextLeadingDistribution.even),
//   child: child!)
```

Use sp for text and dp for padding, and test at Android's 200% non-linear font scale ([Android 14](https://developer.android.com/about/versions/14/features)). Use a fixed-height `StrutStyle` only where rows must not change height.

**Shapes and surfaces.** Use `ShapeDecoration(shape: RoundedSuperellipseBorder(borderRadius: …))` for cards, sheets and buttons ([Flutter](https://api.flutter.dev/flutter/painting/RoundedSuperellipseBorder-class.html)). Use `ClipRSuperellipse` only for images, and never animate a clip ([Flutter performance](https://docs.flutter.dev/perf/best-practices)). Wrap the glass nav in a `BackdropGroup` with `BackdropFilter.grouped` ([Flutter](https://api.flutter.dev/flutter/widgets/BackdropGroup-class.html)). Never animate the blur sigma, and enable the blur only on API 29+, which needs a device-info lookup such as `device_info_plus`; that package was not researched. For sheets, use `showModalBottomSheet(showDragHandle: true, isScrollControlled: true, useSafeArea: true)` ([Flutter](https://api.flutter.dev/flutter/material/showModalBottomSheet.html)), or `smooth_sheets` 1.3.0 where snap detents are needed ([pub.dev](https://pub.dev/documentation/smooth_sheets/latest)). Use `SliverAppBar.large` for collapsing titles ([Flutter](https://api.flutter.dev/flutter/material/SliverAppBar/SliverAppBar.large.html)), `RefreshIndicator.adaptive` for pull-to-refresh ([Flutter](https://api.flutter.dev/flutter/material/RefreshIndicator-class.html)), and `skeletonizer` 3.0.0 with a per-brightness `effectResolver` for skeletons ([pub.dev](https://pub.dev/packages/skeletonizer)).

**Motion.** Set page transitions once in `PageTransitionsTheme`: shared-axis for push and pop, fade-through between tabs, and `OpenContainer` from row to record, all from the `animations` package ([SharedAxisTransition](https://pub-web.flutter-io.cn/documentation/animations/latest/animations/SharedAxisTransition-class.html)). Drive sheets, drags and press release with `SpringSimulation`, passing the gesture velocity through. `flutter_animate` handles staggers, but its docs do not mention reduced motion, so gate it explicitly ([flutter_animate](https://pub.dev/documentation/flutter_animate/latest/)). Use `RepeatingAnimationBuilder` (Flutter 3.41) for simple shimmer ([Flutter 3.41](https://flutter.dev/blog/whats-new-in-flutter-3-41)). The following sketch is untested:

```dart
abstract final class SbSprings {
  static final standard = SpringDescription.withDampingRatio(mass: 1, stiffness: 700, ratio: 0.9);
  static final fast = SpringDescription.withDampingRatio(mass: 1, stiffness: 1400, ratio: 0.9);
  static final hero = SpringDescription.withDurationAndBounce(
      duration: const Duration(milliseconds: 400), bounce: 0.2);
}

bool sbReduceMotion(BuildContext c) =>
    MediaQuery.disableAnimationsOf(c) ||
    WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion ||
    SbPrefs.reduceMotion; // in-app toggle
```

`disableAnimations` reflects Android's "Remove animations" setting, while iOS reduce-motion arrives separately ([Flutter](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html)). `withDurationAndBounce` matches SwiftUI's spring parameters ([Flutter](https://api.flutter.dev/flutter/physics/SpringDescription/SpringDescription.withDurationAndBounce.html)).

**Haptics.** Wrap `HapticFeedback` in a single `SbHaptics` service. The service checks the user toggle, maps success, warning and error to impacts on API below 30 (where the notification calls are silent), and is the only place haptics are called. Verify that the notification methods ship in the project's Flutter version, since they landed in November 2025 ([Flutter commit](https://flutter.googlesource.com/mirrors/flutter/+/c0e052941af58233d0b962e26fcfc03c8fb1124f%5E%21)).

**Performance and platform migration.** Use `const` widgets, `ListView.builder`, fixed-size grid cells, and no `Opacity`, `saveLayer` or clipping inside animations. Hold the frame budget of about 16ms at 60Hz ([Flutter performance](https://docs.flutter.dev/perf/best-practices)). Read from a local database first, and sync in the background with a visible queue. Keep importing `package:flutter/material.dart` on 3.41. Run `dart fix --apply --code=migrate_design_widgets` once when moving to `material_ui` ([pub.dev](https://pub.dev/packages/material_ui)). Revisit official Material 3 Expressive components when they ship there, rather than depending on community M3E packages now. Study the open-source Wonderous app, built by Flutter and gskinner, as the reference for a custom design on Material primitives ([Flutter blog](https://flutter.dev/blog/wonderous-explore-the-world-with-flutter)).

The test matrix should cover:

- an API 28 device and a recent Pixel-class device;
- 200% font scale;
- real Amharic strings, including ። and ፣;
- dark mode;
- "Remove animations";
- TalkBack.

### What is inferred rather than sourced

| Recommendation | Status | Why |
|---|---|---|
| Teal brand seed, every hex value and the chart palette | Inferred | Generated for this report from sourced structure (Kole Jain, Linear); no SmartBroker brand data or Ethiopian colour-perception research |
| Menbere as display, Inter + Noto Sans Ethiopic as text | Inferred pairing of sourced fonts | Licences and coverage are sourced; how they look together with Amharic readers is untested |
| 16sp body, 1.5 line height, 13sp minimum, per-script weight balancing | Inferred | No measured Ethiopic legibility data exists in the sources |
| Shadow values, glass opacity, radius assignments and nesting rule | Adapted | Principles sourced; numbers chosen here |
| Specific haptic-to-event map, including `selectionClick` for tabs | Adapted | HIG and Raroque sourced; they disagree on tab-change weight |
| Nav that never hides; long-press capture to dictate | Inferred | Derived from NN/g's critique, not tested |
| Right = act, left = defer swipe rule | Inferred | Synthesised from Superhuman, Things and Linear, which differ |
| Ethiopian calendar and clock, Telegram quick action, transliteration search, unicase hierarchy | Inferred; outside the research notes | General locale knowledge; verify with brokers |
| Device mix, API-level distribution and blur affordability in Ethiopia | Unknown | No data found |
| Which apps Reddit communities cite as best designed | Unknown | Reddit was blocked for the researchers |

## Conclusion

The research inverts the usual redesign brief. In 2026, the visual vocabulary of polish (glass, gradients, bounce, dark-by-default, even the Linear look) is cheap to generate and therefore no longer signals care. What still signals care is the expensive layer: decisions held consistently across hundreds of components, speed and state that survive bad networks, and craft in the places templates cannot reach. For SmartBroker, the most defensible distinction is not borrowed from Linear or Revolut at all. It is being **genuinely Ethiopic-first**. That means typography designed for fidel, metrics normalised so Amharic rows do not jitter, local date, time and messaging conventions, and dictation that never loses a word. That is exactly the "emotional, unpredictable" territory Malewicz says AI cannot copy.

The platform shift also lowers the risk. Material 3 Expressive and Liquid Glass have converged on a floating labelled pill, a large thumb-reach primary action, emphasized type and calm-by-default springs. SmartBroker can adopt that grammar now through a thin token layer, then map it onto the official `material_ui` components when they arrive, rather than chasing either platform's chrome. The next step is evidence rather than more design. Run five-second preference tests and task timings with Addis brokers on their own phones, comparing the current UI with this token set in Amharic. That would fill the three gaps this report could not: local perception of "premium", Ethiopic legibility minimums, and the real device floor.
