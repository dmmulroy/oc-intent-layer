#!/bin/bash
set -e

# Intent Layer Tools Installer for OpenCode
# Installs skills and commands globally to ~/.config/opencode/

REPO_URL="https://github.com/sst/oc-intent-layer"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
INSTALL_DIR="$CONFIG_DIR/oc-intent-layer"

echo "Intent Layer Tools for OpenCode"
echo "================================"
echo ""

# Check if OpenCode config directory exists
if [ ! -d "$CONFIG_DIR" ]; then
  echo "Creating OpenCode config directory: $CONFIG_DIR"
  mkdir -p "$CONFIG_DIR"
fi

# Check for existing installation
if [ -d "$INSTALL_DIR" ]; then
  echo "Existing installation found at $INSTALL_DIR"
  read -p "Update to latest? [Y/n] " -r
  if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Aborted."
    exit 0
  fi
  echo "Updating..."
  cd "$INSTALL_DIR"
  git pull --ff-only
else
  echo "Installing to $INSTALL_DIR"
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

# Create skill and command directories
mkdir -p "$CONFIG_DIR/skill"
mkdir -p "$CONFIG_DIR/command"

# Symlink skills
echo ""
echo "Linking skills..."
for skill_dir in "$INSTALL_DIR/.opencode/skill/"*/; do
  skill_name=$(basename "$skill_dir")
  target="$CONFIG_DIR/skill/$skill_name"
  if [ -L "$target" ] || [ -d "$target" ]; then
    rm -rf "$target"
  fi
  ln -s "$skill_dir" "$target"
  echo "  @$skill_name"
done

# Symlink commands
echo ""
echo "Linking commands..."
for cmd_file in "$INSTALL_DIR/.opencode/command/"*.md; do
  cmd_name=$(basename "$cmd_file" .md)
  target="$CONFIG_DIR/command/$cmd_name.md"
  if [ -L "$target" ] || [ -f "$target" ]; then
    rm -f "$target"
  fi
  ln -s "$cmd_file" "$target"
  echo "  /$cmd_name"
done

echo ""
echo "Installation complete!"
echo ""
echo "Available commands:"
echo "  /intent-init      Bootstrap intent layer for a project"
echo "  /intent-capture   Capture single intent node"
echo "  /intent-sync      Sync nodes after code changes"
echo ""
echo "Get started:"
echo "  cd your-project"
echo "  opencode"
echo "  /intent-init"
