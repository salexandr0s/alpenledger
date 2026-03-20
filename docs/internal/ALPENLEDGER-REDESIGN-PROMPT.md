# AlpenLedger — macOS App Redesign Prompt

## Context

AlpenLedger is a local-first, encrypted Swiss finance workspace for macOS. It handles tax readiness, bookkeeping, and document management for Swiss sole proprietors and natural persons. The app is built with a native macOS stack (likely SwiftUI or AppKit) and uses a dark theme. It currently has working functionality but the design is inconsistent, cluttered with empty states, and lacks the polish expected of a premium native Mac app.

The target user is a Swiss freelancer / GmbH owner managing their own bookkeeping and tax prep — someone who wants the app to feel like a trustworthy, calm financial tool, not a developer prototype.

---

## Global Design System Issues to Fix

### 1. Establish a Unified Design Token System
- **Color palette**: Define a tight palette. Currently, blues, reds, oranges, and grays are used ad-hoc. Pick ONE accent color (suggest a refined blue or teal), ONE warning color, ONE destructive/blocking color. Use semantic naming: `color.accent`, `color.warning`, `color.destructive`, `color.surface.primary`, `color.surface.secondary`, `color.surface.elevated`.
- **Typography scale**: The app mixes font sizes inconsistently. Define a strict type ramp: `title-large`, `title`, `headline`, `body`, `caption`, `overline`. Use SF Pro (system font) with proper weight distribution — semibold for headings, regular for body, medium for labels.
- **Spacing system**: Use a 4px base grid. All padding, margins, gaps should be multiples of 4. Currently, spacing is inconsistent between and within cards.
- **Corner radii**: Standardize. Pick one radius for cards (suggest 10–12px), one for badges/pills (full-round), one for buttons (8px). Currently, different components use different radii.
- **Elevation / surfaces**: Define 3 surface levels: `base` (window background), `elevated` (cards, panels), `overlay` (popovers, dialogs). Use subtle brightness differences, NOT borders, to distinguish layers. Currently the cards use visible borders on dark backgrounds which looks heavy.

### 2. Sidebar Navigation
- The sidebar section labels (HOME, RECORDS, FILING, UTILITY) are too faint and use all-caps overline text that's hard to read on dark backgrounds.
- **Fix**: Use slightly brighter overline text with more vertical spacing above each group. Add 16px gap between groups. The active state should use a subtle filled background (not a bright blue block) — think macOS Sonoma-style sidebar with a rounded highlight and slight translucency.
- Badge counts (the "4" on Inbox, Tax Studio) should be small, muted pills — not bright colored circles competing with the nav labels.
- Consider adding subtle icons to each nav item for faster scanning (already partially done, but inconsistently).

### 3. Empty States
- **This is the single biggest design problem.** Almost every screen shows large, hollow empty states with generic icons and vague copy. When the app is new, the user sees emptiness everywhere.
- **Fix**: Every empty state should be: (a) compact — not taking up a full column, (b) actionable — always include a primary CTA button, (c) contextual — the copy should tell the user what to do next specifically, (d) visually light — use a small monoline icon, a one-liner of text, and a button. No giant illustrations.
- Multi-column layouts should collapse gracefully when there's no content. Don't show three empty columns side by side — collapse to a single centered message.

### 4. Badge / Status System
- "Blocking" badges are bright red with an icon, "Pending" badges are orange. Both are too visually loud for a finance app — they create anxiety rather than clarity.
- **Fix**: Use a calmer status system. Blocking = a muted red text label or a small dot indicator. Pending = amber/yellow dot. Resolved = green dot. Use color sparingly — a small colored dot + text label is enough. Don't use filled background badges for every status.

---

## Screen-by-Screen Redesign Specifications

### Screen 1: Welcome / Workspace Picker

**Current problems:**
- Two-column layout is asymmetric and lacks visual hierarchy
- Raw filesystem paths shown in recent workspaces
- "Local-First" feature section is marketing copy that doesn't belong on a launcher screen
- "Encrypted locally" and "On this Mac" badges use inconsistent visual treatments
- The Create Workspace form card and Open Existing card are separate but should feel unified

