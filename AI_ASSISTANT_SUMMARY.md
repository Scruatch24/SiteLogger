# SiteLogger AI Assistant — Complete System Reference

## What It Is

The AI Assistant is a chat-based interface embedded in SiteLogger's invoice creation page. Users dictate or type invoice details, and the AI extracts structured data (items, prices, clients, dates, taxes, discounts) into a live-editable invoice form. After initial extraction, users can refine the invoice through a conversational chat — adding items, changing prices, managing taxes, selecting clients, etc. — without re-recording.

---

## Architecture Overview

### Files

| File | Role |
|------|------|
| `home_legacy.js` (~9,990 lines) | All frontend JS: chat UI, widget rendering, state management, voice recording, API calls |
| `home_controller.rb` (~4,720 lines) | Backend: `process_audio` (initial extraction), `refine_invoice` (chat refinements), enforcement functions, client matching, clarification generation |
| `_ai_assistant_section.html.erb` | Chat container HTML: header with icon + "Online" badge, message area, input bar with text + mic + send |
| `invoice_generator.rb` | PDF generation with Prawn: BILLED TO, FROM, ISSUED, DUE, NUM badges, item tables, totals |
| `config/locales/en.yml` + `ka.yml` | All localized strings (English + Georgian) |
| `index.html.erb` | Populates `window.APP_LANGUAGES` and global JS variables |

### State Management (Frontend Global Variables)

| Variable | Purpose |
|----------|---------|
| `window.lastAiResult` | Current invoice JSON from AI — the source of truth for refinements |
| `window._userItemOverrides` | Locked field values that override AI responses (from widget confirmations) |
| `window._undoStack` | Array of snapshots for undo (max 10), each with JSON + chat HTML + state flags |
| `window.clarificationHistory` | Array of Q&A pairs for conversation context sent to AI |
| `window._recentQuestions` | Loop protection — tracks last 10 questions to prevent AI re-asking |
| `window._clarificationQueue` | Sequential queue of pending clarification widgets |
| `window._queueAnswers` | Collected answers from queue, batch-submitted to AI |
| `window.clientMatchResolved` | Flag: client matching is done, don't re-trigger |
| `window._wasAddClientYes` | Flag: user wants to create new client (triggers detail collection) |
| `window._newClientDetails` | Collected client details (email, phone, address, notes) |
| `window._collectingClientDetail` | Currently active detail field being collected |
| `window._pendingAnswer` | Queued user answer displayed after AI finishes processing |
| `window._aiReturnedNothing` | Flag: AI returned identical data (shows "didn't understand" prompt) |
| `window._lastAiReply` | AI's natural language reply text, shown before widgets |
| `window._taxManagementItems` | Items array for the tax management widget (chip handler) |
| `window._taxQueueItems` | Items array for the tax management widget (in queue) |
| `window._removeSelectedItems` | Selected items for the remove-item widget |
| `window._invoicePreviewShownOnce` | Prevents auto-opening PDF preview more than once |
| `window.profileTaxRate` | User's configured default tax rate |
| `window.profileSystemLanguage` | User's system language preference |

---

## Input Methods

### 1. Voice Recording
- **`startAssistantRecording()`** — starts MediaRecorder, shows timer, captures audio chunks
- Audio sent to `POST /process_audio` as multipart form data
- Supports both initial recording (full extraction) and refinement recording (within chat)
- Timer countdown visible on mic button
- Language auto-detected or set via live transcription language selector

### 2. Text Input
- Textarea with character counter (profile-based limit: `@profile.char_limit`)
- Enter key submits, Shift+Enter for newline
- Auto-resize textarea as user types
- Manual text sent to `POST /process_audio` with `manual_text` param

### 3. Live Transcription
- Browser speech recognition + server-side Google streaming STT
- Real-time transcript animation (typed-out effect)
- Language selector (English/Georgian) drives both recognition locale and AI language

---

## Backend Processing Pipeline

### `process_audio` (Initial Extraction)

