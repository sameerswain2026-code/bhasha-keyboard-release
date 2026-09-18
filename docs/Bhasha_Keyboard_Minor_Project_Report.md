# Bhasha Keyboard
## A Multilingual Android Input Method Editor for Indian Languages

### Minor Project Report

Submitted in partial fulfilment of the requirements for the award of the degree of

**Bachelor of Technology (B.Tech.)**

**Seventh Semester — Minor Project**

---

### Submitted by

**Student Name:** `[Your Full Name]`
**Roll Number:** `[Your Roll Number]`
**Enrollment Number:** `[Your Enrollment Number]`

### Under the Guidance of

**Project Mentor:** `[Mentor Name and Designation]`

### Department of `[Department Name]`
### `[College/Institute Name]`
### `[University Name]`

**Academic Session:** `[20XX–20XX]`
**Date of Submission:** `[DD Month YYYY]`

---

## Certificate

This is to certify that the Minor Project Report entitled **“Bhasha Keyboard: A Multilingual Android Input Method Editor for Indian Languages”** has been carried out by **`[Student Name]`**, Roll Number **`[Roll Number]`**, student of the Department of **`[Department Name]`**, **`[College/Institute Name]`**, under my supervision and guidance during the seventh semester of the Bachelor of Technology programme.

To the best of my knowledge, the work presented in this report is original and has been completed in accordance with the academic requirements prescribed by the institute.

|  |  |
|---|---|
| **Project Mentor** | **Head of Department** |
| Signature: ____________________ | Signature: ____________________ |
| Name: `[Mentor Name]` | Name: `[HOD Name]` |
| Date: `[Date]` | Date: `[Date]` |

<br>

**Principal/Director Approval:** __________________________________________
**Date:** `[Date]`
**Institution Seal:**

---

## Declaration

I, **`[Your Full Name]`**, declare that this Minor Project Report entitled **“Bhasha Keyboard: A Multilingual Android Input Method Editor for Indian Languages”** is my original academic work, completed under the guidance of **`[Mentor Name]`**. The implementation, testing observations, diagrams, and explanations presented in this report have been prepared for academic evaluation.

Wherever the work of other authors, organizations, frameworks, or service providers has been used, it has been acknowledged through references. Provider credentials used during private testing are not included in this report or in any publicly distributed source artifact.

**Student Signature:** ____________________
**Name:** `[Your Full Name]`
**Date:** `[Date]`

---

## Acknowledgement

I express my sincere gratitude to **`[Mentor Name]`**, Project Mentor, for providing guidance, technical direction, and continuous feedback throughout this project. I also thank the Head of the Department and the faculty members of **`[Department Name]`** for their support and for providing the academic environment required to complete this work.

I am grateful to **`[College/Institute Name]`** for providing the facilities and resources necessary for development and testing. I also acknowledge the open-source communities behind Flutter, Android, Kotlin, and the supporting software libraries used in this project.

Finally, I thank my classmates, friends, and family members for their encouragement and for helping with informal usability feedback during testing.

---

## Abstract

Bhasha Keyboard is a Flutter-based Android Input Method Editor (IME) designed to improve multilingual typing for Indian-language users. The project provides a single system keyboard with native-script layouts, Roman transliteration, language-aware suggestions, cursor-aware editing, voice typing, emoji and sticker support, clipboard utilities, themes, and optional artificial-intelligence-assisted features.

The keyboard is implemented as a hybrid system. The Android layer provides the `InputMethodService`, manages the connection with the active text editor, and exposes the IME lifecycle to the Flutter user interface. The Flutter layer manages keyboard layout rendering, application state, text-buffer operations, suggestions, language configuration, and optional network services. Voice typing uses a streaming speech provider abstraction, with Sarvam AI as the Android provider in the current implementation. Optional Gemini and Tavily integrations are isolated behind service classes and are configured at build time rather than committed to source control.

A major engineering focus of the project is reliable synchronization between the keyboard's local text model and the host application's text field. The implementation uses selection-aware updates and exact changed-range replacement so that insertion, deletion, and replacement in the middle of existing text do not cause caret jumps or duplicated input. The project also includes automated formatting, static analysis, unit tests, widget tests, Android build verification, and a GitHub Actions CI/CD pipeline.

**Keywords:** Android IME, multilingual keyboard, Indian languages, Flutter, transliteration, voice typing, text synchronization, mobile application, CI/CD.

---

## Table of Contents

1. Introduction
2. Problem Statement and Motivation
3. Aim, Objectives, and Scope
4. Existing System and Proposed System
5. Requirements Analysis
6. System Design and Architecture
7. Detailed Module Design
8. Implementation
9. Text Synchronization and Caret Management
10. Voice Typing and AI-Assisted Features
11. Testing and Validation
12. Security, Privacy, and Ethical Considerations
13. Results and Discussion
14. Limitations
15. Future Scope
16. Project Management and Development Workflow
17. Conclusion
18. References

---

# 1. Introduction

## 1.1 Background

A keyboard is a direct interface between a user and a computing system. For multilingual users, the quality of this interface depends on more than the availability of alphabetic keys. It must support appropriate scripts, language switching, transliteration, suggestions, cursor movement, correction, voice input, and compatibility with different Android text editors.

India has a linguistically diverse user base. Users may communicate in English, Hindi, Bengali, Tamil, Telugu, Marathi, Gujarati, Kannada, Malayalam, Punjabi, Urdu, Odia, Assamese, Nepali, and other languages within the same device and sometimes within the same conversation. A keyboard designed around only one script or one language can make this interaction slower and less accessible.

Bhasha Keyboard addresses this problem by providing a unified Android IME. The user can enable the keyboard at the operating-system level and use it across compatible applications. The project combines local keyboard operations with optional cloud-assisted capabilities while keeping the core typing path independent of network availability.

