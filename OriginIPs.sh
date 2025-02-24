#!/bin/bash

# Input file containing subdomain resolution results
INPUT_FILE="result_ip.txt" #You can change the txt file with your txt file name

# Extract unique IPs from the file
echo "[*] Extracting unique IPs from $INPUT_FILE..."
IPs=$(grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$INPUT_FILE" | sort -u)

# Create output file
OUTPUT_FILE="origin_ips.txt" #you can change the OutPut file name here
> "$OUTPUT_FILE"

echo "[*] Checking potential origin IPs..."

# Loop through each IP
for ip in $IPs; do
    echo "[+] Checking IP: $ip"

    # Check who owns the IP (avoid Cloudflare, Akamai, AWS, etc.)
    owner=$(whois "$ip" | grep -i 'OrgName\|NetName\|Organization' | head -1)

    if [[ "$owner" =~ "Cloudflare" || "$owner" =~ "Akamai" || "$owner" =~ "Amazon" || "$owner" =~ "Fastly" || "$owner" =~ "Google" ]]; then
        echo "   [-] Skipping (CDN detected: $owner)"
        continue
    fi

    # Test if the IP serves Swiggy content directly
    response=$(curl -k -H "Host: swiggy.com" --max-time 5 --silent --write-out "%{http_code}" --output /dev/null "http://$ip")

    if [[ "$response" =~ "200" || "$response" =~ "302" ]]; then
        echo "   [+] Potential origin IP found: $ip (Response: $response)"
        echo "$ip" >> "$OUTPUT_FILE"

        # Scan for open ports
        echo "   [*] Scanning ports on $ip..."
        nmap -sS -p- --min-rate=1000 -T4 "$ip" | tee -a "$OUTPUT_FILE"
    else
        echo "   [-] No direct response (Code: $response)"
    fi

    echo "-----------------------------------"
done

echo "[✔] Origin IP scanning completed. Results saved in $OUTPUT_FILE"