**Redesign direction:**
- Center the screen content vertically and horizontally. This is a launcher — it should feel focused, not like a dashboard.
- Top: App icon + "AlpenLedger" wordmark + one-line tagline.
- Middle: Recent workspaces as a clean list (workspace name + last opened date only, NO file paths). Each item is a clickable row with a hover state. Clicking opens the workspace.
- Bottom: Two actions side by side — "Create New Workspace" (primary button) and "Open Existing…" (secondary/text button). The create flow should open a sheet/dialog, not be inline.
- Remove the "Local-First" feature blurb. If trust messaging is needed, put a single subtle line under the app icon: "Encrypted. Local. Yours." — no bullet points.
- Visual style: Think of how Raycast, Linear, or Arc present their launch screens — minimal, centered, confident.

### Screen 2: Overview / Dashboard

**Current problems:**
- Top stats row has 4 different metrics with inconsistent card layouts
- "Start Here" card competes visually with "Needs Attention" panel
- "Needs Attention" panel is a long scrolling list of red/orange badges — too aggressive
- "Recent Activity" shows a large empty illustration when there are no imports
- "Workspace Snapshot" is small and buried

**Redesign direction:**
- **Top section**: Show the workspace name prominently with the entity count as a subtitle. Below, show 3–4 key metrics in a clean horizontal row of equal-width stat cards: Open Issues (number + label), Pending Requirements (number + label), Documents (number + label), Tax Readiness (progress indicator or status label). Each card should be the same height and layout.
- **Primary action area**: Replace "Start Here" with a single, prominent next-action card that dynamically shows the highest-priority action. Use an icon + title + description + CTA button. This should be the visual focal point.
- **Issues list**: Show the top 3–4 blocking issues in a compact list below the action card. Each issue is a single row: icon + title + status dot. No large badges. Include a "View all →" link.
- **Recent Activity**: If empty, show a single line "No recent imports" with an "Import" link — not a large illustration.
- **Workspace Snapshot**: Integrate the entity/account counts into the top stats row instead of a separate card.

### Screen 3: Inbox

**Current problems:**
- Three stats at top showing zeros is wasted space
- Flat issue list with identical red badges — no visual differentiation
- Inspector panel shows a huge empty state
- No filtering, sorting, or grouping options visible

**Redesign direction:**
- Remove the top stats bar (Issues/Proposals/Imports counts). Use tabs or a segmented control instead: Issues | Proposals | Imports — with a count badge on each tab.
- **Issue list**: Each row should show: a colored status dot (not a full badge), the issue title (truncated if needed), the entity it belongs to as a secondary label, and the date. Group issues by entity or by type if there are more than 5.
- **Inspector panel**: When nothing is selected, show a minimal one-liner "Select an issue to inspect" with no illustration. When an issue IS selected, show full details: title, status, description, related account, suggested resolution, and action buttons (Resolve, Dismiss, Link Statement).
- Add a search/filter bar above the list.

### Screen 4: Ledger

**Current problems:**
- Three-column layout with two empty states when nothing is selected
- Account list items are extremely sparse — no balance, no visual richness
- "All" filter dropdown is orphaned in the header

**Redesign direction:**
- **Account list (left column)**: Each account row should show: account icon (bank icon, colored per account type), account name, account type label, and CURRENT BALANCE in CHF prominently on the right side. The balance is the most important piece of information and it's completely missing.
- **Transaction list (middle column)**: When an account is selected, show transactions in a clean table: date | description | amount (green for income, red/default for expense) | category tag. Add a search bar and date range filter at the top. When no account is selected, collapse this column or show a compact prompt.
- **Inspector (right column)**: When a transaction is selected, show: full details, linked documents, category, notes, and action buttons. When nothing is selected, DON'T show a full empty state — just leave the panel with a muted "Select a transaction" hint at the top.
- Add an "Import Transactions" button in the account list header or as a toolbar action.

### Screen 5: Documents