## 1.2 Project Context

This work is submitted as a **B.Tech. seventh-semester Minor Project**. It demonstrates the application of mobile software engineering, user-interface design, Android service integration, asynchronous programming, text processing, API integration, software testing, and CI/CD practices in one practical system.

## 1.3 Report Organization

This report first defines the problem and project objectives. It then explains the requirements, architecture, modules, implementation details, text synchronization strategy, testing process, security approach, limitations, and future improvements. The final sections summarize the outcome and list the technical references used.

---

# 2. Problem Statement and Motivation

## 2.1 Problem Statement

Many multilingual users require a keyboard that can support Indian scripts, Roman input, voice typing, suggestions, and system-wide text entry without repeatedly switching between unrelated applications or keyboard tools. Existing solutions may provide only a subset of these functions, may not provide consistent cursor-aware editing, or may not expose a unified interface for language and input-mode management.

The problem addressed by this project is:

> **To design and implement a reliable, extensible Android multilingual keyboard that supports Indian-language typing, transliteration, voice input, and productivity features while maintaining correct text and caret synchronization with host applications.**

## 2.2 Motivation

The project is motivated by four practical requirements. First, users need access to multiple Indian languages from one keyboard. Second, typing assistance should remain useful when users alternate between native scripts and Roman input. Third, voice typing should reduce the effort required for longer messages. Fourth, an Android IME must behave correctly inside external applications, where the keyboard does not own the host editor's complete lifecycle.

The caret synchronization problem is especially important. A keyboard that inserts characters correctly only at the end of a text field is not reliable for editing. Users routinely place the cursor in the middle of a sentence, select a word, delete text, or replace a selected range. Therefore, the project treats selection-aware editing as a core engineering requirement rather than a visual enhancement.

---

# 3. Aim, Objectives, and Scope

## 3.1 Aim

The aim of this project is to develop a production-oriented prototype of a multilingual Android keyboard that provides accessible Indian-language input and reliable interaction with Android text editors.

## 3.2 Objectives

| Objective | Description |
|---|---|
| Multilingual input | Provide language packs and layouts for Indian languages. |
| Script flexibility | Support native-script and Roman/transliteration input modes where applicable. |
| System integration | Implement the keyboard as an Android `InputMethodService`. |
| Reliable editing | Support insertion, deletion, selection replacement, and editor actions. |
| Voice typing | Provide a provider-independent voice engine with streaming-result handling. |
| Productivity | Include suggestions, clipboard history, emoji, stickers, GIF access, themes, and text-editing tools. |
| Maintainability | Separate UI, controller, data, IME bridge, and provider services. |
| Quality assurance | Automate formatting, analysis, tests, and Android build checks. |
| Security awareness | Keep provider credentials outside source control and document the residual risk of client-side keys. |

## 3.3 Scope

The current scope includes an Android application and keyboard service, Flutter user interface, multilingual layouts, transliteration support, voice typing integration, optional AI-assisted features, local preferences, and automated validation. The application targets Android devices running Android 6.0/API 23 or later, subject to the minimum SDK selected by the Flutter and Android build configuration.

The project does not attempt to build a new speech-recognition model, a new large language model, or a new Android operating system. Cloud services are consumed through provider abstractions. The project also does not claim that embedded API credentials are suitable for a public consumer release; a secure backend proxy is the appropriate future architecture for that scenario.

---

# 4. Existing System and Proposed System

## 4.1 Existing System

A typical user may combine the default Android keyboard, a separate transliteration application, a voice assistant, and clipboard or emoji utilities. This creates several limitations:

1. Language switching may require repeated navigation through system settings.
2. Native-script and Roman input may not be available in one consistent layout.
3. Voice input may not share the same language configuration as keyboard typing.
4. Editing behavior may vary between tools.
5. Users may need to install several applications with unrelated interfaces.

## 4.2 Proposed System

Bhasha Keyboard consolidates these functions into one Android IME. The system provides a toolbar, keyboard layers, language configuration, text editing, voice controls, and productivity panels. Core local typing remains available independently of network services. Optional providers are accessed through dedicated service classes and can fail over or degrade without preventing the keyboard from starting.

## 4.3 Comparative Summary

| Feature | Conventional fragmented workflow | Bhasha Keyboard |
|---|---|---|
| Indian-language layouts | May require separate keyboard or language configuration | Centralized language registry and layouts |
| Roman/native switching | Often inconsistent across tools | Integrated script-mode control |
| Voice typing | Separate or application-dependent | Integrated voice engine and mic workflow |
| Middle-text editing | Depends on host integration quality | Exact range replacement and selection-aware updates |
| Clipboard and emoji tools | Separate applications or panels | Included in the keyboard interface |
| Testing workflow | Often manual | Automated analysis, tests, and Android build checks |
| Provider configuration | May be embedded or unmanaged | Build-time configuration with documented security limitations |

---

# 5. Requirements Analysis

## 5.1 Functional Requirements

| ID | Requirement |
|---|---|
| FR-01 | The system shall display an Android keyboard interface when selected as the active IME. |
| FR-02 | The system shall allow users to select among supported language packs. |
| FR-03 | The system shall provide alphabetic, numeric, and symbol keyboard layers. |
| FR-04 | The system shall support native-script and Roman input modes where configured. |
| FR-05 | The system shall insert text at the active selection and not only at the end of the buffer. |
| FR-06 | The system shall support backspace, continuous delete, swipe delete, and editor actions. |
| FR-07 | The system shall provide suggestions based on the current language and composing text. |
| FR-08 | The system shall start, stop, and display the state of voice typing. |
| FR-09 | The system shall handle partial and final voice results without duplicate insertion. |
| FR-10 | The system shall provide optional clipboard, emoji, sticker, GIF, theme, and settings panels. |
| FR-11 | The system shall persist user preferences such as language, theme, and input mode. |
| FR-12 | The system shall operate with disabled optional credentials without crashing at startup. |

