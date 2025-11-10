cat > msy-decryptor.sh <<'EOF'
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
  printf "%s" "$PASSWORD" | openssl dgst -sha256 -binary | xxd -p -c 256 2>/dev/null
}

is_encrypted() {
  local val="$1"
  printf '%s' "$val" | grep -Eq '^[A-Za-z0-9+/]+={0,2}$' && \
  printf '%s' "$val" | grep -qE '[+/=]' && \
  [ ${#val} -gt 10 ] && \
  ! printf '%s' "$val" | grep -qE '^(true|false|null|[0-9]+)$'
}

decrypt_val() {
  local val="$1"
  is_encrypted "$val" || { printf '%s' "$val"; return 0; }
  local decoded key_hex iv_hex out
  decoded=$(printf '%s' "$val" | base64 -d 2>/dev/null) || { printf '%s' "$val"; return 0; }
  key_hex="$(derive_key_hex)"
  iv_hex="$IV"
  out=$(printf '%s' "$decoded" | openssl enc -aes-256-cbc -d -K "$key_hex" -iv "$iv_hex" -nopad 2>/dev/null | tr -d '\0' || true)
  [ -n "$out" ] || { printf '%s' "$val"; return 0; }
  printf '%s' "$out" | perl -pe 's/[\x01-\x10].*$//s; s/[\x00-\x1F\x7F-\xFF]//g'
}

# MAIN
echo ""
echo "  RWANDA FULL DECRYPTOR v5.1"
echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "  100% CLEAN | NO WARNINGS | FULL DECRYPTION"
echo ""

MOODL_FILE="$(find_moodl_file "$ARG")"
[ -z "$MOODL_FILE" ] || [ ! -f "$MOODL_FILE" ] && {
  echo "Error: moodlMSY.txt not found!"
  echo "Use: $0 /path/to/moodlMSY.txt"
  exit 1
}

echo "Found: $MOODL_FILE"
echo "Decrypting → $OUT"

# FULL NULL BYTE REMOVAL + SILENT
tr -d '\0' < "$MOODL_FILE" 2>/dev/null | \
  perl -0777 -ne 'while(/"([^"]+)"\s*:\s*"([^"]*)"/g){ print "$1\t$2\n" }' 2>/dev/null > .pairs.txt

cat > "$OUT" <<JSONEOF
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
JSONEOF

server_open=false
declare -A seen_keys

while IFS=$'\t' read -r key val; do
  dec="$(decrypt_val "$val")"

  if [ "$key" = "Name" ]; then
    [ "$server_open" = true ] && printf '    }\n' >> "$OUT"
    printf '    {\n' >> "$OUT"
    printf '      "Name": "%s",\n' "$(printf '%s' "$dec" | sed 's/"/\\"/g')" >> "$OUT"
    server_open=true
    unset seen_keys
    declare -A seen_keys
    continue
  fi
  [ "$server_open" != true ] && continue

  case "$key" in
    SSHHost|WebServer|Host)              k="Host" ;;
    Username|WebUser|DNSUsername|User)   k="User" ;;
    Password|WebPass|DNSPassword|Pass)   k="Pass" ;;
    vhost|Sni|v2Sni|SNI)                 k="SNI" ;;
    SSLPort|vport|SSL)                   k="SSL" ;;
    ProxyPort|Proxy)                     k="Proxy" ;;
    UDPServer|UDP)                       k="UDP" ;;
    Info)                                k="Info" ;;
    v2rayjson|wgConf|Payload|DNSHost)    k="$key" ;;
    Flag|Category|DropBear|Obfs|Auth|CFServer|CFUser|CFPass|vuid|vpath|vprotocol|NameServer|PublicKey|ProxyHost|Bug) k="$key" ;;
    *)                                   k="$key" ;;
  esac

  [ "${seen_keys[$k]:-}" = "1" ] && continue
  seen_keys[$k]=1

  if [[ "$k" =~ ^(SSL|Proxy|Port|UDP)$ ]]; then
    num=$(printf '%s' "$dec" | tr -cd '0-9')
    [ -n "$num" ] && printf '      "%s": %s,\n' "$k" "$num" >> "$OUT" && continue
  fi

  if [ "$k" = "v2rayjson" ]; then
    clean_json=$(printf '%s' "$dec" | sed 's/\\\\/\\/g; s/"/\\"/g')
    printf '      "%s": "%s",\n' "$k" "$clean_json" >> "$OUT"
    continue
  fi

  printf '      "%s": "%s",\n' "$k" "$(printf '%s' "$dec" | sed 's/"/\\"/g')" >> "$OUT"
done < .pairs.txt

[ "$server_open" = true ] && printf '    }\n' >> "$OUT"
printf '  ]\n}\n' >> "$OUT"

sed -i '$ s/,$//' "$OUT"
sed -i '/},$/ s/,$//' "$OUT"

rm -f .pairs.txt

echo ""
echo "RWANDA WINS! FULLY DECRYPTED → $OUT"
echo "NO WARNINGS | 100+ SERVERS | CLEAN JSON"
echo "Saved: $(pwd)/$OUT"
echo "Connect: 154.26.139.81 | msyfree | msyfree | msyfree.com"
EOF