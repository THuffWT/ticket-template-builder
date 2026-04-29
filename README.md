# Ticket Template Builder

Build your own personal Jira ticket templates from the tickets you've already written. Your AI assistant analyzes your past tickets, finds your patterns, and generates reusable templates so future tickets stay consistent — and your AI can write them for you.

Works with **Claude Code**, **Cursor**, and **Codex**.

---

## What you need before installing

- **The Atlassian MCP set up in your AI tool**, connected to your Jira account.

If you don't have it yet, no problem — the skill will walk you through the setup the first time you run it.

---

## Install (1 minute)

Open your terminal and paste this:

```bash
curl -fsSL https://raw.githubusercontent.com/THuffWT/ticket-template-builder/main/install.sh | bash
```

The installer will ask which AI tool you're using (Claude Code, Cursor, or Codex), then put the skill in the right place automatically.

**Restart your AI tool** after installing, then type `/ticket-template-builder` in a chat to start.

---

## How to use it

1. Open a chat in your AI tool
2. Type: `/ticket-template-builder`
3. Answer the questions it asks (which Jira project, which folder to save to, etc.)
4. Confirm the patterns it finds
5. Get your finished templates in the folder you chose

Takes about 20–40 minutes depending on how many tickets you have.

---

## What the skill does (high level)

1. **Setup** — checks your Atlassian MCP, asks which Jira project and where to save things
2. **Pull** — downloads your tickets from Jira
3. **Organize** — sorts them into folders by issue type (Story, Bug, Spike, etc.)
4. **Pick** — asks which issue types you want templates for
5. **Analyze** — reads your tickets and finds the patterns in how you write them
6. **Build** — drafts a template for each pattern and shows it to you for feedback
7. **Format** — asks about Jira-specific formatting that doesn't show in plain text (panels, checklists, code blocks, etc.)
8. **Validate** — generates a sample ticket from each template so you can sanity check
9. **Save** — writes the final templates to your folder with a quick how-to

---

## How to use the templates after they're built

When you want your AI to write a new ticket, just paste a template into the chat and say:

> Using the [Template Name] template, write a ticket. Here's the context: [whatever your context is]

If you have the Atlassian MCP set up, your AI can also create the ticket directly in Jira from the template.

---

## Want to share your templates with your team?

Copy the templates folder into your team's docs (Notion, Confluence, GitHub, etc.) and anyone can use them — even if they don't have this skill installed.

---

## Questions?

Contact Tyler Huffman on Slack at @T-Huff.
