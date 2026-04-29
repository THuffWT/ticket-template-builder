---
name: ticket-template-builder
description: >-
  Guided workflow that builds a personal library of Jira ticket templates for a
  product manager by analyzing the tickets they've already written. Use when the
  user says "build my ticket templates", "create ticket templates from my Jira",
  "set up my ticket templates", or invokes /ticket-template-builder.
---

# Ticket Template Builder

**Announce at start:** "I'm using the ticket-template-builder skill to build your ticket templates. This will take 20–40 minutes depending on how many tickets you have. I'll ask you questions along the way — you can stop and resume anytime."

This skill takes a product manager from zero to a personal library of Jira ticket templates by analyzing the tickets they've already written. It is project-agnostic — works with any Jira project at any company.

## Phase 0: Detect Platform and Re-Run Check

**Detect the platform** the user is on. Look for clues in environment, MCP server names, or ask:
"Which AI tool are you running this in?
- Claude Code
- Cursor
- Codex"

**Check for an existing config** at `~/.ticket-templates/config.yaml`. If it exists, read it and ask:
"I found a saved config from a previous run. Want to:
1. **Continue** with the same Jira project and output folder
2. **Refresh** existing templates (re-analyze and overwrite)
3. **Start fresh** with new project / folder"

If continuing or refreshing, skip questions in later phases that the config already answers.

## Phase 1: Atlassian MCP Setup

Search available tools for `searchJiraIssuesUsingJql` (the Atlassian MCP tool).

**If the tool is available:** Call it with a small probe query to confirm authentication and identify the account:

```
Tool: getAccessibleAtlassianResources (or similar account-info tool from the Atlassian MCP)
```

If no account-info tool exists, run a tiny `searchJiraIssuesUsingJql` query (`maxResults: 1`) and pull the user info from the response.

Show the user:
"✓ Atlassian MCP is connected.
Account: `<email>`
Sites: `<site-list>`

Is this the right account? (yes / no)"

**If the tool is NOT available**, walk the user through setup based on their platform. Use WebFetch to pull the most current Atlassian Remote MCP setup instructions for that platform from these URLs:
- Claude Code: `https://support.atlassian.com/rovo/docs/setting-up-ides-for-the-atlassian-remote-mcp-server/` (look for the Claude Code section)
- Cursor: same URL, Cursor section
- Codex: same URL, Codex section
- Fallback: `https://www.atlassian.com/blog/announcements/remote-mcp-server`

Tell the user the install path for their platform's MCP config and the exact JSON snippet to add. Walk them through OAuth authentication. After setup, verify the tool is available before continuing.

If the Atlassian docs have changed since this skill was written, trust the docs over the skill.

## Phase 2: Project Selection

Ask:
"Which Jira project do you want to use? Give me the project key (e.g. `DQLS`, `PROJ`, `MYTEAM`)."

If the user gives a name instead of a key, query Jira to find the matching project key.

## Phase 3: Output Folder

Ask:
"Where should I save your tickets and templates?
- Type a folder path (absolute or relative)
- Or press enter and I'll create `./ticket-templates` in your current folder

If the folder already has tickets in it from a previous run, I'll ask before overwriting."

Create the folder structure:
```
{output_folder}/
├── tickets/        ← raw ticket files
├── organized/      ← sorted by issue type
└── templates/      ← final output
```

## Phase 4: Author Filter

Ask:
"Which tickets should I pull? You probably want option 1 — these are tickets you wrote, which is what we'll analyze for your style:

1. Tickets I **created** (recommended)
2. Tickets I **reported**
3. Tickets I **wrote the description for** (uses custom JQL)
4. **All tickets** in the project (only if you want to analyze the whole team's style)

Also: cap at how many? Default 500. Type `all` for no cap."

## Phase 5: Pull Tickets

Build the JQL based on author choice:
- Created: `project = {KEY} AND creator = currentUser() ORDER BY created DESC`
- Reported: `project = {KEY} AND reporter = currentUser() ORDER BY created DESC`
- Wrote description: `project = {KEY} AND creator = currentUser() ORDER BY created DESC` (closest available — Jira doesn't expose "description author" directly)
- All: `project = {KEY} ORDER BY created DESC`

Fetch in batches of 100 using `searchJiraIssuesUsingJql`, paginating until done or limit hit. Pull these fields:
`summary, issuetype, status, priority, description, created, updated, creator, reporter, project`

For each ticket, save to `{output_folder}/tickets/{KEY}-{number} - {sanitized-title}.md`:

```markdown
# {KEY}-{number}: {title}

## Jira Metadata

- Link: {site_url}/browse/{KEY}-{number}
- Project: {project_name}
- Issue Type: {issue_type}
- Status: {status}
- Priority: {priority}
- Created: {created}
- Updated: {updated}
- Creator: {creator}
- Reporter: {reporter}

## Jira Description Markdown

{description_converted_from_ADF_to_markdown}
```

**ADF → markdown conversion**: descriptions come back as Atlassian Document Format JSON. Convert: paragraphs → text, bulletList/listItem → `* item`, orderedList → `1. item`, heading levels → `#`/`##`/`###`, strong → `**text**`, em → `_text_`, code → backticks, codeBlock → fenced code, hardBreak → newline, inlineCard/blockCard → `[url](url)`, panel nodes → flatten to plain content (note: panels don't survive export — that's why this skill asks about them later).

Show progress every 50 tickets.

## Phase 6: Organize by Issue Type

Read the `Issue Type:` line from each ticket's metadata. Auto-discover all unique issue types — don't assume Story/Bug/Task. Custom types like Incident, Initiative, Change Request all count.

Create `{output_folder}/organized/{Issue Type}/` for each type and move files in.

Report:
"✓ Organized {N} tickets into {X} folders:
- Story: {n}
- Bug: {n}
- [etc, sorted by count descending]"

## Phase 7: Pick Issue Types to Template

Ask:
"Which issue types do you want templates for? You can pick multiple. Just list the numbers:

1. Story ({n} tickets)
2. Bug ({n} tickets)
3. [etc]

Tip: I need at least 5 tickets in a type to find reliable patterns. For types with fewer than 5, I'll build a basic template but it'll be more guess than analysis."

For any chosen issue type with fewer than 5 tickets, warn:
"Only {n} {type} tickets — the template will be more guess than analysis. Build it anyway, or skip?"

## Phase 8: Pattern Analysis

For each chosen issue type:

**Sampling strategy:**
- If the type has 30 or fewer tickets: read ALL of them
- If more than 30: sample 30 spread across project key prefixes AND subject areas (look at the variety in filenames). Goal is variety, not arithmetic spread.

**Context window protection:** for any type with 50+ tickets, dispatch a subagent (Explore type) to read and analyze the tickets. Have it return: section headers used, section order, structural variants, voice/tone, domain patterns, outlier filenames. Do not read 50+ files inline.

Read only the `## Jira Description Markdown` section of each file.

For each issue type, identify:
- **Section headers** — what's used? (H1, H2, H3, bold-only)
- **Section order** — typical sequence
- **Structural variants** — 1 dominant pattern, or 2-3 sub-patterns?
- **Voice/tone** — "we want to", imperative, passive, etc.
- **Domain patterns** — feature flags, API/data, deeplinks, audit fixes, etc.
- **Outliers** — tickets where the description is dominated by content the author *didn't write*: pasted emails, copied Slack threads, vendor doc dumps, audit findings. Exclude from pattern analysis. Also flag minimal tickets (1-3 sentences, no structure) — these are not a useful template.

After analyzing all chosen types, present findings **one type at a time**, waiting for user confirmation:

---
"## {Issue Type} ({n} tickets)

I found **{X} pattern(s)**:

**Pattern 1: {Name}** (~{%})
Structure: {Section1} → {Section2} → {Section3}
Examples: `{filename}`, `{filename}`

**Pattern 2: {Name}** (~{%})
[etc]

**Outliers excluded ({n} tickets):** Descriptions dominated by external pasted content — not your writing style.

**Skipping:** {n} minimal tickets (just 1-3 sentences). Let me know if you want a template for these too.

You can:
- Say **'looks good'** to confirm
- **Rename**, **merge**, **add**, or **skip** patterns"
---

After all types are confirmed, show a summary table:

| # | Template Name | Issue Type | Use Case | ~% |
|---|---|---|---|---|

Ask: "Ready to build? Reply 'yes' to proceed."

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

Show each draft to the user and ask:
"Here's the draft for **{Template Name}**:

{template content}

- Any sections I missed?
- Any sections I included that you don't use?
- Does the placeholder language feel right?"

Incorporate feedback before the next template.

## Phase 10: Formatting Pass

After all draft templates are approved, run a formatting pass on each one **one at a time**.

For each template, ask:
---
"Now let's capture Jira-specific formatting that doesn't show up in plain text exports.

**{Template Name}** has these sections:
{numbered list of section headers}

**Panels:** Does any section live inside a colored Jira panel?
- `info` (blue), `note` (yellow), `warning` (orange), `tip` (green), `success` (green), `error` (red)

Just reply with mappings, e.g.:
- 'AC → info'
- 'Current Behavior → error, Expected Behavior → success, AC → info'
- 'none' if you don't use panels here

**Other Jira formatting** in this template?
- Status badges (colored pill labels)
- Checklists (interactive checkboxes — usually `[ ]` syntax)
- Code blocks with specific languages
- Tables for any section
- Smart links to other tickets
- @mentions
- Anything else?"
---

For each panel mapping, add to the template:
```
<!-- ADF: wrap in a panel node with panelType: "{type}" -->
{section content}
<!-- /ADF panel -->
```

For other formatting, add a comment above the section describing what to apply:
```
<!-- ADF: render as a checklist (taskList node) -->
```

Show the updated template and ask: "Looks right? Continue to next?"

## Phase 11: Validation

For each finished template, generate ONE sample ticket using fake-but-plausible context. Show all samples to the user:

"Here's a sample ticket built from each template using fake context. Quick sanity check — does each one read like something you'd actually write?

[show each sample]

Anything that feels off? I can fix it now or you can edit the template files later."

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