1. **Input validation** — audio/text length checks, char limit enforcement
2. **Transcription** — Google STT for audio, or direct text input
3. **AI model call** — Gemini (primary: flash-lite, fallback: flash) with cached instruction prompt
4. **JSON parsing** — validates structure, handles malformed responses
5. **Post-processing:**
   - Free item detection (უფასოდ/free → price=0)
   - Section building (labor, materials, expenses, fees, credits)
   - Tax normalization (string→number, scope enforcement)
   - Clarification stripping (remove AI-generated client clarifications)
   - **`auto_upgrade_clarifications!`** — merges individual text questions into rich widgets
   - **`enforce_tax_from_message!`** — safety net: deterministically applies tax instructions
   - **`enforce_prices_from_message!`** — safety net: parses structured price answers
   - Client matching (exact → fuzzy → new, with confirmation for rare clients)
   - Sender info extraction (overrides for business name, address, etc.)
6. **Response** — normalized JSON with sections, clarifications, recipient_info, sender_info

### `refine_invoice` (Chat Refinements)

1. **Client change shortcut** — if `client_change_only`, bypasses AI entirely, just does client matching
2. **AI model call** — focused refine prompt that only modifies what user asked for
3. **Post-processing:**
   - Tax normalization
   - `auto_upgrade_clarifications!`
   - `enforce_tax_from_message!` + `enforce_prices_from_message!`
   - `generate_missing_clarifications` — catches missing prices, vague names, unresolved discounts
   - Client list widget generation (for "show clients" requests)
   - Client matching (same as process_audio)
   - AI reply extraction
4. **Response** — same format as process_audio

### Backend Safety Nets

| Function | What It Does |
|----------|-------------|
| `enforce_tax_from_message!` | Parses tax instructions (remove tax, set rates) from user message. Handles: remove all tax, per-item rates ("18% phone"), "rest X%", Georgian verb stems (დაბეგრ, მოაშორე, etc.) |
| `enforce_prices_from_message!` | Parses price/hours from batch Q&A answers ("შეკეთება 5 საათი 100 ლარი") |
| `auto_upgrade_clarifications!` | Converts simple text questions into rich widgets (item_input_list for prices, tax_management for rates, etc.) |
| `generate_missing_clarifications` | Detects missing prices on new items, vague item names, unresolved discounts |

---

## Frontend Processing Pipeline

### `triggerAssistantReparse()` (Sending Messages to AI)

1. **`syncLastAiResultFromDOM()`** — reads current DOM values (prices, quantities, tax rates, discounts) back into `lastAiResult` so manual edits aren't lost
2. **Undo checkpoint** — pushes current state onto `_undoStack`
3. **Tax safety net** — if message contains any tax keyword, calls `applyTaxTextDirectly()` immediately
4. **Build request** — `current_json` + `user_message` + `conversation_history` + `language`
5. **Fetch with retry** — 1 retry after 1.5s on 500 or network error
6. **Override protection** — clears stale tax/discount overrides if user sent new tax/discount instructions
7. **`_reapplyAllOverrides()`** — re-applies locked widget values that AI may have overwritten
8. **Unchanged detection** — if AI returned identical data, shows "didn't understand" prompt
9. **`handleClarifications()`** — processes returned clarifications, builds widget queue

### `applyTaxTextDirectly()` (Frontend Tax Safety Net)

Keyword-based detection (no complex regex):
- **Remove all tax** — keyword list including "no tax", "tax free", "დღგ მოაშორ", "არ დაბეგრ", etc.
- **Set all to X%** — "all 18%", "ყველა 18%"
- **Remove tax from specific item** — matches item name stems with Georgian suffix handling
- **Per-item rates** — "phone 18%, rest 0%"
- **Just a number** — "18" → apply 18% to all items

---

## Clarification System

### Widget Types (rendered in chat)

