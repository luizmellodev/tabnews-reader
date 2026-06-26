#!/bin/bash
# Envia push de teste pro simulador iOS (sem Firebase).
# Uso: ./Scripts/test-push-simulator.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD="$SCRIPT_DIR/tabnews-test-push.apns"
BUNDLE_ID="dev.luizmello.newtabnews"

if ! xcrun simctl list devices booted | grep -q Booted; then
  echo "❌ Nenhum simulador ligado. Abra um no Xcode e rode o app primeiro."
  exit 1
fi

echo "📲 Enviando push para $BUNDLE_ID no simulador booted..."
xcrun simctl push booted "$BUNDLE_ID" "$PAYLOAD"
echo "✅ Enviado! Olhe o simulador e o console do Xcode por 📬 Push remoto recebido"
