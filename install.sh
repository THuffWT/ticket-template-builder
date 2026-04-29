#!/usr/bin/env bash
#
# Ticket Template Builder — installer
# Works for Claude Code, Cursor, and Codex.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/THuffWT/ticket-template-builder/main/install.sh | bash
#
# Or with a specific platform argument:
#   curl -fsSL <url>/install.sh | bash -s -- claude-code
#   curl -fsSL <url>/install.sh | bash -s -- cursor
#   curl -fsSL <url>/install.sh | bash -s -- codex

set -e

REPO_RAW_URL="https://raw.githubusercontent.com/THuffWT/ticket-template-builder/main"
SKILL_NAME="ticket-template-builder"

echo ""
echo "  Ticket Template Builder — installer"
echo "  -----------------------------------"
echo ""

# Detect or accept a platform argument
PLATFORM="${1:-}"

if [ -z "$PLATFORM" ]; then
  echo "  Which AI tool are you using?"
  echo ""
  echo "    1) Claude Code"
  echo "    2) Cursor"
  echo "    3) Codex"
  echo ""
  read -rp "  Enter 1, 2, or 3: " choice
  case "$choice" in
    1) PLATFORM="claude-code" ;;
    2) PLATFORM="cursor" ;;
    3) PLATFORM="codex" ;;
    *) echo "  Invalid choice."; exit 1 ;;
  esac
fi

# Pick install path per platform
case "$PLATFORM" in
  claude-code) INSTALL_DIR="$HOME/.claude/skills/$SKILL_NAME" ;;
  cursor)      INSTALL_DIR="$HOME/.cursor/skills/$SKILL_NAME" ;;
  codex)       INSTALL_DIR="$HOME/.agents/skills/$SKILL_NAME" ;;
  *) echo "  Unknown platform: $PLATFORM"; exit 1 ;;
esac

echo ""
echo "  Installing to: $INSTALL_DIR"
echo ""

mkdir -p "$INSTALL_DIR"

# Download the skill files
curl -fsSL "$REPO_RAW_URL/SKILL.md" -o "$INSTALL_DIR/SKILL.md"
curl -fsSL "$REPO_RAW_URL/config.yaml.example" -o "$INSTALL_DIR/config.yaml.example"

echo "  ✓ Installed successfully!"
echo ""
echo "  Next steps:"
echo "    1) Make sure the Atlassian MCP is set up in your AI tool"
echo "       (the skill will help you with this if it isn't)"
echo "    2) Restart your AI tool"
echo "    3) In a chat, type:  /ticket-template-builder"
echo ""
echo "  That's it. The skill will walk you through the rest."
echo ""