## 5.2 Non-Functional Requirements

| Category | Requirement |
|---|---|
| Usability | Common typing actions should be available with minimal navigation. |
| Reliability | Host-editor selection changes must not corrupt the local text model. |
| Performance | Key interactions should not wait unnecessarily for network operations. |
| Maintainability | Features should be isolated into modules with testable interfaces. |
| Security | Secrets must not be committed to the public repository. |
| Compatibility | The Android host should use standard IME and `InputConnection` APIs. |
| Testability | Core behavior should be covered by deterministic tests. |
| Portability | The Flutter layer should remain separable from Android-specific code. |

## 5.3 Hardware and Software Requirements

| Requirement | Specification |
|---|---|
| Development OS | Linux, macOS, or Windows with Flutter and Android tooling |
| Framework | Flutter 3.35.x-compatible toolchain |
| Language | Dart and Kotlin |
| Java | Java 17 for Android builds |
| Android target | Android 6.0/API 23 or newer, subject to project configuration |
| Network | Required only for cloud voice and optional AI services |
| Testing device | Android phone or emulator with microphone permission for voice testing |

---

# 6. System Design and Architecture

## 6.1 Architectural Overview

Bhasha Keyboard follows a layered architecture. The Android layer owns operating-system integration. The Flutter layer owns presentation and application state. The service layer isolates network providers. The data layer defines languages, layouts, emoji, and sticker content.

```text
+-------------------------------------------------------------+
|                    Android Host Application                 |
|  MainActivity | InputMethodService | Android Mic Source    |
+------------------------------+------------------------------+
                               |
                         Method Channels
                               |
+------------------------------v------------------------------+
|                       Flutter Application                  |
|                                                             |
|  KeyboardView  <-->  KeyboardController  <-->  ImeBridge   |
|       |                    |                  |             |
|       |                    |                  +--> Selection|
|       |                    +--> Suggestions / Transliterator|
|       |                    +--> VoiceEngine                 |
|       |                    +--> Preferences                 |
|       |                    +--> AI Assistant                 |
+-------+--------------------+--------------------------------+
        |                    |
+-------v--------+   +-------v--------------------------------+
| Local Data     |   | Optional Provider Services              |
| Languages      |   | Sarvam STT | Gemini | Tavily           |
| Layouts        |   +----------------------------------------+
| Emoji/Stickers |
+----------------+
```

## 6.2 Major Components

| Component | Responsibility |
|---|---|
| `BhashaImeService` | Android IME lifecycle, `InputConnection`, selection updates, and host text replacement. |
| `MainActivity` | Android application entry point and Flutter host activity. |
| `KeyboardView` | Renders toolbar, keyboard rows, panels, mic controls, and dynamic states. |
| `KeyboardController` | Central state management, text editing, language state, preferences, and feature coordination. |
| `ImeBridge` | Communicates Flutter text changes and selection information to the Android IME layer. |
| `VoiceEngine` | Manages voice lifecycle, partial/final results, cancellation, and silence timeout. |
| `SarvamSpeechProvider` | Streams microphone audio and receives speech transcripts. |
| `SuggestionEngine` | Produces language-aware suggestions and maintains learned terms. |
| `Transliterator` | Converts Roman input or source text into the configured target script where supported. |
| `GeminiService` | Optional AI routing and response generation. |
| `TavilySearchService` | Optional web-search retrieval for AI-assisted queries. |

## 6.3 State Management

The `KeyboardController` is the primary state holder. It maintains the selected language, script mode, keyboard layer, shift state, active panel, editor value, voice status, theme, clipboard history, and persisted settings. Flutter widgets observe the controller and rebuild when state changes.

The voice subsystem uses a finite lifecycle represented by the states `idle`, `initializing`, `listening`, `stopping`, and `error`. This explicit state model prevents ambiguous mic behavior and makes the UI state testable.

---

# 7. Detailed Module Design

## 7.1 Language and Layout Module

The language registry stores language identifiers, display names, script families, locale information, native support, Roman support, and provider language codes. Layout data is selected from the current language and script mode. The keyboard can therefore render a Latin QWERTY layout or an Indic layout without changing the overall view structure.

## 7.2 Keyboard UI Module

The keyboard view is divided into a toolbar, dynamic status/suggestions area, keyboard rows, and feature panels. The toolbar provides access to the menu, clipboard, translation configuration, settings, mic mode, and voice control. Keyboard rows support alpha, numeric, and symbol layers. The UI also contains one-handed and floating presentation modes within the keyboard surface.

## 7.3 Text Editing Module

Text editing operations are selection-aware. Insertion replaces the active selection, while deletion operates relative to the current caret or selection. Editor actions such as send, search, done, next, and newline are forwarded through the Android input connection.

The controller maintains a local `TextEditingValue`, including the text and selection. The Android bridge receives host selection updates and communicates changed text ranges back to the native service.

## 7.4 Suggestions and Transliteration

When alphabetic input is entered, the controller updates the composing word and requests suggestions. Separators commit the composing region before insertion. The transliteration module can convert Roman input into native script for supported language packs. Learned words are stored in local preferences to improve future suggestions.

## 7.5 Productivity Panels

Productivity panels include clipboard history, emoji, stickers, GIF search, text editing, language selection, themes, resizing, and translation configuration. These panels are implemented as Flutter widgets and are coordinated through the same controller state.

## 7.6 Persistence Module

