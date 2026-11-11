# Siri AI opens to apps, not keyboards

Apple's 3 November 2026 developer news item announces a **Siri AI Developer Preview**. From the iOS 27.3 betas onward, any app can expose its own actions and content to Siri AI through App Intents ([Apple Developer News](https://developer.apple.com/news/?id=gdk2umrf)). The Preview is **testing only**. It runs on development-signed builds and internal TestFlight testers, it is not available to App Store versions, customers get it "in a few months", and App Store submission opens "in the spring" of 2027 ([Apple Docs](https://developer.apple.com/documentation/appintents/siri-ai-developer-preview.md)). Nothing in the announcement covers keyboard extensions. Intents run in the main app, an App Intents extension or a widget extension ([WWDC26 Session 345](https://nonstrict.eu/wwdcindex/wwdc2026/345/)), so Siri can reach Mancini's companion app but never the keyboard itself. Inside the keyboard, the only Apple AI that might be reachable is **Foundation Models**: the on-device AFM 3 model, from the same model family as Siri AI. That framework ships today and covers Simplified and Traditional Chinese, which Siri AI does not. Nobody has yet confirmed that a keyboard extension can call it. For his app, **Korean Siri AI works in Korea now** (since iOS 27.2). Chinese is split: Traditional is due by end of 2026, and Simplified has no date. **"Write with Siri"** on Apple's own keyboard is the direct competitor, because it proofreads as you type and offers no API for third-party keyboards. The recommended order is a one-day on-device Foundation Models spike in the keyboard, then a Siri-connected study loop in the companion app, then a voice "check this" Siri tool for personal use, held back from the App Store until spring.

## Apple's 3 November item opens custom Siri actions, for testing only

