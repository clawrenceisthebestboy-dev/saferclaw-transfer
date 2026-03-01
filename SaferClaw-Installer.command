#!/bin/bash
clear
echo ""
echo "  🦞 SaferClaw Transfer — Installer"
echo "  =================================="
echo ""
echo "  This will install Homebrew and Node.js on your Mac."
echo "  You'll be asked for your Mac password once — that's normal."
echo ""
read -p "  Press ENTER to start..." 

echo ""

# Homebrew
if ! command -v brew &>/dev/null && ! [ -f /opt/homebrew/bin/brew ]; then
  echo "  🍺 Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
  echo "  ✅ Homebrew installed!"
else
  eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
  echo "  ✅ Homebrew already installed"
fi

echo ""

# Node.js
if ! command -v node &>/dev/null; then
  echo "  📦 Installing Node.js..."
  brew install node
  echo "  ✅ Node.js installed!"
else
  echo "  ✅ Node.js $(node --version) already installed"
fi

echo ""
echo "  ✅ All done! Now open SaferClaw Transfer and click Restore."
echo ""
read -p "  Press ENTER to close..."