User settings are stored using `SharedPreferences`. The implementation includes a pending-write queue so that user actions occurring before asynchronous preference initialization are not silently lost. Persisted settings include the active language, script mode, voice mode, theme, clipboard history, learned suggestions, and selected feature preferences.

---

# 8. Implementation

## 8.1 Technology Stack

| Layer | Technology |
|---|---|
| Mobile UI | Flutter and Material widgets |
| Application language | Dart |
| Android integration | Kotlin and Android SDK |
| IME implementation | Android `InputMethodService` |
| State management | Flutter `ChangeNotifier` with Provider |
| Local persistence | `shared_preferences` |
| HTTP and WebSocket communication | Dart networking libraries |
| Voice provider | Sarvam AI streaming speech provider abstraction |
| Optional AI provider | Gemini API service |
| Optional search provider | Tavily Search API service |
| Testing | Flutter test framework and widget tests |
| Automation | GitHub Actions CI/CD |

## 8.2 Android IME Integration

An Android keyboard is not an ordinary text field. It runs as an input method service and communicates with the currently focused editor through an `InputConnection`. The service observes editor information and selection changes, then exposes the relevant state to Flutter through a method-channel bridge.

When a user taps a key, the Flutter controller updates its local editor value. The bridge computes the changed range and sends a replacement request to the native service. The native service selects exactly that range in the host editor and commits the replacement text.

## 8.3 Key Interaction Flow

```text
User taps key
      |
      v
KeyboardView callback
      |
      v
KeyboardController updates local TextEditingValue
      |
      v
ImeBridge calculates changed prefix and suffix
      |
      v
Native replaceRange(start, end, text)
      |
      v
InputConnection.setSelection(start, end)
      |
      v
InputConnection.commitText(text, 1)
      |
      v
Host application receives exact edit
```

## 8.4 Voice Typing Flow

```text
User taps microphone
      |
      v
VoiceEngine initializes provider and enters LISTENING
      |
      v
Sarvam provider streams microphone audio
      |
      v
Partial transcript updates status display
      |
      v
Final transcript -> KeyboardController -> editor insertion
      |
      v
Manual stop, key interaction, or silence timeout ends session
```

A key interaction during voice typing uses an immediate cancellation path. The latest partial transcript is committed synchronously before the key is inserted, while provider shutdown continues asynchronously. This avoids blocking a key tap on a network flush window and prevents late voice callbacks from inserting text at a stale caret position.

## 8.5 Build-Time Provider Configuration

Provider credentials are supplied through Dart compile-time defines. The source repository contains no live credentials. A private testing build may use commands similar to the following:

```bash
flutter build apk --release \
  --dart-define="SARVAM_API_KEYS=key1,key2" \
  --dart-define="GEMINI_API_KEYS=key1" \
  --dart-define="TAVILY_API_KEYS=key1,key2"
```

The final academic report intentionally does not include real provider keys. A client APK containing compile-time keys must be treated as a private testing artifact because reverse engineering can expose embedded credentials.

---

# 9. Text Synchronization and Caret Management

## 9.1 Problem Observed

During early testing, appending text at the end of a buffer worked, but editing in the middle could move the caret unexpectedly and duplicate input. The underlying issue was an overly broad diff operation. It deleted the complete old tail after the common prefix and then inserted the complete new tail. This assumption is invalid when the host caret is not at the end of the text.

## 9.2 Corrected Algorithm

The corrected algorithm computes both:

1. The longest common prefix between the previous synchronized text and the new local text.
2. The longest common suffix after excluding the prefix.

The changed range is then:

```text
old changed range = [prefix, oldText.length - suffix)
new replacement   = newText[prefix, newText.length - suffix)
```

Only this range is replaced in the host editor. Unchanged text before and after the range is not deleted or replayed.

## 9.3 Native Replacement

The Android service receives `replaceRange(start, end, text)`. It performs the following sequence inside a batch edit:

1. Mark the update as self-initiated.
2. Select the exact `[start, end)` range using `InputConnection.setSelection`.
3. Replace the selected range with `InputConnection.commitText(text, 1)`.
4. End the batch edit.
5. Ignore the corresponding self-generated selection callback when appropriate.

This approach is valid for insertion, deletion, and replacement. It also supports replacing a selected word or sentence without relying on an unbounded `deleteSurroundingText` count.

## 9.4 Synchronization Invariants

| Invariant | Purpose |
|---|---|
| Local selection is always clamped to local text length | Prevent invalid range operations. |
| Host replacement range is exact | Prevent deletion of unrelated text. |
| Self-initiated callbacks are guarded | Prevent feedback loops and duplicate events. |
| Queued edits execute in order | Preserve consistency during rapid typing. |
| Late voice results are ignored after cancellation | Prevent stale asynchronous insertion. |

---

# 10. Voice Typing and AI-Assisted Features

## 10.1 Voice Engine

The voice engine separates lifecycle management from provider implementation. A provider exposes initialization, start, stop, script mode, mic mode, and result callbacks. This design allows the Flutter UI and controller to remain independent of a specific speech vendor.

The engine supports partial transcripts for live feedback and final transcripts for editor insertion. A silence timer provides a clean automatic stop when no speech activity is received for the configured interval.

## 10.2 Provider Failover

The Sarvam key pool maintains multiple configured keys. When an authentication, quota, or rate-limit error is detected, the pool marks the current key as failed and rotates to another configured key. If all keys are marked failed, the pool resets so that temporary provider conditions do not permanently disable the session.

## 10.3 Optional AI Assistant

The optional AI assistant can detect a configured wake word, capture a multi-chunk voice command, use Gemini for routing or response generation, and use Tavily for web-search retrieval when required. The assistant is disabled by default unless explicitly enabled through the application settings.

