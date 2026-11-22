#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> [1/3] Checking Fedora Easy Effects and LV2 plugin packages..."
sudo dnf install -y easyeffects lsp-plugins-lv2 calf lv2-zam-plugins lv2-mdala-plugins rnnoise

echo "==> [2/3] Preparing Easy Effects preset directories and copying presets..."
mkdir -p ~/.local/share/easyeffects/output ~/.config/easyeffects/output ~/.local/share/easyeffects/input ~/.config/easyeffects/input

if [[ -f "${SCRIPT_DIR}/Clean-Mic-RNNoise.json" ]]; then
    cp -f "${SCRIPT_DIR}/Clean-Mic-RNNoise.json" ~/.local/share/easyeffects/input/Clean-Mic-RNNoise.json
    cp -f "${SCRIPT_DIR}/Clean-Mic-RNNoise.json" ~/.config/easyeffects/input/Clean-Mic-RNNoise.json
    echo "    ✓ Clean-Mic-RNNoise.json (Microphone Noise Suppression) installed."
fi

if [[ -f "${SCRIPT_DIR}/CMF-Buds-2-Clarity.json" ]]; then
    cp -f "${SCRIPT_DIR}/CMF-Buds-2-Clarity.json" ~/.local/share/easyeffects/output/CMF-Buds-2-Clarity.json
    cp -f "${SCRIPT_DIR}/CMF-Buds-2-Clarity.json" ~/.config/easyeffects/output/CMF-Buds-2-Clarity.json
    echo "    ✓ CMF-Buds-2-Clarity.json (CMF Buds 2 - Music & Balanced) installed."
fi

if [[ -f "${SCRIPT_DIR}/CMF-Buds-2-Cinema-Game.json" ]]; then
    cp -f "${SCRIPT_DIR}/CMF-Buds-2-Cinema-Game.json" ~/.local/share/easyeffects/output/CMF-Buds-2-Cinema-Game.json
    cp -f "${SCRIPT_DIR}/CMF-Buds-2-Cinema-Game.json" ~/.config/easyeffects/output/CMF-Buds-2-Cinema-Game.json
    echo "    ✓ CMF-Buds-2-Cinema-Game.json (CMF Buds 2 - Cinema & Gaming Wide Stage) installed."
fi

if [[ -f "${SCRIPT_DIR}/Laptop-Speaker-Boost.json" ]]; then
    cp -f "${SCRIPT_DIR}/Laptop-Speaker-Boost.json" ~/.local/share/easyeffects/output/Laptop-Speaker-Boost.json
    cp -f "${SCRIPT_DIR}/Laptop-Speaker-Boost.json" ~/.config/easyeffects/output/Laptop-Speaker-Boost.json
    echo "    ✓ Laptop-Speaker-Boost.json (Laptop Speaker Booster) installed."
fi

echo "==> [3/3] Configuring background service (Autostart)..."
mkdir -p ~/.config/autostart
EE_SERVICE_EXEC="easyeffects --gapplication-service"
EE_HELP_OUT="$(easyeffects --help 2>&1 || true)"
if grep -q -- '--service-mode' <<< "$EE_HELP_OUT"; then
    EE_SERVICE_EXEC="easyeffects --service-mode --hide-window"
fi
cat << EOF > ~/.config/autostart/com.github.wwmm.easyeffects.desktop
[Desktop Entry]
Name=Easy Effects
Comment=Easy Effects Service
Exec=${EE_SERVICE_EXEC}
Icon=com.github.wwmm.easyeffects
StartupNotify=false
Terminal=false
Type=Application
EOF

echo ""
echo "✅ All presets installed successfully!"
