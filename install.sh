#!/bin/bash
set -e

# Intent Layer Tools Installer for OpenCode
# Installs only /intent-init command - other components install on first run

REPO_URL="https://github.com/dmmulroy/oc-intent-layer"
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

# Create command directory
mkdir -p "$CONFIG_DIR/command"

# Only symlink intent-init command
# Other skills and commands are installed during /intent-init execution
echo ""
echo "Linking /intent-init command..."
cmd_file="$INSTALL_DIR/.opencode/command/intent-init.md"
cmd_name="intent-init"
target="$CONFIG_DIR/command/$cmd_name.md"
if [ -L "$target" ] || [ -f "$target" ]; then
  rm -f "$target"
fi
ln -s "$cmd_file" "$target"
echo "  /$cmd_name"

echo ""
echo "Installation complete!"
echo ""
echo "Get started:"
echo "  cd your-project"
echo "  opencode"
echo "  /intent-init"
echo ""
echo "The /intent-init command will install additional components"
echo "(skills, other commands, tiktoken) on first run."