The news item is titled "Announcing Siri AI is now open to all developers". It says the 27.3 betas of iOS, iPadOS, macOS and visionOS add a Developer Preview that "enables any developer to integrate their app with Siri AI" ([Apple Developer News](https://developer.apple.com/news/?id=gdk2umrf)). Apps bring "content and actions directly into Siri AI by using App Intents", which gives them access to **personal context, onscreen awareness and natural language**. The item introduces three new things. **Skills** let Siri combine several actions into one experience. **Spotlight entities** can now be surfaced by Siri AI even when they don't fit an existing schema. **Custom actions**, such as "checking a delivery" or "placing an order", can be carried out by Siri ([Apple Developer News](https://developer.apple.com/news/?id=gdk2umrf)). Before this, Siri AI only understood actions in Apple's system-defined schema domains. The Preview is what extends it to arbitrary custom intents ([Apple Docs](https://developer.apple.com/documentation/appintents/siri-ai-developer-preview.md)).

The linked documentation sets the rules for when Siri calls an app. A request doesn't need to name the app while it is in the foreground, while it has an active Live Activity, or when an ongoing Siri conversation already mentioned it. **Background requests must name the app**. Requests can chain actions across apps ([Apple Docs](https://developer.apple.com/documentation/appintents/siri-ai-developer-preview.md)). The new building blocks are:

| API | What it does |
|---|---|
| `@AppIntent(.tool)` / `ToolIntent` | Makes an intent available to Siri as a tool |
| `GenerableEntity` | Lets Siri's model fill an entity from what the person says |
| `IntentVisibility` with `@ComputedProperty`/`@DeferredProperty` | Controls what Siri can see |
| `CardSnippet` | Branded result cards |
| App skills | Multi-step orchestration |
| Siri Integration Advisor (Xcode) and `SiriEvaluations` | Script and regression-test Siri requests |

Apple also warns that "the App Intents API and Siri functionality may change" during the Preview ([Apple Docs](https://developer.apple.com/documentation/appintents/siri-ai-developer-preview.md)).

The commercial terms are still open. Apple says it will "follow up with more details about the terms and usage policies for experiences enabled through Siri AI". Server-side Apple Intelligence features, Siri AI included, have **daily usage limits**, with "expanded access… for a fee in the future" ([Apple Developer News](https://developer.apple.com/news/?id=gdk2umrf)). Consumer Siri AI is itself still a beta. It launched with iOS 27 on 14 September 2026 as an opt-in, English-only feature behind a waitlist ([9to5Mac](https://9to5mac.com/2026/09/14/ios-27-has-a-waitlist-for-accessing-new-siri-ai/)) and added Korean and four other languages on 26 October ([Apple Newsroom](https://apple.com/newsroom/2026/10/siri-ai-is-available-in-more-languages-starting-today/)). Siri AI needs Apple Intelligence hardware: **iPhone 15 Pro or later** ([Apple Newsroom (UK)](https://www.apple.com/uk/newsroom/2026/06/apple-introduces-siri-ai-a-profoundly-more-capable-and-personal-assistant/)).

## Four Apple surfaces, and only one might reach inside the keyboard

Developers cannot call the model behind Siri AI directly. Press reports describe it as Gemini-derived, but no developer API exposes it ([TheNextWeb](https://thenextweb.com/news/apple-wwdc-2026-siri-ai-gemini-ios-27)). What developers can use falls into four surfaces, and they differ sharply on whether they ship and where they run.

| Surface | What a developer gets | Ships to App Store users today? | Runs inside a keyboard extension? |
|---|---|---|---|
| **Siri AI Developer Preview** (tool intents, skills, `CardSnippet`, custom Spotlight entities) | Siri calls custom actions with parameters filled from natural language | **No**: dev builds and internal TestFlight only, until spring 2027 | **No**: execution targets are the main app, `appIntentsExtension` and `widgetKitExtension` ([Session 345](https://nonstrict.eu/wwdcindex/wwdc2026/345/)) |
| **App Schemas** (Messages `draftMessage`/`sendMessage`, Notes `appendText`, etc.) | Siri AI understands schema-conforming actions out of the box | Yes | No (same execution targets) |
| **App Shortcuts** (`AppShortcutsProvider`) | Fixed phrases trigger intents in Siri, Spotlight and Shortcuts | Yes (pre-iOS 27 API) | No |
| **Foundation Models** (`SystemLanguageModel`, `PrivateCloudComputeLanguageModel`, the `LanguageModel` protocol) | On-device AFM 3, Apple's Private Cloud Compute model, or Claude/Gemini behind one session API, with `@Generable` structured output and tool calling ([Apple Docs](https://developer.apple.com/documentation/foundationmodels.md)) | Yes | **Unconfirmed** (see below) |
| **Writing Tools / Write with Siri** | Nothing: no provider API was found | n/a | n/a |

None of the schema domains fits a correction or learning app. The primary domains are Audio, Calendar, Camera, Clock, Mail, Maps, Messages, Notes, Phone, Photos, Reminders, search and Video. Word processor and Journaling exist only as Shortcuts domains ([App schema domains](https://developer.apple.com/documentation/appintents/app-schema-domains.md)). Actions like "check this sentence", "explain this word" and "add to my study list" are therefore custom tool intents, and those **fall entirely inside the Developer Preview restriction**. App Shortcuts are the one Siri path that ships today, but they match fixed phrases rather than free-form speech.

On-screen awareness doesn't solve the keyboard problem. Each app annotates its *own* views with entity identifiers, and otherwise "Siri… only sees what's in the pixels" ([WWDC26 Session 343](https://nonstrict.eu/wwdcindex/wwdc2026/343/)). A custom keyboard runs in an isolated process and sees the host app's text field only through `textDocumentProxy` ([Creating a custom keyboard](https://developer.apple.com/documentation/uikit/creating-a-custom-keyboard.md)). No API lets the keyboard turn "the sentence I'm typing in KakaoTalk" into an entity Siri can address. Siri AI might read visible text from the screen and pass it as a `String` into the companion app's tool intent, but no Apple document guarantees this. It is the biggest unknown for any voice-driven "check this" feature.

Foundation Models is the only Apple AI that could run inside the keyboard, and even that is open. An Apple DTS engineer said the system model runs out-of-process, so it **doesn't count against an extension's memory limit**. The same engineer added that "some extensions don't allow XPC due to privacy reason, and hence can't use a model via the Foundation Models framework", without saying which extensions. A follow-up question went unanswered ([Apple Developer Forums 833575](https://developer.apple.com/forums/thread/833575)). Three more constraints matter for a correction model:

| Constraint | Detail |
|---|---|
| Fine-tuning | **Adapters (fine-tuning) were dropped in OS 27**: "we're no longer supporting adapters as of OS 27" ([Apple Developer Forums 831314](https://developer.apple.com/forums/thread/831314)) |
| Context window | 4K tokens on device, 32K on PCC ([Apple: PCC](https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute.md)) |
| PCC access | Needs a managed entitlement and network. It is free of cloud API cost for Small Business Program apps under 2 million downloads ([WWDC26 iOS guide](https://developer.apple.com/wwdc26/guides/ios/)), and users have a daily quota (`quotaLimitReached`) |

## Korean works today, Chinese splits by script, EU and mainland China are excluded

Language coverage is where Siri AI and Foundation Models differ most, and it decides which proposal can serve Chinese.

| | Siri AI (incl. Developer Preview) | Foundation Models (on-device / PCC) |
|---|---|---|
| **Korean** | **Yes, since iOS 27.2 (26 Oct 2026)** ([Apple Newsroom](https://apple.com/newsroom/2026/10/siri-ai-is-available-in-more-languages-starting-today/)) | Yes (Apple Intelligence language) |
| **Traditional Chinese** | "By the end of the year" ([Apple Newsroom](https://apple.com/newsroom/2026/10/siri-ai-is-available-in-more-languages-starting-today/)) | Listed as an Apple Intelligence language |
| **Simplified Chinese** | **Not announced, no date** | Listed as an Apple Intelligence language |
| **German** | Not announced | Listed as an Apple Intelligence language |
| **English** | Yes, since 14 Sept 2026 | Yes |
| **Mainland China** | Not available ([Apple Newsroom (UK)](https://www.apple.com/uk/newsroom/2026/06/apple-introduces-siri-ai-a-profoundly-more-capable-and-personal-assistant/)) | New features not available; forum reports `deviceNotEligible` on CH/A hardware ([Forums 855201](https://developer.apple.com/forums/thread/855201)) |
| **EU** | **Unavailable on iOS, iPadOS and watchOS** ([Apple Developer News](https://developer.apple.com/news/?id=gdk2umrf)) | No EU block stated in the sources |
| **Taiwan / Hong Kong** | Not specified | Not specified |

The on-device model is "multilingual" across all Apple Intelligence languages. Apple recommends opening the instructions with "The person's locale is \(locale.identifier)." and naming the output language explicitly ([Apple: Supporting languages](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models.md)). Apple publishes no Korean or Chinese quality scores. Its AFM 3 evaluation groups Chinese and Korean together with six other languages ([Apple ML Research](https://machinelearning.apple.com/research/introducing-third-generation-of-apple-foundation-models)). Two practical points follow. A keyboard must check the *typed* language against `supportedLanguages` rather than `supportsLocale()`, because the latter uses the app's locale. And no source says how Siri AI behaves with mixed-language requests, such as Siri set to Korean while the content is Chinese.

For Mancini personally, being in Korea with Korean Siri AI means the Developer Preview is testable now on an iOS 27.3 beta device. For a public release, every Siri proposal leaves out Simplified Chinese users, EU iPhone users and mainland China, and Traditional Chinese depends on a launch that hasn't happened yet. Foundation Models is the only surface that serves his Chinese users on day one.

## Write with Siri is the competitor built into Apple's keyboard

Starting with iOS 27 Beta 2, "Write with Siri" replaced the Writing Tools button on the system keyboard. It offers generation, feedback, **proofread-as-you-type** and edit-on-request in any app using the standard keyboard, on iPhone 15 Pro or later ([iThinkDiff](https://www.ithinkdiff.com/ios-27-beta-2-write-with-siri-keyboard-2/)). That is a free, built-in version of the keyboard's core "check after a pause" feature. Three facts limit how strong a competitor it is, and none is fully confirmed. First, no public API lets a third-party app plug its own proofreader into it. Second, the feature lives in Apple's keyboard UI, so users of a custom keyboard probably lose the bar. Third, the sources don't say whether it supports Korean or Chinese. The rumoured Siri "Extensions" that would let users choose Claude or Gemini for Writing Tools are unannounced and switched off on Apple's servers ([The Next Web](https://thenextweb.com/news/apple-siri-extensions-third-party-ai-missing-wwdc)).

The app's defensible ground is therefore not generic proofreading. It is everything Write with Siri doesn't model: **speech level against a specific listener** (반말/해요체/합쇼체, age, relationship), **mainland versus Taiwan vocabulary and script**, a one-line *teaching* tip rather than a silent fix, and a study list that feeds Anki. Each proposal below is judged on whether it widens that gap or competes head-on.

## Three ways to bring Siri AI into the keyboard

The proposals use different surfaces and make different trade-offs. Effort estimates assume AI-assisted building with the existing Worker proxy, App Group and keyboard already in place. They are judgement calls, not sourced figures.

### Proposal 1: "Siri, check this": a voice tool in the companion app

**Experience.** Mancini is in KakaoTalk with a draft to a friend: "어제 친구랑 영화를 봤어서 늦게 잤어요". He holds the side button and says "[app name]으로 이거 자연스러운지 봐줘". Siri reads the visible draft, calls the app's `CheckSentence` tool with `text`, `language: .korean` and `register: .haeyo` (taken from his saved profile when he doesn't say it), and shows a branded card: **"봤어서 → 봐서"** with the tip "-아/어서 doesn't take past tense 았/었". The spoken response gives the full line. He can follow up with "send it to 지민" and Siri hands the corrected string to Messages, or "save 봐서 to my study list" to log the mistake. This could replace his current Action-button screenshot flow, which is too slow.

| | |
|---|---|
| **APIs** | `@AppIntent(.tool)` `CheckSentence` with `@Parameter` text plus `AppEnum`s for language and speech level; returns `ProvidesDialog` + `CardSnippet`/`ShowsSnippetView` + a `Transferable` correction entity for chaining ([Bringing custom actions to Siri](https://developer.apple.com/documentation/appintents/bringing-custom-actions-and-content-to-siri.md); [Session 343](https://nonstrict.eu/wwdcindex/wwdc2026/343/)). Runs in an App Intents extension via `ExecutionTargets` and calls the Cloudflare Worker within the **30-second intent limit** ([Session 345](https://nonstrict.eu/wwdcindex/wwdc2026/345/)). An App Shortcuts phrase version ships as a fallback. |
| **Depends on** | Developer Preview: iOS 27.3 beta, dev-signed or internal TestFlight builds only. Korean Siri AI (available). Traditional Chinese only after its end-of-year launch; Simplified Chinese not at all. No EU iPhones. iPhone 15 Pro or later. Siri AI daily limits. Unpublished Siri AI usage terms. App Review 5.1.2(i) disclosure and consent for sending text to third-party AI ([TechCrunch](https://techcrunch.com/2025/11/13/apples-new-app-review-guidelines-clamp-down-on-apps-sharing-personal-data-with-third-party-ai)). |
| **Effort** | Medium: about 3 to 5 days for the intent, extension, snippet and a `SiriEvaluations` test script, plus beta setup on device. |
| **Risks to test on device** | Does Siri pull text out of KakaoTalk into the `String` parameter at all? Does Siri route "is this natural?" to the app's tool, or just answer with its own model? Is the speech-level parameter filled reliably from Korean speech? How does Siri voice a Korean dialog string? Latency of Siri plus the Worker round trip. Stability of running a developer beta on his only phone. |
| **When** | **Personal use: now**, if he runs the 27.3 beta. Internal TestFlight suits building away from the Mac. **App Store: spring 2027 at the earliest**, Korean-first, Chinese later. |
| **Versus Write with Siri** | Partly competes, because Siri AI can already judge Korean on screen without the app. The value it adds is the profile (listener, speech level), the consistent tip format and saving to the study list. This is the thinnest differentiation of the three. |

### Proposal 2: Siri AI's on-device model inside the keyboard

**Experience.** Typing to a senior with the Korean profile set to 해요체, he writes "선배, 내일 시간 있어?" and pauses. Within about a second, before any network call, the suggestion bar shows a stiff/mismatch flag: **"반말 to a senior → 선배, 내일 시간 있으세요?"** Tapping it asks the Worker (Claude) for the full one-line tip, and that call happens only when the on-device pass flags something or he asks for "More natural". In Chinese, with the Taiwan/Traditional profile, "我們打的去吧" gets an instant flag: **"打的 is mainland usage → 我們搭計程車去吧"**. A clean sentence gets a tick with no network call, so ticks feel instant and Worker costs drop. Without Full Access, the keyboard could offer an on-device-only mode as the privacy option.

| | |
|---|---|
| **APIs** | `SystemLanguageModel.default` with an availability check, `supportedLanguages` against the active input language, and a `@Generable struct CheckResult { verdict, corrected, tip }` for guaranteed structured output ([Apple Docs](https://developer.apple.com/documentation/foundationmodels.md); [SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel.md)). The profile goes into short instructions with Apple's locale phrase. Optional: `PrivateCloudComputeLanguageModel` as a free deeper tier in place of Haiku once the app ships, if eligible. |
| **Depends on** | **Whether keyboard extensions may reach the model over XPC (unconfirmed)**. Apple Intelligence device (iPhone 15 Pro or later). Korean and both Chinese scripts are Apple Intelligence languages, so Chinese is covered where Siri AI isn't. Not in mainland China. No fine-tuning, because adapters were removed. 4K context, so instructions must stay short. PCC needs network, and whether a keyboard can call PCC without Full Access is unknown. |
| **Effort** | Small to start: a **one-day spike** that logs `availability` and errors inside the keyboard, with and without Full Access. Then about 1 to 2 weeks for hybrid routing (on-device first pass, Worker escalation) and an evaluation set of roughly 100 real Korean and Chinese sentences. |
| **Risks to test on device** | XPC blocked in keyboards. Quality of a ~3B model on Korean speech levels, particles and spacing, and on mainland versus Taiwan wording, which nobody has benchmarked publicly. Latency of the first token after a pause. Guardrail false positives on slang and casual text. Context size (Apple says 4K; one secondary source says 8,192). |
| **When** | **Personal use: as soon as the spike passes.** **App Store: now**, because Foundation Models is a shipping API rather than a preview. This is the only proposal that is not blocked until spring. |
| **Versus Write with Siri** | Competes head-on on "check as I type", but with the same on-device model family, offline, and inside his own keyboard where Apple's bar probably doesn't appear. It wins on profiles and Chinese variants. Strictly speaking it is not "Siri AI" but the same AFM 3 model family made available to developers. |

### Proposal 3: A Siri-aware study loop in the companion app

**Experience.** Words he long-presses and saves in the keyboard's learning mode land in the App Group as study items, each with its source sentence, the correction tip and the profile it came from. That evening he asks "Siri, 이번 주에 저장한 표현으로 퀴즈 내줘". An app skill fetches this week's items and starts a five-minute quiz as a **Live Activity**, so follow-up answers don't need the app's name. Siri asks "'눈치 보다'를 써서 문장 만들어 보세요". His spoken answer goes to the `CheckSentence` tool from Proposal 1 and is graded. Later he can ask "그 '어색하다' 예문 뭐였지?" and Siri finds the item through the Spotlight semantic index, or say "export this week's words to Anki" to queue the CSV export. Chinese items work the same way for retrieval even though Siri itself speaks Korean or English.

| | |
|---|---|
| **APIs** | `StudyItem` as an `AppEntity`/`IndexedEntity` in Spotlight. Tool intents `QuizMe`, `FindSaved`, `ExportToAnki`. App skills for the quiz flow. Live Activity for foreground-free follow-ups ([Apple Docs](https://developer.apple.com/documentation/appintents/siri-ai-developer-preview.md)). `.appEntityIdentifier` on the companion app's study list, so "save this one" works on screen ([Session 343](https://nonstrict.eu/wwdcindex/wwdc2026/343/)). `RelevantEntities` to surface due items ([Session 345](https://nonstrict.eu/wwdcindex/wwdc2026/345/)). `authenticationPolicy`/`IntentVisibility` to keep source sentences, which come from private chats, out of reach. |
| **Depends on** | Developer Preview for free-form Siri use of custom entities, tools and skills. The shippable subset today is App Shortcuts phrases (e.g. "[app] 퀴즈 시작") plus ordinary Spotlight search. Korean Siri AI is available. Chinese content inside a Korean or English Siri conversation is untested. EU and mainland China excluded for Siri AI. |
| **Effort** | Medium to high: about 1.5 to 2 weeks for entities, indexing, intents, skill, Live Activity and evaluations. It reuses the study list and Anki export he needs anyway. |
| **Risks to test on device** | Pronunciation and recognition of Korean answers inside Siri. How app skills behave (the "Orchestrating complex actions with app skills" page wasn't read). Whether Siri finds non-schema `StudyItem`s reliably. Siri AI daily limits during long quizzes. Privacy of chat-derived example sentences. |
| **When** | **Personal use: now** on the 27.3 beta. **App Store: shortcut-and-Spotlight subset now, full Siri version spring 2027.** |
| **Versus Write with Siri** | **Doesn't compete.** Apple has no learning loop, speech-level history or Anki path. This is where the app is most differentiated, and Siri makes the loop usable hands-free. |

### Side-by-side

| | 1. Voice "check this" | 2. On-device model in keyboard | 3. Siri study loop |
|---|---|---|---|
| Surface | Siri → companion app tool | Keyboard extension | Siri → companion app entities/skills |
| Shippable on App Store today | No (App Shortcuts fallback only) | **Yes** | Partly |
| Chinese support | Traditional later, Simplified none | **Both scripts** | Retrieval yes, Siri dialog untested |
| Biggest unknown | Siri reading third-party screen text | XPC from a keyboard | Skills and mixed-language Siri |
| Effort | Medium | Small spike, then medium | Medium to high |
| Gap over Write with Siri | Thin | Moderate | **Wide** |

## Recommendation: test on-device first, build the study loop, hold voice until spring

**Start with Proposal 2's one-day spike.** It is the only option that ships to the App Store now, covers Chinese, makes the most common outcome (a tick) instant and free, and answers its central question with a single device test. If the keyboard can't reach `SystemLanguageModel`, drop on-device and keep the Worker path. Nothing else in the plan depends on it. **Build Proposal 3 next.** It turns the study list he is already building into the part of the app Apple can't copy, and its App Shortcuts and Spotlight subset can ship before spring. **Run Proposal 1 as a personal-use experiment only**, once he is comfortable putting the 27.3 beta on his phone. It might replace the slow screenshot workflow, but it competes with Siri's own abilities, and it can't reach App Store users before spring 2027 or Simplified Chinese users at all. Its `CheckSentence` intent can be reused as the grader in Proposal 3, so building it isn't wasted.

The questions below should be settled before committing build time:

| # | Open question | How to resolve |
|---|---|---|
| 1 | Can a keyboard extension call `SystemLanguageModel` (and PCC), with and without Full Access? | One-day spike on device; log `availability` and any thrown errors |
| 2 | Is the on-device model good enough on Korean speech levels and mainland versus Taiwan Chinese to act as a first pass? | ~100-sentence evaluation set, scored against Claude's output |
| 3 | Does Siri AI extract text from a KakaoTalk draft into a tool intent's `String` parameter? | Proposal 1 prototype on iOS 27.3 beta |
| 4 | Does Write with Siri support Korean and Chinese, and does it disappear when a custom keyboard is active? | Check on device in both languages |
| 5 | Is he willing to run the iOS 27.3 developer beta on his only iPhone? | His call; affects Proposals 1 and 3 timing |
| 6 | What will Apple's Siri AI terms, usage policies and fees require? | Watch for Apple's promised follow-up before spring |
| 7 | When will Traditional Chinese Siri AI launch, does it cover Taiwan, and will Simplified Chinese ever be added? | Apple Newsroom and feature-availability page |
| 8 | Does the app qualify for free PCC (Small Business Program, under 2M downloads) as a replacement for paid Haiku calls? | Apply for the managed entitlement before public launch |

## Conclusion

The 3 November announcement is aimed at apps, not input methods. Siri AI can call into the companion app, but it cannot sit inside the keyboard, and Apple's own keyboard now has a free proofreader built in. So the question isn't how to put Siri into the keyboard. It is which parts of the product Siri should serve, and which parts must stay in the keyboard to be better than Write with Siri. On that split, the keyboard keeps the instant, profile-aware check (on-device where Apple permits it), and Siri gets the hands-free learning loop around it.

There is also a timing advantage. The App Store will be closed to custom Siri tools until spring 2027, and Chinese Siri coverage is incomplete. Foundation Models and a solid study list can ship before then. When the Preview opens, the app would already have the profiles, history and study items that make its Siri tools worth more than Siri alone.
