# ChangeWindow

**Runbook, rollback deadline and evidence for infrastructure engineers executing approved changes inside after-hours maintenance windows.**

iOS 17+ · SwiftUI · MVVM + Use Cases · Core Data · WidgetKit · Share Extension · Notification Content Extension

---

## Project overview

ChangeWindow is a companion for the engineer standing in a data hall at 1 am implementing an approved change (e.g. `CHG0041932 – Patch Hyper-V cluster HV-CLUS01`). It keeps the approved window, the **rollback deadline** (the "point of no return"), the numbered runbook and the evidence log on the device that is always in their pocket — while the laptop is busy being the console.

The app enforces the rules that, when broken, turn routine changes into outages: don't start outside the approved window, do mandatory steps in order, stop and make a Go/No-Go call at the rollback deadline, and don't close a change without proof it worked.

## Domain context

| Term | Meaning in ChangeWindow |
|---|---|
| **Change request** | A CAB-approved infrastructure change, identified by its reference (`CHG…`). Aggregate root. |
| **Maintenance window** | The approved period (`opensAt`–`closesAt`) the change may run in. |
| **Rollback deadline** | Latest time the back-out plan can still be completed before the window closes. |
| **Runbook step** | A numbered instruction from the implementation plan; mandatory or optional. |
| **Go/No-Go decision** | The explicit call at the rollback deadline: proceed, or roll back (with a rationale). |
| **Evidence** | Vendor links, log excerpts, console screenshots and notes captured for the post-implementation review (PIR). |

Primary stakeholder: **an infrastructure consultant executing a CAB-approved change on a client's production systems during an after-hours maintenance window.**

## Architecture summary

```
SwiftUI Views ──▶ ViewModels (@MainActor) ──▶ Use Cases (business rules + typed errors)
                                                    │
                                                    ▼
                                    ChangeRequestRepository (protocol)
                                     │                         │
                     PlatformSyncingChangeRequestRepository   MockChangeRequestRepository (tests)
                       (decorator: widget snapshot,
                        WidgetCenter reload, reminders)
                                     │
                         CoreDataChangeRequestRepository ──▶ Core Data (app-private SQLite)

App Group  group.com.vignesh.changewindow
  ├─ widget-snapshot.json   app writes → Widget + Share Extension read
  ├─ EvidenceInbox/*.json   Share Extension writes → app imports via AttachEvidenceUseCase
  └─ EvidenceFiles/*.jpg    Share Extension writes screenshots → app displays
Notification userInfo       app scheduler writes → Notification Content Extension renders
```

* **Semantic domain model** — `ChangeRequest`, `MaintenanceWindow`, `RunbookStep`, `EvidenceItem`, `GoNoGoRecord`, `ChangeStatus`.
* **Use Cases** (each with a typed, human-readable error enum):

| Use Case | Business rules enforced | Error enum |
|---|---|---|
| `ScheduleChangeUseCase` | Unique CAB reference; window in the future and ordered; rollback deadline strictly inside window; ≥ 1 step | `ScheduleChangeError` |
| `BeginChangeWindowUseCase` | Only inside the approved window; only from Scheduled; one change in progress at a time | `BeginChangeError` |
| `CompleteRunbookStepUseCase` | Mandatory steps in order; optional steps skippable; blocked after rollback deadline until Go/No-Go | `CompleteRunbookStepError` |
| `RecordGoNoGoDecisionUseCase` | Only while in progress; recorded once; rollback needs a rationale and closes as Rolled Back | `GoNoGoDecisionError` |
| `CloseChangeUseCase` | All mandatory steps done; ≥ 1 evidence item; records implicit Go if none | `CloseChangeError` |
| `AttachEvidenceUseCase` | Non-blank; not cancelled; closed changes accept evidence for 24 h only | `AttachEvidenceError` |

* **Errors are written for the engineer** — every case has `errorDescription` (what went wrong) and `recoverySuggestion` (what to do next); a unit test enforces this.

### Screens (stakeholder workflow order)

1. **Change Windows** – schedule: in progress / upcoming / closed
2. **Schedule Change** – CAB reference, approved window, rollback deadline, runbook
3. **Change Console** – live countdown to rollback deadline, runbook, allowed actions
4. **Runbook Step** – instruction, engineer note, mark complete
5. **Go/No-Go Decision** – progress summary, Go / No-Go with rationale
6. **Close Change** – PIR summary, close as completed
7. **Evidence Log** – notes plus items shared in from other apps

## Extensions and why they exist

