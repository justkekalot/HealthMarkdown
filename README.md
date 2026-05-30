# Health → Markdown

Turn **everything in Apple Health** into a single, clean Markdown file you can hand to an AI assistant.

<p align="center">
  <em>Read on-device · 40+ metrics · agent-ready tables · nothing leaves your phone</em>
</p>

---

## What it does

HealthMarkdown is a small, beautiful iOS app that:

1. Asks (once) for read access to your Apple Health data.
2. Reads a comprehensive catalog of metrics over a window you choose (7 days → all time).
3. Compiles a structured Markdown document — front-matter header, per-domain tables, explicit units.
4. Lets you **copy** the Markdown or **share** it as a `.md` file (AirDrop, Files, Mail, or straight into an LLM app).

Everything is read locally via **HealthKit**. The app has no network code — your data never leaves the device unless *you* share the file.

## Why Markdown for an agent?

LLMs read Markdown tables far more reliably than raw JSON dumps or screenshots. The generated document:

- Opens with a metadata block (window, freshness, data-point count) so the model knows scope immediately.
- Includes a short "How to read this" preamble so aggregates aren't misinterpreted.
- Groups metrics by domain (Activity, Heart, Sleep, Vitals, Nutrition, Workouts, …).
- Distinguishes cumulative totals from point-in-time averages, and always shows the latest reading.

## Metrics covered

| Domain | Examples |
|---|---|
| **Activity** | Steps, walking/running/cycling/swimming distance, flights, active & resting energy, exercise & stand time |
| **Heart** | Heart rate, resting HR, walking HR, HRV (SDNN), VO₂ max |
| **Body** | Weight, height, BMI, body fat, lean mass, waist |
| **Vitals** | Blood pressure, body temperature, blood glucose |
| **Respiratory** | Respiratory rate, blood oxygen |
| **Nutrition** | Energy, protein, carbs, fat, fiber, sugar, water, caffeine |
| **Sleep** | Time asleep, in-bed, REM/Core/Deep stages, nights |
| **Mindfulness** | Sessions, total time |
| **Mobility** | Walking speed, step length, double-support, asymmetry, 6-min walk |
| **Hearing** | Environmental & headphone sound levels |
| **Workouts** | Per-session activity, duration, energy, distance |
| **Profile** | Age, biological sex, blood type, skin type |

Adding a metric is a one-line change in `Sources/HealthKit/HealthCatalog.swift`.

## Architecture

```
Sources/
├── HealthMarkdownApp.swift      # @main entry
├── Models/                      # DateRange, HealthReport value types
├── HealthKit/
│   ├── HealthSection.swift      # domain grouping
│   ├── HealthCatalog.swift      # the single source of truth for metrics
│   └── HealthKitManager.swift   # auth + all queries (async/await)
├── Markdown/
│   ├── Formatting.swift         # number/date/duration helpers
│   └── MarkdownGenerator.swift  # report -> Markdown string
├── Views/
│   ├── Theme.swift              # colors, gradients, glass cards, button styles
│   ├── RootView.swift           # auth-gated routing
│   ├── OnboardingView.swift     # permission flow
│   ├── DashboardView.swift      # window picker + generate
│   └── PreviewView.swift        # scrollable preview + copy/share
└── Resources/                   # Assets, generated Info.plist & entitlements
```

The data layer is fully decoupled from the UI: `HealthKitManager` produces a `HealthReport`, and `MarkdownGenerator` is a pure function of that report (trivially testable, no I/O).

## Build & run

Requires **Xcode 16+** and **[XcodeGen](https://github.com/yonyz/XcodeGen)** (`brew install xcodegen`).

```bash
xcodegen generate          # creates HealthMarkdown.xcodeproj from project.yml
open HealthMarkdown.xcodeproj
```

Then in Xcode:

1. Select the **HealthMarkdown** target → Signing & Capabilities → set your Team.
2. Run on a **real device** (HealthKit data isn't present in most simulators).
3. Grant Health access when prompted, pick a window, and tap **Generate Markdown**.

> The `.xcodeproj` is git-ignored on purpose — it's generated from `project.yml`. Run `xcodegen generate` after cloning.

## Privacy

- `NSHealthShareUsageDescription` explains read-only access.
- No `NSHealthUpdateUsageDescription` writes occur — the app never modifies Health.
- No analytics, no networking, no third-party SDKs.

## License

MIT
