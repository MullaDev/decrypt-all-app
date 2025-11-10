#!/bin/bash
# ========================================
# MSY VPN DECRYPTOR - RWANDA EDITION
# GitHub: https://github.com/MullaDev/decrypt-all-app
# Works with file in ANY folder (Download, DCIM, etc.)
# Password: UPDATE BELOW WHEN CHANGED
# ========================================

IV="0123456789ABCDEF1032547698BADCFE"
PASSWORD="HexXVPNPass"  # CHANGE THIS LINE WHEN PASSWORD UPDATES

KEY=$(printf "$PASSWORD" | openssl dgst -sha256 -binary | xxd -p -c 256)

# ========================================
# ███████╗ ██████╗██████╗ ██╗██████╗ ████████╗    ██████╗ ██╗   ██╗
# ██╔════╝██╔════╝██╔══██╗██║██╔══██╗╚══██╔══╝    ██╔══██╗╚██╗ ██╔╝
# ███████╗██║     ██████╔╝██║██████╔╝   ██║       ██████╔╝ ╚████╔╝ 
# ╚════██║██║     ██╔══██╗██║██╔═══╝    ██║       ██╔══██╗  ╚██╔╝  
# ███████║╚██████╗██║  ██║██║██║        ██║       ██║  ██║   ██║   
# ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝╚═╝        ╚═╝       ╚═╝  ╚═╝   ╚═╝   
#
# ██████╗ ██╗   ██╗    @MullaRDevZ
# ██╔══██╗╚██╗ ██╔╝    @MullaRDevZ
# ██████╔╝ ╚████╔╝     @MullaRDevZ
# ██╔══██╗  ╚██╔╝      @MullaRDevZ
# ██████╔╝   ██║       @MullaRDevZ
# ╚═════╝    ╚═╝       @MullaRDevZ
# ========================================

echo ""
echo "   ███╗   ███╗███████╗██╗   ██╗    ██████╗ ███████╗ ██████╗██████╗ ██╗   ██╗██████╗ ████████╗"
echo "   ████╗ ████║██╔════╝╚██╗ ██╔╝    ██╔══██╗██╔════╝██╔════╝██╔══██╗╚██╗ ██╔╝██╔══██╗╚══██╔══╝"
echo "   ██╔████╔██║███████╗ ╚████╔╝     ██║  ██║█████╗  ██║     ██████╔╝ ╚████╔╝ ██████╔╝   ██║   "
echo "   ██║╚██╔╝██║╚════██║  ╚██╔╝      ██║  ██║██╔══╝  ██║     ██╔══██╗  ╚██╔╝  ██╔═══╝    ██║   "
echo "   ██║ ╚═╝ ██║███████║   ██║       ██████╔╝███████╗╚██████╗██║  ██║   ██║   ██║        ██║   "
echo "   ╚═╝     ╚═╝╚══════╝   ╚═╝       ╚═════╝ ╚══════╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝        ╚═╝   "
echo ""
echo "        RWANDA FULL DECRYPTOR v1.0 | t.me/msyfree | 154.26.139.81"
echo "        Current Time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "        Country: RWANDA"
echo ""

# === AUTO FIND moodlMSY.txt IN ANY FOLDER ===
FILE=""
SEARCH_PATHS=(
  "$HOME/storage/shared/Download"
  "$HOME/storage/shared/Documents"
  "$HOME/storage/shared/DCIM"
  "$HOME/storage/shared"
  "$HOME"
)

for path in "${SEARCH_PATHS[@]}"; do
  if [ -f "$path/moodlMSY.txt" ]; then
    FILE="$path/moodlMSY.txt"
    break
  fi
done

# If not found, ask user
if [ -z "$FILE" ] && [ -n "$1" ]; then
  FILE="$1"
elif [ -z "$FILE" ]; then
  echo "Searching for moodlMSY.txt..."
  FILE=$(find "$HOME/storage/shared" -name "moodlMSY.txt" -type f 2>/dev/null | head -1)
fi

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  echo "Error: moodlMSY.txt not found!"
  echo "   → Put it in Download, Documents, or any folder"
  echo "   → Or run: ./msy-decryptor.sh /path/to/moodlMSY.txt"
  exit 1
fi

OUT="${2:-decrypted_msy.json}"

echo "Found: $FILE"
echo "Decrypting → $OUT"

# === DECRYPTION (Handles line-wrapped Base64) ===
tr -d '\n\r' < "$FILE" | grep -o '"[^"]*":"[^"]*"' | grep -E '=+$' | sed 's/":"/\t/g; s/"//g' > .msy_temp.txt

decrypt() {
  printf "$1" | base64 -d 2>/dev/null | \
  openssl enc -d -aes-256-cbc -K "$KEY" -iv "$IV" -nopad 2>/dev/null | \
  perl -pe 's/[\x01-\x10].*$//s' 2>/dev/null
}

echo "{" > "$OUT"
echo "  \"Version\": \"1.0\"," >> "$OUT"
echo "  \"Country\": \"RWANDA\"," >> "$OUT"
echo "  \"Updated\": \"$(date '+%Y-%m-%d %H:%M:%S %Z')\"," >> "$OUT"
echo "  \"BestServer\": {" >> "$OUT"
echo "    \"Host\": \"154.26.139.81\"," >> "$OUT"
echo "    \"Port\": 22," >> "$OUT"
echo "    \"User\": \"msyfree\"," >> "$OUT"
echo "    \"Pass\": \"msyfree\"," >> "$OUT"
echo "    \"SNI\": \"msyfree.com\"," >> "$OUT"
echo "    \"SSL\": 443," >> "$OUT"
echo "    \"UDP\": 7300" >> "$OUT"
echo "  }," >> "$OUT"
echo "  \"Servers\": [" >> "$OUT"

server_count=0
while IFS=$'\t' read key enc; do
  dec=$(decrypt "$enc")
  [ -z "$dec" ] && dec="msyfree.com"

  case "$key" in
    "Name")
      if [ $server_count -gt 0 ]; then echo "    }," >> "$OUT"; fi
      echo "    {" >> "$OUT"
      echo "      \"Name\": \"$dec\"," >> "$OUT"
      ((server_count++))
      ;;
    "SSHHost")   echo "      \"Host\": \"$dec\"," >> "$OUT" ;;
    "Username")  echo "      \"User\": \"$dec\"," >> "$OUT" ;;
    "Password")  echo "      \"Pass\": \"$dec\"," >> "$OUT" ;;
    "vhost")     echo "      \"SNI\": \"$dec\"," >> "$OUT" ;;
    "SSLPort")   echo "      \"SSL\": $dec," >> "$OUT" ;;
    "ProxyPort") echo "      \"Proxy\": $dec," >> "$OUT" ;;
  esac
done < .msy_temp.txt

echo "    }" >> "$OUT"
echo "  ]" >> "$OUT"
echo "}" >> "$OUT"

rm .msy_temp.txt
echo ""
echo "RWANDA WINS! FULLY DECRYPTED → $OUT"
echo "File saved in: $(pwd)"
echo "Import & Connect: 154.26.139.81 | msyfree | msyfree | msyfree.com"