| Type | Widget | Function |
|------|--------|----------|
| `client_confirm_existing` | Yes/No card with client avatar | Confirms if extracted client matches existing DB client |
| `client_match` | Client list with invoice counts + contact details | Disambiguates multiple similar clients; includes "Create new" option |
| `add_client_to_list` | Yes/No card | Asks if user wants to save new client details |
| `client_browse` | Scrollable client list | Shows all user's clients for selection |
| `section_type` | Icon buttons (Labor/Materials/Expenses/Fees) | Categorizes ambiguous items |
| `currency` | Currency buttons with flags | Selects invoice currency |
| `item_input_list` | Multi-row input card with qty/price fields + toggles | Collects prices, quantities, billing modes for multiple items at once |
| `tax_management` | Per-item slider + input + bulk buttons (None/All/Confirm) | Sets tax rates per item with visual sliders |
| `discount_type` | Fixed/Percentage toggle for single item | Selects discount type |
| `discount_type_multi` | Fixed/Percentage toggle per item | Selects discount types for multiple items |
| `choice` | Button list | Single-select from options |
| `multi_choice` | Checkboxes with accordion categories | Multi-select from grouped options |
| `yes_no` | Two buttons (Yes/No) | Simple binary choice |
| `info` | AI bubble (auto-advances after 1.5s) | Informational message, no user input needed |
| `text` | AI bubble + text input | Free-form text answer |

### Queue System

1. Clarifications are sorted by priority: category → info → name/description → qty/price → discount → tax
2. Shown one at a time with progress counter ("Question 2 of 5")
3. Answers collected in `_queueAnswers`, then batch-submitted to AI via `batchSubmitQueueAnswers()`
4. Loop protection: questions already asked recently are auto-skipped
5. Widget-text conflict handling: if user types text while widget is showing, widget is disabled

---

## Quick Action Chips

Rendered after "Anything else?" prompt. Each chip triggers a specific action:

| Chip | Handler | Action |
|------|---------|--------|
| Change client | `handleChipChangeClient()` | Opens client input or client list for paid users |
| Add item | `handleChipAddItem()` | Starts add-item flow with name → price collection |
| Remove item | `handleChipRemoveItem()` | Shows accordion with checkboxes to select items for removal |
| Add discount | `handleChipAddDiscount()` | Starts discount flow (amount + type) |
| Remove tax | `handleChipRemoveTax()` | 1-click: sets all items to taxable:false, tax_rate:0 |
| Manage taxes | `handleChipManageTax()` | Opens per-item tax slider widget |
| Change date | `handleChipChangeDate()` | Shows date picker (invoice date or due date) |
| Undo | `handleChipUndo()` | Restores previous state from undo stack |
| Create invoice | `handleChipCreateInvoice()` | Triggers PDF preview / save flow |

---

## Client Management

### Matching Flow (Backend)

1. **Exact match** — `ILIKE` on client name, then normalized name comparison
2. **Fuzzy match** — `ILIKE %name%`, then substring matching on normalized names
3. **Results:**
   - 1 match → auto-assign, confirm if <3 invoices
   - Multiple matches → show `client_match` widget with names, invoice counts, email, phone
   - 0 matches → treat as new, offer to add details

### Client Detail Collection (Frontend)

After client confirmation/creation, offers to collect:
- Email (with phone/email mismatch detection)
- Phone
- Address
- Notes

Each detail collected one at a time with type-specific prompts and validation.

### Direct Client Change

`directClientChange()` sends `client_change_only: true` to bypass AI entirely — just does DB matching.

---

## Undo/Redo System

- Max 10 snapshots on `_undoStack`
- Each snapshot stores: invoice JSON, chat HTML, history length, client match state, overrides
- `performUndoTo(idx)` — restores to any snapshot, truncating newer entries
- Inline undo buttons appear on certain widget actions
- Undo chip available in quick actions

---

## Manual Change Preservation

### Problem Solved
Users edit prices/quantities/tax directly in the invoice form DOM. When they then ask AI to make a different change, the AI would overwrite those manual edits.

### Solution (3 layers)

1. **`syncLastAiResultFromDOM()`** — before sending to AI, reads current DOM values (prices, quantities, tax rates, descriptions, billing modes, discounts) back into `lastAiResult`
2. **`_userItemOverrides`** — widget confirmations (tax management, item input list) lock specific field values that persist across AI responses
3. **`_reapplyAllOverrides()`** — after AI response arrives, re-applies all locked overrides before rendering