| Extension | User scenario |
|---|---|
| **WidgetKit** (`systemSmall`, `systemMedium`, `accessoryRectangular`, `accessoryCircular`, `accessoryInline`) | Hands on a crash-cart keyboard, phone face-up on the rack shelf: a glance at the Lock Screen shows the current step and the live countdown to the rollback deadline without unlocking. Timeline entries are placed at the deadline and window close so it turns red on time even if the app is never opened. Tapping deep-links to the change. |
| **Share Extension** (URL, image, text) | Mid-change a cluster warning appears; the engineer finds the Microsoft KB in Safari or screenshots the console and shares it straight into the live change's evidence log, tagged with the step in progress — instead of it being lost in the camera roll. |
| **Notification Content Extension** (category `ROLLBACK_DECISION`) | 15 minutes before the rollback deadline a time-sensitive notification shows a decision card (steps done, next step, live countdown, back-out time remaining) with **Go** and **No-Go — roll back…** (text input for the reason) actions. The decision is recorded from the Lock Screen through `RecordGoNoGoDecisionUseCase`. |

## Database choice: Core Data

Change records hold client infrastructure detail (host names, change numbers, outcomes) and must be **private, local and available offline** — data halls frequently have no mobile signal. CloudKit would sync client data into the engineer's personal iCloud account, which conflicts with typical client data-handling obligations, and multi-device sync gives this single-user, single-device workflow no benefit.

* Entities: `ChangeRequestRecord` 1—< `RunbookStepRecord`, `ChangeRequestRecord` 1—< `EvidenceItemRecord` (cascade delete; uniqueness constraint on `reference`).
* Schema defined in code (`ChangeWindowDataModel.swift`) so it is diffable and reviewable.
* Domain predicates, e.g. `statusRaw == "inProgress" AND goNoGoDecisionRaw == nil AND rollbackDeadline <= now` (changes awaiting a Go/No-Go) and `statusRaw == "scheduled" AND windowOpensAt >= start AND windowOpensAt < end`.
* The store stays in the app's private container. Extensions never open it: they exchange small purpose-built files via the App Group, which avoids multi-process SQLite writers in memory-constrained extensions and keeps the validation rules in one place.

## App Group identifier

```
group.com.vignesh.changewindow
```

Defined in `Shared/AppGroup.swift` and all four `Config/*.entitlements` files. If you change the bundle prefix, change it in all five places.

## Setup instructions

1. macOS with **Xcode 15.3+** (iOS 17 SDK). Install XcodeGen: `brew install xcodegen`.
2. From the repo root: `xcodegen generate` → creates `ChangeWindow.xcodeproj` (commit it).
3. Open the project, select each of the 4 targets → *Signing & Capabilities* → choose your Team. If your team can't register `com.vignesh.*`, change the prefix in `project.yml`, the entitlements and `AppGroup.identifier`.
4. Run the **ChangeWindow** scheme on an iPhone simulator (iOS 17+).
5. On the empty schedule tap **Load sample changes (demo)** — this creates a change already in progress whose rollback deadline is 20 minutes away (reminder fires in ~5 min).
6. **Widget:** long-press the Home Screen / Lock Screen → add *ChangeWindow → Active Change*.
7. **Share Extension:** in Safari open any page → Share → *ChangeWindow* → attach to `CHG0041932`. Return to the app; it appears in the Evidence Log.
8. **Notification Content Extension:** allow notifications, open the live change → ••• → *Preview Go/No-Go reminder (5 s)* → lock the simulator (⌘L) → long-press the notification.
9. **Tests:** ⌘U (25 tests, all against `MockChangeRequestRepository`).

## Testing

`ChangeWindowTests` uses `MockChangeRequestRepository` and `FixedClock` — no Core Data. Tests cover happy paths (scheduling, closing, evidence tagging), boundaries (beginning exactly at window open, deadline at the exact rollback time, evidence exactly 24 h after closure, deadline equal to window close) and domain errors (out-of-order steps, missing rollback rationale, overwriting a decision, storage failure).

## Git workflow

* `main` holds only stable, building code; work happens on feature branches merged by PR:
  `feature/domain-model`, `feature/core-data-repository`, `feature/use-cases`, `feature/change-console-ui`, `feature/widget-extension`, `feature/share-extension`, `feature/notification-content-extension`, `test/use-case-coverage`, `docs/readme`.
* Conventional Commits, e.g. `feat(widget): show rollback countdown on Lock Screen`, `fix(share): dismiss extension after deposit`, `test: cover rollback rationale rule`, `docs: add App Group setup`.
