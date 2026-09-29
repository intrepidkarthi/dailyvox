#!/usr/bin/env bash
# What does THIS phone's speech recogniser actually have, and what does it do?
#
# Written after a OnePlus recorded nothing and reported nothing. The Android API
# cannot answer this from inside the app: isOnDeviceRecognitionAvailable() only
# parses a string out of the framework overlay --
#
#   ComponentName.unflattenFromString(
#       context.getString(R.string.config_defaultOnDeviceSpeechRecognitionService))
#   return componentName != null
#
# -- and never checks that the component exists, is installed, is enabled, or has
# a language pack. So it returns true on phones where nothing works, which is why
# the app's own error messages were guesses.
#
# This asks the platform directly. Run with the phone plugged in:
#
#     android/tools/recogniser-probe.sh
#
set -uo pipefail
ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"
PKG=com.dailyvox.app

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

"$ADB" get-state >/dev/null 2>&1 || { echo "No device. Enable USB debugging and plug it in."; exit 1; }
say "Device"
"$ADB" shell getprop ro.product.manufacturer | tr -d '\r' | sed 's/^/  make:    /'
"$ADB" shell getprop ro.product.model        | tr -d '\r' | sed 's/^/  model:   /'
"$ADB" shell getprop ro.build.version.release| tr -d '\r' | sed 's/^/  android: /'
"$ADB" shell getprop ro.build.version.sdk    | tr -d '\r' | sed 's/^/  api:     /'

say "Which recogniser the system has selected"
for k in voice_recognition_service speech_recognition_service; do
  v=$("$ADB" shell settings get secure $k 2>/dev/null | tr -d '\r')
  [ -n "$v" ] && echo "  $k = $v"
done

say "Is a RecognitionService actually installed and resolvable?"
"$ADB" shell cmd package query-services --brief -a android.speech.RecognitionService 2>/dev/null \
  | tr -d '\r' | grep -v '^$' | sed 's/^/  /' || echo "  (query-services unsupported on this API)"

say "Speech-related packages present, and whether they are ENABLED"
for p in com.google.android.tts com.google.android.as com.google.android.googlequicksearchbox; do
  state=$("$ADB" shell cmd package list packages -e "$p" 2>/dev/null | tr -d '\r')
  if [ -n "$state" ]; then echo "  ENABLED   $p"
  elif "$ADB" shell pm list packages "$p" 2>/dev/null | grep -q .; then echo "  DISABLED  $p   <-- installed but off"
  else echo "  ABSENT    $p"
  fi
done

say "DailyVox permissions actually granted"
"$ADB" shell dumpsys package $PKG 2>/dev/null | tr -d '\r' \
  | grep -E "android.permission.(RECORD_AUDIO|POST_NOTIFICATIONS)|health\.READ" \
  | sed 's/^ */  /' | sort -u

say "Now record one entry on the phone. Live recogniser log:"
echo "  (Ctrl-C when the attempt has finished)"
"$ADB" logcat -c
"$ADB" logcat -s DailyVoxSpeech:V SpeechRecognizer:V RecognitionService:V AndroidRuntime:E