---

## Tax Handling

### Frontend Safety Net
- `applyTaxTextDirectly()` — keyword-based immediate application (runs BEFORE AI processes)
- `_lockCurrentTaxRates()` — locks current tax rates into `_userItemOverrides`
- `_lockItemFields()` — locks specific item fields (prices, quantities, etc.)

### Backend Safety Net
- `enforce_tax_from_message!()` — deterministic parsing after AI response
- Handles: remove all, per-item rates, rest/others rate, Georgian stems

### Tax Widget
- Per-item slider (0-100%)
- Bulk actions: None (0%), All (profile default rate), Confirm
- Uses `window.profileTaxRate` as default rate
- Both standalone (chip handler) and in-queue versions

---

## Invoice Output

### Live Preview
- `updateUIWithoutTranscript()` — renders AI response into the invoice form without touching transcript
- Populates: labor items, material/expense/fee sections, credits, client, dates, discounts, tax rates
- Each section type has its own DOM structure (labor-item-row vs item-row)

### PDF Generation (`invoice_generator.rb`)
- **Prawn-based** PDF with custom fonts (NotoSans + NotoSansGeorgian)
- **Dynamic badge widths** — `width_of()` measurement + padding, min 35pt
- **5 badges**: BILLED TO (orange), FROM (gray), ISSUED (gray), DUE (orange), NUM (gray)
- **Consistent styling**: both BILLED TO and FROM use size 10 bold for names, gray for contact details
- **Classic layout**: left column (client + sender), right column (dates + invoice number + logo)
- **Item table**: description, qty, rate, amount, tax, discount columns
- **Summary**: subtotal, discounts, tax, credits, total due with currency symbol

---

## Localization

### Dual Language Support
- **System language** (UI): English or Georgian — drives all labels, prompts, button text
- **Document language**: drives AI output language for item names, descriptions
- All strings via `window.APP_LANGUAGES` (populated from Rails locale files)
- Fallback pattern: `L.key || 'English default'`

### Georgian-Specific Handling
- Georgian case suffix stripping for fuzzy matching (ს, ის, ზე, იდან, ში, საც, აც)
- Georgian date terms (საწყისი თარიღი, ბოლო ვადა)
- Georgian client name convention (შპს "Company")
- Georgian tax terms (დღგ, დაბეგვრა, გადასახადი)

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Network error | 1 automatic retry after 1.5s, then error message |
| Server 500 | 1 automatic retry after 1.5s |
| AI returned identical data | "ვერ გავიგე" prompt + quick action chips |
| Empty/unclear audio | Error message, retry prompt |
| Input too short | Error message |
| Char limit exceeded | Frontend enforcement + server validation with 250-char buffer |
| AI JSON parse failure | Fallback to secondary model, then error |
| Widget conflict | If user types while widget showing, widget disabled |
| Question loop | Auto-skip questions asked in last 10 rounds |

---

## Analytics & Logging

- **`log/ai_assistant.log`** — structured JSON log of every AI interaction (model, message, items, tax states, clarifications, errors)
- **Analytics events**: voice processing, recording, transcription, AI override corrections
- **Override diff tracking**: logs when user overrides had to correct AI values

---

## Data Flow Summary

```
User speaks/types
    ↓
process_audio (initial) or refine_invoice (refinement)
    ↓
AI model (Gemini) extracts/modifies JSON
    ↓
Backend post-processing:
  → tax normalization
  → auto_upgrade_clarifications! (text → widgets)
  → enforce_tax_from_message! (safety net)
  → enforce_prices_from_message! (safety net)
  → generate_missing_clarifications
  → client matching
    ↓
Frontend receives response:
  → syncLastAiResultFromDOM() (before send)
  → _reapplyAllOverrides() (after receive)
  → updateUIWithoutTranscript() (render invoice)
  → handleClarifications() (show widgets/chat)
    ↓
User interacts with widgets / types / records
    ↓
Loop back to refine_invoice
```
