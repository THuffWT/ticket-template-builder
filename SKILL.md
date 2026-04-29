---
name: ticket-template-builder
description: >-
  Guided workflow that builds a personal library of Jira ticket templates for a
  product manager by analyzing the tickets they've already written. Use when the
  user says "build my ticket templates", "create ticket templates from my Jira",
  "set up my ticket templates", or invokes /ticket-template-builder.
---

# Ticket Template Builder

**Announce at start:** "I'm using the ticket-template-builder skill to build your ticket templates. This should take about 15 minutes. I'll ask you questions along the way — you can stop and resume anytime."

This skill takes a product manager from zero to a personal library of Jira ticket templates by analyzing the tickets they've already written. It is project-agnostic — works with any Jira project at any company.

**Platform note for all questions in this skill:**
- **Claude Code** — call the `AskUserQuestion` tool with the parameters specified at each step
- **Cursor / Codex** — present the same options as a numbered list in chat; never say "press enter" — always require the user to type a number or reply with the option name

## Phase 0: Detect Platform and Re-Run Check

**Detect the platform** the user is on. Look for clues in environment or MCP server names first. If you can't determine it, use AskUserQuestion:

**Use AskUserQuestion:**
- question: "Which AI tool are you running this in?"
- header: "Platform"
- multiSelect: false
- options:
  - label: "Claude Code", description: "The Anthropic CLI or desktop app"
  - label: "Cursor", description: "The AI code editor"
  - label: "Codex", description: "OpenAI's coding agent"

**Check for an existing config** at `~/.ticket-templates/config.yaml`. If it exists, read it and use AskUserQuestion:

**Use AskUserQuestion:**
- question: "I found a saved config from a previous run. What do you want to do?"
- header: "Re-run mode"
- multiSelect: false
- options:
  - label: "Continue", description: "Use the same Jira project and output folder"
  - label: "Refresh", description: "Re-analyze tickets and overwrite existing templates"
  - label: "Start fresh", description: "Pick a new project or folder"

If continuing or refreshing, skip questions in later phases that the config already answers.

## Phase 1: Atlassian MCP Setup

Search available tools for `searchJiraIssuesUsingJql` (the Atlassian MCP tool).

**If the tool is available:** Call it with a small probe query to confirm authentication and identify the account:

```
Tool: getAccessibleAtlassianResources (or similar account-info tool from the Atlassian MCP)
```

If no account-info tool exists, run a tiny `searchJiraIssuesUsingJql` query (`maxResults: 1`) and pull the user info from the response.

Show the account details, then use AskUserQuestion:

**Use AskUserQuestion:**
- question: "✓ Atlassian MCP is connected. Account: `<email>` / Sites: `<site-list>`. Is this the right account?"
- header: "Account"
- multiSelect: false
- options:
  - label: "Yes, continue", description: "Proceed with this account"
  - label: "No, wrong account", description: "I'll help you switch accounts"

**If the tool is NOT available**, walk the user through setup based on their platform. Use WebFetch to pull the most current Atlassian Remote MCP setup instructions for that platform from these URLs:
- Claude Code: `https://support.atlassian.com/rovo/docs/setting-up-ides-for-the-atlassian-remote-mcp-server/` (look for the Claude Code section)
- Cursor: same URL, Cursor section
- Codex: same URL, Codex section
- Fallback: `https://www.atlassian.com/blog/announcements/remote-mcp-server`

Tell the user the install path for their platform's MCP config and the exact JSON snippet to add. Walk them through OAuth authentication. After setup, verify the tool is available before continuing.

If the Atlassian docs have changed since this skill was written, trust the docs over the skill.

## Phase 2: Project Selection

Ask in chat:
"Which Jira project do you want to use? Give me the project key (e.g. `DQLS`, `PROJ`, `MYTEAM`)."

If the user gives a name instead of a key, query Jira to find the matching project key.

## Phase 3: Output Folder

Use AskUserQuestion:

**Use AskUserQuestion:**
- question: "Where should I save your tickets and templates?"
- header: "Output folder"
- multiSelect: false
- options:
  - label: "Use ./ticket-templates (Recommended)", description: "Create a ticket-templates folder in your current directory"
  - label: "Choose a custom path", description: "I'll ask you to type a specific folder path"

If the user selects "Choose a custom path" (or enters a custom path via the Other field), ask in chat:
"What folder path should I use? (absolute or relative, e.g. `~/Documents/my-templates`)"

If the chosen folder already has tickets in it from a previous run, ask before overwriting.

Create the folder structure:
```
{output_folder}/
├── tickets/        ← raw ticket files
├── organized/      ← sorted by issue type
└── templates/      ← final output
```

## Phase 4: Author Filter

Use two AskUserQuestion calls — one for whose tickets to pull, one for the cap:

**Use AskUserQuestion:**
- question: "Which tickets should I pull? Option 1 pulls tickets you reported, which is what we analyze for your style."
- header: "Author filter"
- multiSelect: false
- options:
  - label: "Tickets I reported (Recommended)", description: "JQL: reporter = currentUser()"
  - label: "Tickets I wrote the description for", description: "Uses reporter as the closest proxy — Jira doesn't expose description author directly"
  - label: "All tickets in the project", description: "Only choose this if you want to analyze the whole team's style"

**Use AskUserQuestion:**
- question: "How many tickets should I pull at most?"
- header: "Ticket cap"
- multiSelect: false
- options:
  - label: "500 tickets (Recommended)", description: "Enough for solid pattern analysis without hitting limits"
  - label: "250 tickets", description: "Faster pull, still usually enough"
  - label: "100 tickets", description: "Quick run — good for a first test"
  - label: "No cap", description: "Pull all matching tickets (may take a while on large projects)"

## Phase 5: Pull Tickets

Build the JQL based on author choice:
- Reported: `project = {KEY} AND reporter = currentUser() ORDER BY created DESC`
- Wrote description: `project = {KEY} AND reporter = currentUser() ORDER BY created DESC` (closest available — Jira doesn't expose "description author" directly)
- All: `project = {KEY} ORDER BY created DESC`

**Do NOT set `responseContentFormat` — omit it entirely.** Descriptions come back as markdown strings automatically, and setting it breaks pagination on some MCP clients.

**Call parameters (every call):**
- `maxResults: 100` (always)
- `fields: ["summary", "issuetype", "status", "priority", "description", "created", "updated", "creator", "reporter"]`
- Do not set `responseContentFormat`

**Save each raw page immediately** to `{output_folder}/_raw-jira-pages/page-{N}.json` before doing anything else — this prevents context overflow on large responses.

**After saving each page, follow these steps in order:**

1. Extract the tickets from the page. They may be in `response.issues` (a list) or `response.issues.nodes` (an array inside an object) — use whichever is present.

2. Count the tickets in this page. Add to your running total.

3. **Determine the next page token** — check in this order:
   - If `response.nextPageToken` exists → pass it as `nextPageToken` on the next call
   - Otherwise → take the `created` timestamp of the **last ticket** in the page and add `AND created < "{that_timestamp}"` to the JQL on the next call

4. **Stop if ANY of these are true:**
   - This page had fewer than 100 tickets (it's the last page)
   - `response.isLast` is `true`
   - Running total has reached the cap

5. Otherwise make the next call and repeat.

6. Report progress: "Fetched {n} tickets (page {p})..."

**On timeout:** retry the same call once with identical parameters before giving up.

After all pages are fetched, process the saved JSON files to write individual ticket files to `{output_folder}/tickets/`. For each ticket in `response.issues`, save to `{output_folder}/tickets/{KEY}-{number} - {sanitized-title}.md`:

```markdown
# {KEY}-{number}: {title}

## Jira Metadata

- Link: {ticket.webUrl}
- Project: {project_name}
- Issue Type: {issue_type}
- Status: {status}
- Priority: {priority}
- Created: {created}
- Updated: {updated}
- Creator: {creator}
- Reporter: {reporter}

## Jira Description Markdown

{ticket.fields.description — already a markdown string}
```

Show a final count when done: "✓ Pulled {n} tickets across {p} pages."

## Phase 6: Organize by Issue Type

Read the `Issue Type:` line from each ticket's metadata. Auto-discover all unique issue types — don't assume Story/Bug/Task. Custom types like Incident, Initiative, Change Request all count.

Create `{output_folder}/organized/{Issue Type}/` for each type. For each ticket file: write it to the organized subfolder, then **delete the original from `tickets/`**. Do not leave copies in both locations — after this phase the `tickets/` folder should be empty.

Report:
"✓ Organized {N} tickets into {X} folders:
- Story: {n}
- Bug: {n}
- [etc, sorted by count descending]"

## Phase 7: Pick Issue Types to Template

Use AskUserQuestion with multiSelect. Build options dynamically from the discovered issue types, sorted by ticket count descending. Include the ticket count in each description. If there are more than 4 issue types, use the top 4 by count — the user can type additional ones via the Other field.

**Use AskUserQuestion:**
- question: "Which issue types do you want templates for? Select all that apply. (I need at least 5 tickets per type to find reliable patterns — types with fewer will get a best-guess template.)"
- header: "Issue types"
- multiSelect: true
- options: [dynamically built — one per discovered type, label = type name, description = "{n} tickets"]

For any chosen issue type with fewer than 5 tickets, use AskUserQuestion:

**Use AskUserQuestion:**
- question: "Only {n} {type} tickets found — the template will be more guess than analysis. What do you want to do?"
- header: "{type}"
- multiSelect: false
- options:
  - label: "Build it anyway", description: "I'll do my best with limited data"
  - label: "Skip this type", description: "Skip and move on"

## Phase 8: Pattern Analysis

For each chosen issue type:

**Sampling strategy:**
- If the type has 30 or fewer tickets: read ALL of them
- If more than 30: sample 30 spread across project key prefixes AND subject areas (look at the variety in filenames). Goal is variety, not arithmetic spread.

**Context window protection:** for any type with 50+ tickets, dispatch a subagent (Explore type) to read and analyze the tickets. Give the subagent the full Step 1 functional type classification instructions and ask it to return: functional type for each ticket, section structure per functional group, voice/tone per group, and outlier filenames. Do not read 50+ files inline.

Read only the `## Jira Description Markdown` section of each file.

### Step 1: Functional type classification (do this first)

**Do not start with section headers.** Most tickets share the same section structure (Overview → Details → AC), so structural analysis alone collapses everything into one group. The real signal is in *what kind of work the ticket is doing*.

Read each ticket's title and Overview bullet(s) and classify it by functional type. Look for these signals:

- **Flag / conditional logic** — flag field names and value states (e.g. `flag = true | SHOW`, `flag = false | HIDE`), Remote Config or feature flag references, show/hide logic
- **Deeplink / navigation** — "deeplink" or "deeplinking" in title, URL slug patterns (e.g. `app://screen`), named entry points (push notifications, in-app messages, email/Branch links), fallback/error handling per deeplink
- **Fix / remediation / audit** — audit reference (e.g. EY, pen test, accessibility audit), finding IDs or severity codes (H1, M4, L2, HUB-ID), "from the X audit" phrasing, prescribed fix language
- **UI / UX build** — Figma link, named UI states (Main State, Loading State, Empty State, Guest State, Error State), screen or component name as the subject
- **Backend / API / data source** — data source references (CMS, remote config service, third-party API), field names in backticks, resolver/endpoint/query descriptions, field migration lists
- **Analytics** — analytics event names, tracking call descriptions, parameter lists, platform-specific SDK references

These are illustrative categories, not an exhaustive list. Use what you find in the tickets. If the user's tickets show a different split (e.g. "infrastructure", "security", "copy change"), name and use those instead.

For each ticket, write down its functional type. **This classification is the primary basis for grouping into sub-templates** — not section headers.

### Step 2: Apply the merge test before splitting into sub-templates

After classifying by functional type, apply this test to every potential split:

**"Would a PM filling out template A need meaningfully different context or structure than template B?"**

- If the only differences are slot values (platform name, data source name, flag name, screen name) → **merge into one template** with flexible placeholders
- If the structural skeleton — section order, required sections, key decision points — is genuinely different → **keep separate**

Examples of what to merge vs. split:
- "UI build with Figma link" vs. "UI build without Figma link" → **merge** (make Figma optional in one template)
- "Feature flag using Remote Config" vs. "Feature flag using a backend service" → **merge** (same structure, different slot)
- "Feature flag" vs. "Deeplink setup" → **split** (completely different structure and context requirements)
- "BFF resolver build" vs. "CMS field migration" → likely **merge** (both are backend data tickets with the same skeleton)

**Target sub-template count:** 3–5 for a high-volume issue type (50+ tickets). If you're finding 6+, apply the merge test more aggressively. If you're finding only 1–2, you likely skipped the functional classification step.

### Step 3: Look for structural variants within each kept group

Once groups pass the merge test, look at each for:
- **Section headers and order** — what sections appear, in what sequence
- **Voice/tone** — "we want to", imperative, passive, etc.

### Step 3: Flag outliers

- **Content the author didn't write**: pasted emails, copied Slack threads, vendor doc dumps, audit report pastes — exclude from analysis
- **Minimal tickets** (1–3 sentences, no structure) — not a useful template base; flag them separately

After analyzing each issue type, present the findings in chat (patterns, outliers, skipped tickets), then use AskUserQuestion to confirm:

**Use AskUserQuestion:**
- question: "How do these patterns look for {Issue Type}?"
- header: "{Issue Type}"
- multiSelect: false
- options:
  - label: "Looks good", description: "Proceed with these patterns"
  - label: "Make changes", description: "Tell me what to rename, merge, add, or skip in the chat"

After all types are confirmed, show a summary table in chat:

| # | Template Name | Issue Type | Use Case | ~% |
|---|---|---|---|---|

Then use AskUserQuestion:

**Use AskUserQuestion:**
- question: "Ready to build these templates?"
- header: "Build"
- multiSelect: false
- options:
  - label: "Yes, build them", description: "Proceed to template generation"
  - label: "Make adjustments first", description: "Tell me what to change in the chat"

## Phase 9: Build Draft Templates

Build **one template at a time**. For each one:

1. Re-read the example tickets for that pattern (don't rely on Phase 8 memory)
2. Extract the most consistent structure: section headers, order, voice
3. Build a skeleton with `[PLACEHOLDER]` labels
4. Add a usage block at the top:

```markdown
# {Template Name} Template

> **How to use:** Give Claude (or Cursor/Codex) the following context and ask it to fill in this template.
>
> **Minimum context needed:**
> - [field 1]
> - [field 2]
>
> **Optional context that improves the ticket:**
> - [field 1]

---

# [Title format matching the pattern]

[sections with placeholders, matching the real tickets exactly]
```

Show the draft in chat, then use AskUserQuestion:

**Use AskUserQuestion:**
- question: "How does the draft look for **{Template Name}**?"
- header: "Draft review"
- multiSelect: false
- options:
  - label: "Looks good, next template", description: "Move on to the next template"
  - label: "Sections missing", description: "Tell me which sections to add in the chat"
  - label: "Remove a section", description: "Tell me which sections to remove in the chat"
  - label: "Fix placeholder language", description: "Describe what feels off in the chat"

Incorporate any feedback before moving to the next template.

## Phase 10: Formatting Pass

After all draft templates are approved, run a formatting pass on each one **one at a time**.

For each template, first ask whether panels are used:

**Use AskUserQuestion:**
- question: "Does **{Template Name}** use any colored Jira panels? (info/blue, note/yellow, warning/orange, tip/green, error/red)"
- header: "Panels"
- multiSelect: false
- options:
  - label: "No panels", description: "Skip panel annotations for this template"
  - label: "Yes, some sections use panels", description: "I'll describe which sections and colors in the chat"

If yes, ask in chat:
"Which sections use panels, and what color? e.g. 'AC → info', 'Current Behavior → error, Expected Behavior → success'"

Then ask about other Jira formatting:

**Use AskUserQuestion:**
- question: "Does **{Template Name}** use any other special Jira formatting?"
- header: "Formatting"
- multiSelect: true
- options:
  - label: "Checklists", description: "Interactive checkboxes (taskList nodes)"
  - label: "Tables", description: "One or more sections rendered as tables"
  - label: "Code blocks", description: "Fenced code with a specific language"
  - label: "None of the above", description: "No other special formatting"

For each panel mapping, add to the template:
```
<!-- ADF: wrap in a panel node with panelType: "{type}" -->
{section content}
<!-- /ADF panel -->
```

For other formatting, add a comment above the section:
```
<!-- ADF: render as a checklist (taskList node) -->
```

Show the updated template in chat, then use AskUserQuestion:

**Use AskUserQuestion:**
- question: "Does the formatting annotation look right for **{Template Name}**?"
- header: "Formatting check"
- multiSelect: false
- options:
  - label: "Looks right, continue", description: "Move to the next template"
  - label: "Something's off", description: "Tell me what to fix in the chat"

## Phase 11: Validation

For each finished template, generate ONE sample ticket using fake-but-plausible context. Show all samples in chat, then use AskUserQuestion:

**Use AskUserQuestion:**
- question: "Do these sample tickets read like something you'd actually write?"
- header: "Validation"
- multiSelect: false
- options:
  - label: "Yes, they look right", description: "Finalize all templates"
  - label: "Something feels off", description: "Tell me what to fix in the chat — or you can edit the template files directly later"

## Phase 12: Final Output

Save each template to `{output_folder}/templates/{Template Name}.md`.

Save the user's config to `~/.ticket-templates/config.yaml`:
```yaml
jira:
  project_key: "{KEY}"
  account: "{email}"
output_folder: "{absolute path}"
last_run: "{ISO date}"
templates_built:
  - "{Template Name}"
```

Generate `{output_folder}/templates/README.md`:

```markdown
# My Ticket Templates

Generated by ticket-template-builder on {date}.

| Template | Issue Type | Use When |
|---|---|---|
| [Name](./Name.md) | Story | [one-liner] |

## How to use

When you want Claude/Cursor/Codex to write a ticket, paste the relevant template into the chat and say:

> "Using the [Template Name] template, write a [issue type] ticket. Here's the context: [your context]"

If you have the Atlassian MCP set up, your AI can also create the ticket directly in Jira from these templates — the `<!-- ADF: ... -->` comments tell it how to format Jira-specific elements like panels and checklists.

## Sharing these templates

These are yours — copy them into Slack, Notion, or commit them to your team's docs repo so anyone can use them.
```

Final summary to the user:

"✓ Done! Built {N} templates in `{output_folder}/templates/`:

{list of templates with one-liners}

**To use them:**
- Paste a template into your AI chat with: 'Using the [Template Name] template, write a ticket. Context: ...'
- Or commit them to your team's docs repo so others can use them too

**To rebuild later:** just run `/ticket-template-builder` again — your config is saved."
