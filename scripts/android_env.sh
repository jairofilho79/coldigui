#!/usr/bin/env bash
# Carrega ANDROID_HOME, Java e adb no PATH desta sessão do terminal.
#
# Uso:
#   source scripts/android_env.sh
#   adb devices
#
# Sem `set -u`: este script é feito para `source` no zsh; nounset quebra o prompt do Cursor (RPROMPT).

if [[ -d "$HOME/Library/Android/sdk" ]]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
fi

if [[ -z "${JAVA_HOME:-}" && -d "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]]; then
  export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
  export PATH="$JAVA_HOME/bin:$PATH"
fi