The AI assistant is intentionally separated from normal transcription. If it is disabled, ordinary voice text follows the standard transcription path. This limits unnecessary provider calls and reduces the risk that ordinary speech is accidentally treated as an AI command.

## 10.4 Failure Handling

The application treats optional provider failure as a recoverable condition. Empty credentials do not prevent startup. Network failures are surfaced through user-facing status messages where appropriate. The core keyboard remains available for local typing even when voice or AI services are unavailable.

---

# 11. Testing and Validation

## 11.1 Testing Strategy

Testing is organized at multiple levels. Unit tests validate pure engines and state transitions. Widget tests validate keyboard rendering and interaction. Integration-oriented tests validate the relationship between voice results, keyboard actions, and editor state. CI executes formatting, static analysis, tests, and an Android debug build.

## 11.2 Test Categories

| Category | Examples |
|---|---|
| Language tests | Language registry, supported scripts, language selection. |
| Core controller tests | Insertion, deletion, selection replacement, shift state, editor actions. |
| Voice tests | Initialization, partial results, final results, cancellation, silence timeout, provider lifecycle. |
| AI tests | Wake-word capture, multi-chunk buffering, routing, fallback behavior. |
| Widget tests | Keyboard rendering, panels, theme changes, keyboard layers, key taps. |
| Build checks | Dart formatting, Flutter analyzer, Flutter tests, APK compilation. |

## 11.3 Important Regression Cases

The following cases are particularly important for future development:

| Test case | Expected result |
|---|---|
| Insert character at end | Character appears once at the end. |
| Insert character in middle | Character appears once at the selected caret position. |
| Delete character in middle | Only the intended character is removed. |
| Replace selected word | Selected range is replaced without changing surrounding text. |
| Rapid consecutive key taps | Events remain ordered and are not duplicated. |
| Mic listening followed by key tap | Pending voice text is preserved and key input is immediate. |
| Late voice result after cancellation | Late result is ignored. |
| Voice provider unavailable | Keyboard remains usable and displays a recoverable status. |
| Empty optional credentials | Application starts without a provider-related crash. |

## 11.4 CI/CD Validation

The repository CI workflow validates every change through the following sequence:

1. Check out the source code.
2. Install the configured Flutter toolchain.
3. Resolve dependencies.
4. Check Dart formatting.
5. Run Flutter static analysis.
6. Run tests with coverage.
7. Build a debug Android APK.
8. Upload the APK as a workflow artifact.

A separate release workflow is designed for signed tag-based releases. Release signing credentials and provider credentials are expected to be supplied through encrypted repository secrets rather than source files.

## 11.5 Test Result Summary

The latest verified CI run completed successfully for formatting, static analysis, Flutter tests, Android debug APK build, and APK artifact upload. The local release build was also generated with R8 and resource shrinking enabled for the arm64 architecture.

For a college demonstration, final validation should be performed on a physical Android device using at least one messaging application and one long-form text editor. The evaluator should test native typing, Roman input, middle-text editing, selection replacement, voice transcription, and keyboard enable/disable flows.

---

# 12. Security, Privacy, and Ethical Considerations

## 12.1 Credential Management

Live provider credentials must not be committed to a public repository. The project source uses build-time configuration. For a public production release, this is still not sufficient because compile-time Dart defines become part of the application binary and may be extracted by a determined attacker.

The recommended production architecture is:

```text
Android keyboard -> Project backend proxy -> Provider API
```

The backend should enforce authentication, rate limits, quotas, logging controls, and key rotation. Provider keys should remain server-side.

## 12.2 User Data and Privacy

A keyboard can process sensitive data because users may type passwords, personal messages, financial information, and health information. The core local typing path should therefore avoid transmitting text unless the user explicitly activates a network-dependent feature. Voice typing requires microphone permission and sends audio to the configured speech provider. Optional AI features may transmit voice-derived text or search queries to external services.

A production release should provide a complete privacy policy, clear consent flows, data retention information, provider disclosures, and a mechanism to disable cloud features. The current academic prototype documents these considerations but should not be treated as a completed legal compliance package.

## 12.3 Secure Testing Practice

Private testing APKs containing provider credentials must not be uploaded to public repositories, shared in public chat, or distributed broadly. Keys used in development should be rotated if they are exposed. The academic submission should include architecture and configuration procedures, not the secret values themselves.

---

# 13. Results and Discussion

## 13.1 Functional Outcome

The project successfully demonstrates a multilingual Android keyboard architecture with a Flutter interface and native Android IME integration. The application supports language-aware layouts, script switching, suggestions, editor actions, voice lifecycle management, and productivity panels.

## 13.2 Reliability Outcome

The most significant reliability improvement is the exact-range text replacement protocol. It addresses the failure mode in which middle-text edits caused cursor movement and duplicate insertion. The protocol preserves unchanged prefixes and suffixes and applies only the intended edit to the host field.

The voice interaction path was also improved. Key presses no longer wait for the voice provider's network flush window. Pending partial speech is preserved before the key edit, and late callbacks are prevented from modifying the editor after cancellation.

## 13.3 Build Outcome

The debug build was approximately 155 MB because it included debug overhead and multiple Android architectures. A release arm64 build using R8 code shrinking, resource shrinking, and split-per-ABI packaging reduced the APK to approximately 20.7 MB. A 5–10 MB target is not realistic for a complete Flutter application with an Android IME, Flutter runtime, networking, and voice-related dependencies.

## 13.4 Academic Learning Outcome

The project provided practical experience in:

