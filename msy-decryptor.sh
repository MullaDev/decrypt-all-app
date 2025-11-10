#!/usr/bin/env bash
set -euo pipefail

PASSWORD="${MSY_PASSWORD:-HexXVPNPass}"
IV="${MSY_IV:-0123456789ABCDEF1032547698BADCFE}"

ARG="${1:-}"
OUT="${2:-decrypted_msy.json}"

DEFAULT_PATHS=(
  "$HOME/storage/shared/Download"
  "$HOME/storage/shared/Documents"
  "$HOME/storage/shared"
  "$HOME"
)

find_moodl_file() {
  local arg="$1"
  if [ -n "$arg" ]; then
    [ -f "$arg" ] && echo "$arg" && return 0
    [ -d "$arg" ] && find "$arg" -maxdepth 1 -iname "moodlMSY.txt" -print -quit 2>/dev/null || true
    [ -f "./$arg" ] && echo "./$arg" && return 0
  fi
  for p in "${DEFAULT_PATHS[@]}"; do
    find "$p" -maxdepth 1 -iname "moodlMSY.txt" -print -quit 2>/dev/null || true
  done
}

derive_key_hex() {
  printf "%s" "$PASSWORD" | openssl dgst -sha256 -binary | xxd -p -c 256
}

decrypt_val() {
  local val="$1"
  # Only process if it's valid Base64 ending with =
  printf '%s' "$val" | grep -Eq '^[A-Za-z0-9+/]+={0,2}$' || { printf '%s' "$val"; return 0; }

  local decoded key_hex iv_hex out
  decoded=$(printf '%s' "$val" | base64 -d 2>/dev/null) || { printf '%s' "$val"; return 0; }
  key_hex="$(derive_key_hex)"
  iv_hex="$IV"

  # Try decryption with padding removal
  out=$(printf '%s' "$decoded" | openssl enc -aes-256-cbc -d -K "$key_hex" -iv "$iv_hex" -nopad 2>/dev/null || true)
  [ -n "$out" ] || { printf '%s' "$val"; return 0; }

  # Strip PKCS#7 padding + nulls + non-printable
  printf '%s' "$out" | perl -pe 's/[\x01-\x10].*$//s; s/[\x00-\x1F\x7F-\xFF]//g'
}

# MAIN
echo ""
echo "  RWANDA FULL DECRYPTOR v3.0"
echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "  V2RAY + WG + PAYLOAD + SNI → 100% DECRYPTED"
echo ""

MOODL_FILE="$(find_moodl_file "$ARG")"
[ -z "$MOODL_FILE" ] || [ ! -f "$MOODL_FILE" ] && {
  echo "Error: moodlMSY.txt not found!"
  echo "Usage: $0 [path] [output.json]"
  exit 1
}

echo "Found: $MOODL_FILE"
echo "Decrypting → $OUT"

# Extract ALL "key":"value" pairs (even multi-line), filter encrypted only
tr -d '\0' < "$MOODL_FILE" | \
  perl -0777 -ne 'while(/"([^"]+)"\s*:\s*"([^"]*)"/g){ print "$1\t$2\n" }' | \
  grep -E $'\t.*=+$' > .pairs.txt

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
while IFS=$'\t' read -r key val; do
  dec="$(decrypt_val "$val")"

  if [ "$key" = "Name" ]; then
    [ "$server_open" = true ] && printf '    },\n' >> "$OUT"
    printf '    {\n' >> "$OUT"
    printf '      "Name": "%s",\n' "$(printf '%s' "$dec" | sed 's/"/\\"/g')" >> "$OUT"
    server_open=true
    continue
  fi
  [ "$server_open" != true ] && continue

  # Map keys
  case "$key" in
    SSHHost|WebServer)            k="Host" ;;
    Username|WebUser|DNSUsername) k="User" ;;
    Password|WebPass|DNSPassword) k="Pass" ;;
    vhost|Sni|v2Sni)              k="SNI" ;;
    SSLPort|vport)                k="SSL" ;;
    ProxyPort)                    k="Proxy" ;;
    UDPServer)                    k="UDP" ;;
    Info)                         k="Info" ;;
    v2rayjson|wgConf|Payload|DNSHost) k="$key" ;;
    *)                            k="$key" ;;
  esac

  # Special handling for numbers
  if [ "$k" = "SSL" ] || [ "$k" = "Proxy" ]; then
    num=$(printf '%s' "$dec" | tr -cd '0-9')
    [ -n "$num" ] && printf '      "%s": %s,\n' "$k" "$num" >> "$OUT" || \
      printf '      "%s": "%s",\n' "$k" "$(printf '%s' "$dec" | sed 's/"/\\"/g')" >> "$OUT"
  else
    printf '      "%s": "%s",\n' "$k" "$(printf '%s' "$dec" | sed 's/"/\\"/g')" >> "$OUT"
  fi
done < .pairs.txt

[ "$server_open" = true ] && printf '    }\n' >> "$OUT"
printf '  ]\n}\n' >> "$OUT"

# Fix trailing commas
sed -i '$ s/,$//' "$OUT"
sed -i '/},$/ s/,$//' "$OUT"

rm -f .pairs.txt

echo ""
echo "RWANDA WINS! FULLY DECRYPTED → $OUT"
echo "V2RAY JSON, WG, PAYLOAD, SNI → CLEAN"
echo "Saved: $(pwd)/$OUT"
echo "Connect: 154.26.139.81 | msyfree | msyfree | msyfree.com"
EOF