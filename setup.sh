#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}====================================================${NC}"
echo -e "${YELLOW} Marzban HAProxy Setup (Ports Only & Identical .env)${NC}"
echo -e "${GREEN}====================================================${NC}"

# ۱. آپدیت پکیج‌ها و نصب HAProxy
echo -e "${YELLOW}Updating system and installing HAProxy...${NC}"
apt-get update -y && apt-get upgrade -y
apt install -y haproxy[cite: 2]

# ۲. دریافت پورت‌ها از کاربر
read -p "Enter Panel Local Port [Default: 10000]: " PANEL_PORT
PANEL_PORT=${PANEL_PORT:-10000}

read -p "Enter Reality Local Port [Default: 12000]: " REALITY_PORT
REALITY_PORT=${REALITY_PORT:-12000}

read -p "Enter Reality GRPC Local Port [Default: 12200]: " REALITY_GRPC_PORT
REALITY_GRPC_PORT=${REALITY_GRPC_PORT:-12200}

read -p "Enter Fallback Local Port [Default: 11000]: " FALLBACK_PORT
FALLBACK_PORT=${FALLBACK_PORT:-11000}

read -p "Enter Your Current Port for Sfront (Subscription) [Default: 8080]: " CURRENT_PORT
CURRENT_PORT=${CURRENT_PORT:-8080}

# ۳. ایجاد فایل کانفیگ HAProxy با پورت‌های جدید و SNIهای ثابت[cite: 2]
echo -e "${YELLOW}Configuring /etc/haproxy/haproxy.cfg...${NC}"
cat <<EOF > /etc/haproxy/haproxy.cfg
listen front
 mode tcp
 bind *:443

 tcp-request inspect-delay 5s
 tcp-request content accept if { req_ssl_hello_type 1 }

 use_backend panel if { req.ssl_sni -m end yourpaneldomain.com }
 use_backend reality if { req.ssl_sni -m end FirstSNI }
 use_backend realitygrpc if { req.ssl_sni -m end SecondSNI }
 default_backend fallback

backend panel
 mode tcp
 server srv1 127.0.0.1:$PANEL_PORT

backend reality
 mode tcp
 server srv1 127.0.0.1:$REALITY_PORT send-proxy

backend realitygrpc
 mode tcp
 server srv1 127.0.0.1:$REALITY_GRPC_PORT

backend fallback
 mode tcp
 server srv1 127.0.0.1:$FALLBACK_PORT

listen sfront
 mode tcp
 bind *:$CURRENT_PORT

 tcp-request inspect-delay 5s
 tcp-request content accept if { req_ssl_hello_type 1 }

 use_backend sub if { req.ssl_sni -m end yourpaneldomain.com }

backend sub
 mode tcp
 server srv1 127.0.0.1:$PANEL_PORT
EOF

# ۴. یکسان‌سازی فایل .env مرزبان[cite: 2]
echo -e "${YELLOW}Applying identical .env configurations...${NC}"
ENV_FILE="/opt/marzban/.env"

if [ -f "$ENV_FILE" ]; then
    if ! grep -q "^XRAY_FALLBACKS_INBOUND_TAG" "$ENV_FILE"; then
        echo 'XRAY_FALLBACKS_INBOUND_TAG = "TROJAN_FALLBACK_INBOUND"' >> "$ENV_FILE"[cite: 2]
    fi
else
    echo 'XRAY_FALLBACKS_INBOUND_TAG = "TROJAN_FALLBACK_INBOUND"' > "$ENV_FILE"[cite: 2]
fi

# ۵. تست کانفیگ و ریستارت سرویس‌ها[cite: 2]
echo -e "${YELLOW}Testing HAProxy config and restarting services...${NC}"
haproxy -c -f /etc/haproxy/haproxy.cfg[cite: 2]

systemctl restart haproxy[cite: 2]
marzban restart[cite: 2]

echo -e "${GREEN}Setup Completed! HAProxy and Marzban are running with updated ports.${NC}"
