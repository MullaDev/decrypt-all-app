$ cat > msy-decryptor.sh <<'EOF'
#!/usr/bin/env bash
# msy-decryptor.sh
# Decrypt moodlMSY.txt files in ANY folder
# Usage:
#   ./msy-decryptor.sh                 # auto-find in Download, Documents, etc.
#   ./msy-decryptor.sh /sdcard/Download myconfig.json
#   ./msy-decryptor.sh /path/to/moodlMSY.txt
# Notes:
#   - Requires: openssl, perl, base64
#   - Edit PASSWORD below or use: MSY_PASSWORD="YourPass" ./msy-decryptor.sh

set -euo pipefail

# -------------------- CONFIG --------------------
PASSWORD="${MSY_PASSWORD:-HexXVPNPass}"
IV="${MSY_IV:-0123456789ABCDEF1032547698BADCFE}"
RECURSIVE_SEARCH=false
# ------------------------------------------------

ARG="${1:-}"
OUT="${2:-decrypted_msy.json}"

DEFAULT_PATHS=(
  "$HOME/storage/shared/Download"
  "$HOME/storage/shared/Documents"
  "$HOME/storage/shared/DCIM"
  "$HOME/storage/shared"
  "$HOME"
)

find_moodl_file() {
  local arg="$1"
  if [ -n "$arg" ]; then
    if [ -f "$arg" ]; then
      printf '%s' "$arg"; return 0
    fi
    if [ -d "$arg" ]; then
      if [ "$RECURSIVE_SEARCH" = true ]; then
        find "$arg" -type f -iname "moodlMSY.txt" -print -quit 2>/dev/null || true
      else
        for f in "$arg"/moodlMSY.txt "$arg"/MoodlMSY.txt "$arg"/moodlmsy.txt; do
          [ -f "$f" ] && { printf '%s' "$f"; return 0; }
        done
      fi
      return 0
    fi
    if [ -f "./$arg" ]; then
      printf '%s' "./$arg"; return 0
    fi
  fi

  for p in "${DEFAULT_PATHS[@]}"; do
    for f in "$p"/moodlMSY.txt "$p"/MoodlMSY.txt "$p"/moodlmsy.txt; do
      [ -f "$f" ] && { printf '%s' "$f"; return 0; }
    done
  done

  find "$HOME/storage/shared" -type f -iname "moodlMSY.txt" -print -quit 2>/dev/null || true
}

derive_key_hex() {
  printf "%s" "$PASSWORD" | openssl dgst -sha256 -binary | xxd -p -c 256
}

decrypt_val() {
  local val="$1"
  if ! printf '%s' "$val" | grep -Eq '^[A-Za-z0-9+/]+={0,2}$'; then
    printf '%s' "$val"; return 0
  fi

  local decoded key_hex iv_hex tmpout
  decoded=$(printf '%s' "$val" | base64 -d 2>/dev/null) || { printf '%s' "$val"; return 0; }
  key_hex="$(derive_key_hex)"
  iv_hex="$IV"

  # Try with padding
  tmpout=$(printf '%s' "$decoded" | openssl enc -aes-256-cbc -d -K "$key_hex" -iv "$iv_hex" 2>/dev/null || true)
  if [ -n "$tmpout" ]; then
    printf '%s' "$tmpout" | perl -pe 's/[\x00\r\n]+$//'
    return 0
  fi

  # Try nopad + strip PKCS#7
  tmpout=$(printf '%s' "$decoded" | openssl enc -aes-256-cbc -d -K "$key_hex" -iv "$iv_hex" -nopad 2>/dev/null || true)
  if [ -n "$tmpout" ]; then
    printf '%s' "$tmpout" | perl -pe 's/[\x01-\x10].*$//s' | perl -pe 's/[\x00-\x1F\x7F-\xFF]//g'
    return 0
  fi

  printf '%s' "$val"
}

# MAIN
echo ""
echo "  RWANDA FULL DECRYPTOR v1.0"
echo "  Current Time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "  Country: RWANDA"
echo ""

MOODL_FILE="$(find_moodl_file "$ARG")"

if [ -z "$MOODL_FILE" ] || [ ! -f "$MOODL_FILE" ]; then
  echo "Error: moodlMSY.txt not found!"
  echo "Put it in Download or run: ./msy-decryptor.sh /path/to/moodlMSY.txt"
  exit 1
fi

echo "Found: $MOODL_FILE"
echo "Decrypting → $OUT"

# CLEAN EXTRACT: Remove null bytes, extract only Base64 values
tr -d '\0' < "$MOODL_FILE" | tr -d '\n\r' | grep -o '"[^"]\{1,\}":"[^"]\{1,\}"' | grep -E '=+$' | sed 's/":"/\t/; s/"//g' > .pairs.txt

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
  dec="$(decrypt_val "$val")"

  if [ "$key" = "Name" ]; then
    if [ "$server_open" = true ]; then
      printf '    },\n' >> "$OUT"
    fi
    printf '    {\n' >> "$OUT"
    printf '      "Name": "%s",\n' "$(printf '%s' "$dec" | sed 's/"/\\"/g')" >> "$OUT"
    server_open=true
    server_count=$((server_count+1))
    continue
  fi

  if [ "$server_open" != true ]; then continue; fi

  case "$key" in
    SSHHost|WebServer)       jsonkey="Host" ;;
    Username|WebUser)        jsonkey="User" ;;
    Password|WebPass)        jsonkey="Pass" ;;
    vhost|Sni)               jsonkey="SNI" ;;
    SSLPort)                 jsonkey="SSL" ;;
    ProxyPort)               jsonkey="Proxy" ;;
    UDPServer)               jsonkey="UDP" ;;
    Info)                    jsonkey="Info" ;;
    *)                       jsonkey="$key" ;;
  esac

  if [ "$jsonkey" = "SSL" ] || [ "$jsonkey" = "Proxy" ]; then
    num=$(printf '%s' "$dec" | tr -cd '0-9')
    [ -n "$num" ] && printf '      "%s": %s,\n' "$jsonkey" "$num" >> "$OUT" || \
      printf '      "%s": "%s",\n' "$jsonkey" "$(printf '%s' "$dec" | sed 's/"/\\"/g')" >> "$OUT"
  else
    printf '      "%s": "%s",\n' "$jsonkey" "$(printf '%s' "$dec" | sed 's/"/\\"/g')" >> "$OUT"
  fi

done < .pairs.txt

if [ "$server_open" = true ]; then
  printf '    }\n' >> "$OUT"
fi

printf '  ]\n}\n' >> "$OUT"

# Remove trailing commas
sed -i '$ s/,$//' "$OUT"
sed -i '/},$/ s/,$//' "$OUT"

rm -f .pairs.txt
echo ""
echo "RWANDA WINS! FULLY DECRYPTED → $OUT"
echo "Saved: $(pwd)/$OUT"
echo "Connect: 154.26.139.81 | msyfree | msyfree | msyfree.com"
EOF