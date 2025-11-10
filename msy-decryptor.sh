#!/usr/bin/env bash
# msy-decryptor.sh
# Decrypt moodlMSY.txt files inside a selected directory (or a direct file path).
# Usage:
#   ./msy-decryptor.sh [directory-or-file] [output.json]
# Examples:
#   ./msy-decryptor.sh                 # auto-find in ~/storage/shared/Download
#   ./msy-decryptor.sh /sdcard/Download myconfig.json
#   ./msy-decryptor.sh /path/to/moodlMSY.txt out.json
# Notes:
#   - Requires: openssl, perl, base64 (standard)
#   - Edit PASSWORD below to set your decryption password (or set env var MSY_PASSWORD)

set -euo pipefail

# -------------------- CONFIG --------------------
# Default PASSWORD (change as needed). You may override by exporting MSY_PASSWORD env var.
PASSWORD="${MSY_PASSWORD:-HexXVPNPass}"
# Default IV (32 hex chars -> 16 bytes). Change if your app used a different IV.
IV="${MSY_IV:-0123456789ABCDEF1032547698BADCFE}"
# Whether to search directories recursively when you pass a directory (true/false)
RECURSIVE_SEARCH=false
# ------------------------------------------------

# Resolve input and output arguments
ARG="${1:-}"   # directory or file path (optional)
OUT="${2:-decrypted_msy.json}"

# default search directories (Termux / Android common)
DEFAULT_PATHS=(
  "$HOME/storage/shared/Download"
  "$HOME/storage/shared/Documents"
  "$HOME/storage/shared/DCIM"
  "$HOME/storage/shared"
  "$HOME"
)

# Helper: find moodlMSY.txt given ARG or defaults
find_moodl_file() {
  local arg="$1"
  if [ -n "$arg" ]; then
    # If user passed a file path that exists and is a file -> use it
    if [ -f "$arg" ]; then
      printf '%s' "$arg"
      return 0
    fi
    # If user passed a directory -> look for moodlMSY.txt inside
    if [ -d "$arg" ]; then
      if [ "$RECURSIVE_SEARCH" = true ]; then
        find "$arg" -type f -iname "moodlMSY.txt" -print -quit 2>/dev/null || true
      else
        # non-recursive
        if [ -f "$arg/moodlMSY.txt" ]; then
          printf '%s' "$arg/moodlMSY.txt"
        else
          # try direct files in the directory (case-insensitive)
          for f in "$arg"/moodlMSY.txt "$arg"/MoodlMSY.txt "$arg"/moodlmsy.txt; do
            [ -f "$f" ] && { printf '%s' "$f"; return 0; }
          done
        fi
      fi
      return 0
    fi
    # If arg doesn't exist -> treat as filename in current dir
    if [ -f "./$arg" ]; then
      printf '%s' "./$arg"
      return 0
    fi
  fi

  # No arg or nothing found — search defaults
  for p in "${DEFAULT_PATHS[@]}"; do
    # check non-recursive
    if [ -f "$p/moodlMSY.txt" ]; then
      printf '%s' "$p/moodlMSY.txt"
      return 0
    fi
    # try case variants
    for f in "$p"/moodlMSY.txt "$p"/MoodlMSY.txt "$p"/moodlmsy.txt; do
      [ -f "$f" ] && { printf '%s' "$f"; return 0; }
    done
  done

  # Last resort: search under $HOME/storage/shared (recursively)
  find "$HOME/storage/shared" -type f -iname "moodlMSY.txt" -print -quit 2>/dev/null || true
}

# derive KEY hex from password
derive_key_hex() {
  printf "%s" "$PASSWORD" | openssl dgst -sha256 -binary | xxd -p -c 256
}

# decrypt helper: input = base64 string; outputs plaintext (or original value if not decryptable)
decrypt_val() {
  local val="$1"
  # quick base64 sanity check
  if ! printf '%s' "$val" | grep -Eq '^[A-Za-z0-9+/]+={0,2}$'; then
    printf '%s' "$val"
    return 0
  fi

  # base64-decode
  local decoded
  decoded=$(printf '%s' "$val" | base64 -d 2>/dev/null) || { printf '%s' "$val"; return 0; }

  # try openssl with default padding
  local key_hex iv_hex tmpout
  key_hex="$(derive_key_hex)"
  iv_hex="$IV"

  tmpout=$(printf '%s' "$decoded" | openssl enc -aes-256-cbc -d -K "$key_hex" -iv "$iv_hex" 2>/dev/null || true)
  if [ -n "$tmpout" ]; then
    # strip trailing nulls/newlines
    printf '%s' "$tmpout" | perl -pe 's/[\x00\r\n]+$//'
    return 0
  fi

  # fallback: openssl nopad then strip pkcs#7 bytes (1..16)
  tmpout=$(printf '%s' "$decoded" | openssl enc -aes-256-cbc -d -K "$key_hex" -iv "$iv_hex" -nopad 2>/dev/null || true)
  if [ -n "$tmpout" ]; then
    printf '%s' "$tmpout" | perl -pe 's/[\x01-\x10].*$//s' | perl -pe 's/[\x00\r\n]+$//'
    return 0
  fi

  # if all fails, return original base64 string
  printf '%s' "$val"
}