**Current problems:**
- Three panels all showing empty states simultaneously
- "Import Document" button is buried
- No drag-and-drop hint
- The screen looks completely dead when empty

**Redesign direction:**
- When there are no documents, collapse to a single centered empty state: an upload icon, "Import your first document" as a heading, "Drag and drop receipts, statements, and tax forms here — or click to browse." with a prominent "Import Document" button. Show a subtle dashed border drop zone.
- When documents exist: left column = document list (thumbnail + name + date + type tag), middle = document preview (PDF/image viewer), right = inspector (metadata, linked transactions, tags).
- Add drag-and-drop support with a visual drop zone indicator.
- Add a toolbar with: search, filter by type (Receipt, Statement, Tax Form), sort by date/name.

### Screen 6: Tax Studio

**Current problems:**
- Entity/Year dropdowns feel disconnected from the content below
- "Missing Facts" is a plain bullet list with no interactivity cues
- Three bottom columns all show empty "No facts" states
- The readiness card mixes a status label, a fact list, and stat counters with no clear hierarchy
- Too much information competing for attention

**Redesign direction:**
- **Top bar**: Entity and Tax Year selectors should be in a compact toolbar row, not floating dropdowns. Add a "Readiness: Not Started" status badge next to them.
- **Readiness overview**: A single card showing a progress bar or checklist. Each requirement is a row: checkbox-style indicator (done/missing/pending) + label + status. Items should be interactive — clicking a missing fact should open the inspector or prompt the user to enter the value.
- **Facts section**: Below the readiness card, show facts organized by category (Personal Income, Deductions, Self-Employment, etc.) as collapsible sections. Each category shows its completion state. When a category has no facts, show a compact inline "No data yet — Add" prompt, not a full empty state.
- **Inspector**: Appears as a slide-over or right panel only when a specific fact or requirement is selected. Don't show it as an always-visible empty column.
- Remove the separate "Blockers & Requirements" column — merge it into the readiness checklist above.

### Screen 7: Settings

**Current problems:**
- Extremely bare — just flat key-value pairs
- No visual grouping or section cards
- "Add Sole Proprietor" feels bolted on
- Entities list shows no detail or actions

**Redesign direction:**
- Group settings into clear sections with card containers:
  - **Workspace**: Name (editable), Type, Location on disk, Encryption status, Created date.
  - **Entities**: List of entities as rich rows — entity name, type (Sole Proprietor / Natural Person), and action buttons (Edit, Remove). Each entity row could expand to show details.
  - **Add Entity**: A clear CTA at the bottom of the entities section — "Add Sole Proprietor" or "Add Entity" with a type selector.
  - **Data Management**: Export workspace, backup, reset — group these if/when they exist.
- Use section headings with subtle dividers. Each section should be a visually distinct card or grouped area.
- Make entity names editable inline or via a detail sheet.

---

## Visual Reference / Target Aesthetic

The redesign should feel like a premium, native macOS app in the style of:
- **Linear** — clean information density, calm color palette, precise typography
- **Things 3** — warm but minimal, excellent use of whitespace, native feel
- **Fantastical** — rich functionality with polished, layered UI
- **Craft** — elegant document-centric design, great empty states

Key principles:
1. **Calm confidence** — This is a finance app. It should feel trustworthy and stable, not flashy.
2. **Progressive disclosure** — Show only what's needed. Don't display three empty columns. Collapse, hide, or simplify when there's no content.
3. **Native feel** — Use system fonts, respect macOS conventions (sidebar, inspector, toolbar), support dark/light mode properly.
4. **Information density done right** — When there IS data, show it densely and clearly. When there ISN'T data, show a focused onboarding prompt.
5. **Consistent rhythm** — Every screen should feel like it belongs to the same app. Same card styles, same spacing, same typography, same interaction patterns.

---

## Deliverable Expectations

This prompt should be used to guide a SwiftUI/AppKit implementation or a design tool mockup. Each screen should be redesigned individually, but all screens must share the design token system defined above. The redesign should not add new features — only improve the visual design, layout, and UX of existing functionality.