- Designing a layered mobile application.
- Integrating Flutter with a native Android service.
- Managing asynchronous event streams and race conditions.
- Implementing text selection and cursor synchronization.
- Handling optional cloud-provider failure.
- Writing unit, widget, and integration-oriented tests.
- Automating quality checks and build artifacts through CI/CD.
- Evaluating security risks in client-side API integration.

---

# 14. Limitations

The current implementation has the following limitations:

1. Provider credentials supplied through a private APK remain extractable from the binary. A backend proxy is required for a secure public release.
2. Voice typing depends on microphone permission, network availability, provider availability, language support, and account quota.
3. The current Android voice provider is Sarvam AI; other providers require an implementation of the provider abstraction.
4. The application has been validated through automated tests and development-device workflows, but broad compatibility testing across Android manufacturers and text editors remains future work.
5. The compact release APK is optimized for arm64 devices. Separate APKs are required for other ABIs.
6. AI-assisted functionality depends on external provider responses and should not be used for high-stakes decisions without independent verification.
7. The current project is an academic prototype and does not yet include a full public-release privacy compliance process, crash analytics program, or staged production rollout.

---

# 15. Future Scope

The following improvements are recommended:

## 15.1 Security and Backend

A backend proxy can protect provider keys, enforce per-user quotas, authenticate requests, and provide centralized monitoring. Short-lived tokens and server-side provider calls would reduce the risk associated with distributing credentials in an APK.

## 15.2 Language and Accessibility Expansion

Future versions can add more language packs, improved transliteration dictionaries, phonetic correction, regional keyboard layouts, handwriting input, switch-access support, and enhanced screen-reader semantics.

## 15.3 Offline and On-Device Intelligence

An offline speech model, local language model, or on-device transliteration engine could reduce network dependence and improve privacy. Such additions would require careful evaluation of APK size, memory consumption, battery usage, and device compatibility.

## 15.4 Advanced Editing

Future editing features may include word-level cursor movement, gesture typing, grammar suggestions, undo/redo history, selected-text translation, and richer composing-region support for complex scripts.

## 15.5 Production Operations

A production release should add signed App Bundles, staged rollout, crash reporting, performance monitoring, automated dependency updates, device-matrix testing, accessibility audits, and a documented incident-response process.

---

# 16. Project Management and Development Workflow

## 16.1 Development Phases

| Phase | Major activities |
|---|---|
| Phase 1: Analysis | Problem definition, feature identification, requirements, and technology selection. |
| Phase 2: Design | Architecture, data model, keyboard layout, state model, and IME interaction design. |
| Phase 3: Core implementation | Flutter UI, controller, language layouts, text editing, and Android IME bridge. |
| Phase 4: Feature implementation | Suggestions, transliteration, voice typing, panels, themes, and optional AI services. |
| Phase 5: Reliability work | Selection synchronization, exact range replacement, event ordering, and cancellation behavior. |
| Phase 6: Testing | Unit tests, widget tests, integration-oriented regression tests, and device testing. |
| Phase 7: Delivery | Documentation, CI/CD, signed/private builds, and final academic demonstration. |

## 16.2 Repository Structure

```text
flutter_app/
├── android/                 Android host and InputMethodService
├── assets/                  Icons and sticker assets
├── lib/
│   ├── core/                Controller and application state
│   ├── data/                Languages, layouts, emoji, and stickers
│   ├── engine/              Voice, AI, suggestions, transliteration, providers
│   ├── ime/                 Flutter-to-Android IME bridge
│   └── ui/                  Keyboard view and feature panels
├── test/                    Unit, widget, and integration-oriented tests
├── docs/                    Release and project documentation
├── .github/workflows/       CI/CD automation
├── pubspec.yaml             Flutter dependencies and metadata
└── README.md                Development and release instructions
```

## 16.3 Recommended Demonstration Sequence

For the final viva or project demonstration, the student should:

1. Show the application onboarding screen and enable the keyboard.
2. Select Bhasha Keyboard from the Android input-method picker.
3. Demonstrate English and one Indian-language layout.
4. Switch between native and Roman input modes.
5. Insert text at the beginning, middle, and end of an existing sentence.
6. Select and replace a word, then demonstrate backspace and editor actions.
7. Open the microphone, dictate a short sentence, and show the transcript.
8. Tap a keyboard key during listening to demonstrate responsive transition back to typing.
9. Show suggestions, clipboard, emoji, theme, and language panels.
10. Explain the architecture, security limitations, test strategy, and CI/CD workflow.

---

# 17. Conclusion

Bhasha Keyboard demonstrates the design and implementation of a multilingual Android Input Method Editor for Indian-language users. The project combines Flutter UI development with native Android IME integration and provides a practical foundation for language-aware typing, transliteration, voice input, suggestions, editing, and productivity tools.

The project makes a specific contribution to reliability through exact changed-range replacement between the Flutter text model and the host Android editor. This design prevents the cursor jumps and duplicated input associated with broad tail deletion during middle-text editing. The voice interaction flow similarly separates immediate key responsiveness from asynchronous provider shutdown.

The implementation is structured as a production-oriented academic prototype. It includes modular services, explicit lifecycle states, automated tests, CI/CD validation, release documentation, and security guidance. Its primary remaining production concern is the protection of cloud-provider credentials, which should be addressed through a backend proxy before public distribution.

Overall, the project meets the objectives of a B.Tech. Minor Project by applying software engineering principles to a real-world mobile input problem and by demonstrating a complete path from requirements and architecture to implementation, testing, documentation, and build automation.

---

# 18. References

[1]: https://docs.flutter.dev/ "Flutter Documentation"

[2]: https://developer.android.com/reference/android/inputmethod/InputMethodService "Android InputMethodService Reference"

[3]: https://developer.android.com/reference/android/view/inputmethod/InputConnection "Android InputConnection Reference"

