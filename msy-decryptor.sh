#!/bin/bash
# ========================================
# MSY VPN DECRYPTOR - RWANDA EDITION
# GitHub: https://github.com/yourusername/msy-vpn-decryptor
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
#
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

if [ -z "$1" ]; then
  echo "Usage: ./msy-decryptor.sh <config.msy> [output.json]"
  echo "Example: ./msy-decryptor.sh moodlMSY.txt myconfig.json"
  exit 1
fi

FILE="$1"
OUT="${2:-decrypted_msy.json}"

if [ ! -f "$FILE" ]; then
  echo "Error: File '$FILE' not found!"
  exit 1
fi

echo "Decrypting: $FILE → $OUT"

grep -o '"[^"]*":[^,]*' "$FILE" | grep -E '=+$' | cut -d'"' -f2,4 > .msy_temp.txt

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
while IFS=: read key enc; do
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
echo "Import & Connect to: 154.26.139.81 | msyfree | msyfree | msyfree.com"