# MAIN
echo ""
echo "  RWANDA FULL DECRYPTOR v1.0"
echo "  Current Time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

MOODL_FILE="$(find_moodl_file "$ARG")"

if [ -z "$MOODL_FILE" ] || [ ! -f "$MOODL_FILE" ]; then
  echo "Error: moodlMSY.txt not found in given path or default locations."
  echo "Pass a directory containing moodlMSY.txt or a direct file path."
  echo "Usage: $0 [directory-or-file] [output.json]"
  exit 1
fi

echo "Found: $MOODL_FILE"
echo "Decrypting → $OUT"
TMP_PAIRS="$(mktemp --suffix .msypairs 2>/dev/null || mktemp)"

# Extract all "key":"value" pairs robustly (handles newlines in file)
# Uses perl to parse the whole file as one string and capture pairs
perl -0777 -ne 'while(/"([^"]+)"\s*:\s*"([^"]*)"/g){ print "$1\t$2\n" }' "$MOODL_FILE" > "$TMP_PAIRS"

# Build JSON output
cat > "$OUT" <<EOF
{
  "Version": "1.0",
  "Country": "RWANDA",
  "Updated": "$(date '+%Y-%m-%d %H:%M:%S %Z')",
  "BestServer": {
    "Host": "154.26.139.81",
    "Port": 22,
    "User": "msyfree",
    "Pass": "msyfree",
    "SNI": "msyfree.com",
    "SSL": 443,
    "UDP": 7300
  },
  "Servers": [
EOF

server_open=false
server_count=0

while IFS=$'\t' read -r key val; do
  # decrypt val (if base64+AES)
  dec="$(decrypt_val "$val")"

  if [ "$key" = "Name" ]; then
    # close previous server object (if open)
    if [ "$server_open" = true ]; then
      # remove trailing comma in previous object by appending closing and letting post-process fix
      printf '    },\n' >> "$OUT"
    fi
    printf '    {\n' >> "$OUT"
    printf '      "Name": "%s",' "$(printf '%s' "$dec" | sed 's/"/\\"/g')" >> "$OUT"
    printf '\n' >> "$OUT"
    server_open=true
    server_count=$((server_count+1))
    continue
  fi

  # skip adding fields before first Name
  if [ "$server_open" != true ]; then
    continue
  fi

  # map some keys
  case "$key" in
    SSHHost|WebServer) jsonkey="Host" ;;
    Username|WebUser|DNSUsername) jsonkey="User" ;;
    Password|WebPass|DNSPassword) jsonkey="Pass" ;;
    vhost|Sni|v2Sni) jsonkey="SNI" ;;
    SSLPort|vport) jsonkey="SSL" ;;
    ProxyPort) jsonkey="Proxy" ;;
    UDPServer) jsonkey="UDP" ;;
    Info) jsonkey="Info" ;;
    *) jsonkey="$key" ;;
  esac

  if [ "$jsonkey" = "SSL" ] || [ "$jsonkey" = "Proxy" ]; then
    num="$(printf '%s' "$dec" | tr -cd '0-9')"
    if [ -n "$num" ]; then
      printf '      "%s": %s,' "$jsonkey" "$num" >> "$OUT"
    else
      printf '      "%s": "%s",' "$jsonkey" "$(printf '%s' "$dec" | sed 's/"/\\"/g')" >> "$OUT"
    fi
  else
    printf '      "%s": "%s",' "$jsonkey" "$(printf '%s' "$dec" | sed 's/"/\\"/g')" >> "$OUT"
  fi
  printf '\n' >> "$OUT"

done < "$TMP_PAIRS"

# close last server object properly (if any)
if [ "$server_open" = true ]; then
  printf '    }\n' >> "$OUT"
fi

# close JSON
printf '  ]\n}\n' >> "$OUT"

# Post-process to remove trailing commas before closing braces
tmp_clean="$(mktemp --suffix .clean 2>/dev/null || mktemp)"
awk '
  { lines[NR]=$0 }
  END {
    for(i=1;i<=NR;i++){
      if(i<NR && lines[i] ~ /,[[:space:]]*$/ && lines[i+1] ~ /^[[:space:]]*},[[:space:]]*$/){
        sub(/,[[:space:]]*$/,"",lines[i])
      }
      if(i<NR && lines[i] ~ /,[[:space:]]*$/ && lines[i+1] ~ /^[[:space:]]*}[[:space:]]*$/){
        sub(/,[[:space:]]*$/,"",lines[i])
      }
      print lines[i]
    }
  }
' "$OUT" > "$tmp_clean" && mv "$tmp_clean" "$OUT"

# Cleanup
rm -f "$TMP_PAIRS"
echo ""
echo "RWANDA WINS! FULLY DECRYPTED → $OUT"
echo "File saved in: $(pwd)/$OUT"
echo "Import & Connect to: 154.26.139.81 | msyfree | msyfree | msyfree.com"
exit 0