[4]: https://kotlinlang.org/docs/home.html "Kotlin Documentation"

[5]: https://dart.dev/language "Dart Language Documentation"

[6]: https://pub.dev/packages/provider "Provider Package Documentation"

[7]: https://pub.dev/packages/shared_preferences "Shared Preferences Package Documentation"

[8]: https://docs.github.com/en/actions "GitHub Actions Documentation"

[9]: https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions "Using Secrets in GitHub Actions"

[10]: https://docs.sarvam.ai/ "Sarvam AI Documentation"

[11]: https://ai.google.dev/gemini-api/docs "Gemini API Documentation"

[12]: https://docs.tavily.com/ "Tavily Documentation"

[13]: https://developer.android.com/privacy-and-security/risks/ "Android Privacy and Security Guidance"

---

## Appendix A: Project Metadata

| Field | Value |
|---|---|
| Project title | Bhasha Keyboard: A Multilingual Android Input Method Editor for Indian Languages |
| Project type | B.Tech. Seventh-Semester Minor Project |
| Primary platform | Android |
| Primary framework | Flutter |
| Native integration | Kotlin Android IME service |
| Application package | `com.bhashakeyboard.ime` |
| Minimum platform | Android 6.0/API 23 or project-configured minimum |
| Core language count | 22 Indian-language packs as documented by the project |
| Optional services | Sarvam AI, Gemini, Tavily |
| License | MIT License for the project source |

## Appendix B: Glossary

| Term | Meaning |
|---|---|
| API | Application Programming Interface; a defined way for software components to communicate. |
| APK | Android Package Kit, the installable Android application package. |
| CI/CD | Continuous Integration and Continuous Delivery/Deployment. |
| IME | Input Method Editor, an Android service that provides keyboard input. |
| Roman input | Typing a language phonetically using Latin characters. |
| Native script | The writing system normally used by a language. |
| `InputConnection` | Android interface used by an IME to communicate with the focused text editor. |
| Caret | The insertion point indicating where new text will be placed. |
| R8 | Android code shrinker and optimizer used to reduce release application size. |
| ABI | Application Binary Interface, such as `arm64-v8a`, identifying a processor architecture. |
| WebSocket | A persistent network communication channel suitable for streaming events. |

## Appendix C: Student Customization Checklist

Before submitting this report, replace every bracketed placeholder:

- `[Your Full Name]`
- `[Your Roll Number]`
- `[Your Enrollment Number]`
- `[Mentor Name and Designation]`
- `[Department Name]`
- `[College/Institute Name]`
- `[University Name]`
- `[20XX–20XX]`
- `[Date]`
- `[HOD Name]`

The student should also add the institute logo, prescribed page margins, signature scans if required, plagiarism declaration format, and any college-specific formatting rules before final submission.

> **Submission safety note:** Do not paste Sarvam, Gemini, Tavily, or any other live API key into the report, source repository, screenshots, or presentation slides.

---

*Prepared as an academic project report template for customization by the student.*

*End of Report*


---

# Appendix D: Uniqueness and Competitive Differentiation

## D.1 Why Bhasha Keyboard Is Different

Bhasha Keyboard should not be presented as the first keyboard to support Indian languages, transliteration, voice typing, or translation. Established products such as Gboard and Microsoft SwiftKey already provide several of these capabilities. For example, Google has documented Indic-language and transliteration support in Gboard [14], Gboard provides a translate-while-typing workflow [15], and Microsoft documents transliteration support in SwiftKey [16]. Therefore, the academically defensible claim is not that every individual feature is unavailable elsewhere.

The project’s distinction is the **integration of multiple regional-language, editing, voice, translation, and AI-assistance workflows into one focused Android IME**, with particular attention to Indian-language users and reliable cursor-aware editing. In other words, Bhasha Keyboard differentiates itself through the combination, consistency, and engineering focus of its features rather than through one isolated feature claim.

## D.2 Key Differentiators

| Differentiator | Bhasha Keyboard capability | Why it matters |
|---|---|---|
| Broad regional-language focus | A unified registry and layout system for 22 Indian-language packs. | Users can access multiple regional languages from one keyboard architecture instead of treating each language as a separate product experience. |
| Odia native and Roman input | Odia is represented through its native script layout and Roman/transliteration workflow, with provider language-code handling for Odia. | Odia users can type using the script they know while also using a familiar QWERTY-style phonetic workflow. |
| Consistent native/Roman switching | Supported language packs expose script-mode changes through the same keyboard interaction model. | A user can adapt the keyboard to context, literacy preference, or device familiarity without changing applications. |
| Integrated real-time voice typing | The mic workflow is part of the keyboard and uses partial and final streaming transcription states. | Voice input is available at the point of typing rather than requiring a separate assistant workflow. |
| Smart voice AI assistant | Optional wake-word capture, multi-chunk voice command buffering, Gemini routing, and Tavily retrieval. | The microphone can support both ordinary dictation and an explicit AI-assistance mode while keeping those paths separate. |
| Real-time translation workflow | Voice translation mode can produce translated English output and adapt the output style to the selected script configuration. | Users can move from speech to translated text inside the keyboard workflow. |
| Cursor-safe middle-text editing | Exact changed-range replacement preserves unchanged prefixes and suffixes and replaces only the intended host-editor range. | This addresses a practical reliability problem: insertion, deletion, and replacement in the middle of text without duplication or unexpected caret movement. |
| Voice-to-keyboard transition | A key press during listening preserves the latest partial transcript, cancels the active voice session immediately, and allows the key to be inserted without waiting for network flush. | Users can switch from speaking back to typing without the keyboard appearing frozen. |
| One integrated productivity surface | Clipboard, emoji, stickers, GIF search, text editing, themes, resize, language settings, and voice controls are available in the same IME. | The user does not need to leave the active text-entry context for common productivity operations. |
| Provider failover design | Sarvam, Gemini, and Tavily key pools can rotate after authentication, quota, or rate-limit failures in private test builds. | The architecture demonstrates resilience and makes provider integration replaceable. |
| Production-oriented engineering | The project includes modular services, automated tests, formatting checks, static analysis, Android build verification, CI/CD workflows, and release documentation. | The project is evaluated as a maintainable software system, not only as a visual keyboard prototype. |

## D.3 Specific Strength of the Odia Workflow

Odia is a strong demonstration language for this project because it illustrates the need for both script-native and phonetic input. In the native workflow, the user can select an Odia keyboard layout and enter Odia characters directly. In the Roman workflow, the user can use Latin characters on a familiar QWERTY arrangement and receive language-aware processing or transliteration where supported. The application also maps the language to the provider-specific `od-IN` code required by the current speech integration.

The important innovation claim is therefore not that no other application supports Odia. Other products and language tools also provide Odia input or transliteration [17] [18]. The stronger and more accurate claim is that Bhasha Keyboard places Odia native typing, Odia Roman input, voice typing, translation configuration, and cursor-safe system-wide editing inside one common IME architecture.

## D.4 Comparison with Major Alternatives

| Evaluation dimension | Gboard | SwiftKey | Standalone regional keyboard | Bhasha Keyboard project focus |
|---|---|---|---|---|
| General maturity and scale | Very mature general-purpose keyboard | Very mature general-purpose keyboard | Usually focused on one language or script | Academic prototype focused on Indian-language integration |
| Indian-language availability | Broad Indic-language and transliteration support [14] | Broad language catalogue and transliteration support [16] | Often strong for a selected language | Unified architecture for 22 project-defined regional packs |
| Odia native/Roman demonstration | Availability depends on the installed language configuration | Availability depends on supported language configuration | Often optimized for Odia only | Both modes are explicitly demonstrated within one project workflow |
| Translate while typing | Available as a documented feature [15] | Feature set varies by version and configuration | Usually limited | Translation is integrated with voice and keyboard configuration in the project design |
| Voice typing | Mature general-purpose voice input | Voice features vary by platform and version | Usually limited or provider-specific | Streaming provider abstraction with partial/final state handling |
| AI assistant inside the keyboard | Product-specific and account-dependent | Product-specific and version-dependent | Usually absent | Optional wake-word, Gemini routing, and Tavily retrieval architecture |
| Research transparency | Commercial product; internal implementation is not the project focus | Commercial product; internal implementation is not the project focus | Varies | Source structure, tests, architecture, and CI/CD are available for academic inspection |
| Editing reliability contribution | Mature product behavior | Mature product behavior | Varies | Explicit exact-range replacement designed and tested for middle-text edits |
| Main project advantage | — | — | — | A focused, inspectable, extensible academic implementation combining these workflows |

This table is a **feature-positioning comparison**, not a claim that commercial competitors lack the listed capabilities. Commercial products may be more mature, more optimized, or broader in scope. Bhasha Keyboard’s value in the academic context is that its design decisions are inspectable, its regional-language focus is explicit, and its reliability problems are addressed at the source-code and test level.

## D.5 Recommended Viva Answer

If asked, “Why is this project different from Gboard or SwiftKey?”, the student can answer:

> Bhasha Keyboard is not claiming that commercial keyboards have no Indian-language, transliteration, voice, or translation features. Its contribution is the focused integration of these capabilities for Indian-language typing in one inspectable Android IME. It provides a common workflow for 22 regional-language packs, explicitly demonstrates Odia native and Roman input, combines real-time voice typing with translation and an optional smart voice assistant, and addresses a difficult engineering problem through exact-range cursor-safe editing. The project also exposes its architecture, tests, and CI/CD workflow, which makes it suitable for academic evaluation and future extension.

## D.6 Recommended Presentation Slide

For the final presentation, use the following concise message:

> **Bhasha Keyboard: one Indian-language IME for native script, Roman input, voice, translation, AI assistance, and reliable editing.**
>
> Its differentiator is not one isolated feature. It is the integrated, inspectable, and extensible workflow designed around the practical needs of Indian-language users.

## D.7 Claims That Should Be Avoided

The following statements should not be used without a controlled benchmark or a verified market survey:

- “No competitor supports Indian languages.”
- “Bhasha Keyboard is the first keyboard with transliteration.”
- “Gboard and SwiftKey cannot type Odia.”
- “No other keyboard supports real-time translation.”
- “Bhasha Keyboard is more accurate than every commercial keyboard.”

The preferred academic wording is **“project differentiator,” “integrated workflow,” “focused contribution,” “inspectable implementation,”** and **“designed to address.”** This wording is stronger because it is technically defensible and does not depend on unsupported universal comparisons.

---

## Additional References for Appendix D

[14]: https://blog.google/products-and-platforms/products/search/gboard-android-gets-new-languages-and-tools/ "Google: Gboard for Android gets new languages and tools"

[15]: https://support.google.com/gboard/answer/7421372?hl=en "Google Gboard Help: Translate as you type"

[16]: https://support.microsoft.com/en-us/swiftkey-keyboard/which-languages-support-transliteration-and-how-does-it-work-on-swiftkey-for-android "Microsoft Support: Transliteration in SwiftKey for Android"

[17]: https://support.microsoft.com/en-us/windows/set-up-and-use-indic-phonetic-keyboards "Microsoft Support: Set up and use Indic phonetic keyboards"

[18]: https://play.google.com/store/apps/details?id=com.odia.keyboard.for.android&hl=en_US "Google Play: Desh Odia Keyboard"
