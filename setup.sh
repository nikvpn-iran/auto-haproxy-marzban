#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

VARS_FILE="/etc/haproxy/.marzban_setup_vars"

# بارگذاری تنظیمات قبلی (برای قابلیت ویرایش)
if [ -f "$VARS_FILE" ]; then
    source "$VARS_FILE"
    echo -e "${GREEN}Previous configuration found. Entering Edit Mode...${NC}"
else
    echo -e "${YELLOW}No previous configuration found. Entering Initial Setup...${NC}"
fi

echo -e "${CYAN}====================================================${NC}"
echo -e "${YELLOW} Marzban HAProxy Auto Setup & Editor${NC}"
echo -e "${CYAN}====================================================${NC}"
echo -e "Press [Enter] to keep the current value, or type a new one to edit.\n"

# دریافت اطلاعات با نمایش مقادیر پیش‌فرض یا قبلی
read -p "Panel & Sub Domain [${PANEL_DOMAIN:-panel.example.com}]: " input
PANEL_DOMAIN=${input:-${PANEL_DOMAIN:-panel.example.com}}

read -p "Reality SNI [${REALITY_SNI:-reality.com}]: " input
REALITY_SNI=${input:-${REALITY_SNI:-reality.com}}

read -p "Reality GRPC SNI [${REALITY_GRPC_SNI:-grpc.com}]: " input
REALITY_GRPC_SNI=${input:-${REALITY_GRPC_SNI:-grpc.com}}

read -p "Panel Local Port [${PANEL_PORT:-10000}]: " input
PANEL_PORT=${input:-${PANEL_PORT:-10000}}

read -p "Reality Local Port [${REALITY_PORT:-12000}]: " input
REALITY_PORT=${input:-${REALITY_PORT:-12000}}

read -p "Reality GRPC Local Port [${REALITY_GRPC_PORT:-12200}]: " input
REALITY_GRPC_PORT=${input:-${REALITY_GRPC_PORT:-12200}}

read -p "Fallback Local Port [${FALLBACK_PORT:-11000}]: " input
FALLBACK_PORT=${input:-${FALLBACK_PORT:-11000}}

read -p "Current Sfront Port (Subscription) [${CURRENT_PORT:-8080}]: " input
CURRENT_PORT=${input:-${CURRENT_PORT:-8080}}

# ذخیره تنظیمات برای ویرایش‌های آینده
mkdir -p /etc/haproxy
cat <<EOF > "$VARS_FILE"
PANEL_DOMAIN="$PANEL_DOMAIN"
REALITY_SNI="$REALITY_SNI"
REALITY_GRPC_SNI="$REALITY_GRPC_SNI"
PANEL_PORT="$PANEL_PORT"
REALITY_PORT="$REALITY_PORT"
REALITY_GRPC_PORT="$REALITY_GRPC_PORT"
FALLBACK_PORT="$FALLBACK_PORT"
CURRENT_PORT="$CURRENT_PORT"
EOF

echo -e "\n${YELLOW}Updating system and checking HAProxy...${NC}"
apt-get update -y
apt-get install -y haproxy

echo -e "${YELLOW}Configuring /etc/haproxy/haproxy.cfg...${NC}"
cat <<EOF > /etc/haproxy/haproxy.cfg
listen front
 mode tcp
 bind *:443

 tcp-request inspect-delay 5s
 tcp-request content accept if { req_ssl_hello_type 1 }

 use_backend panel if { req.ssl_sni -m end $PANEL_DOMAIN }
 use_backend reality if { req.ssl_sni -m end $REALITY_SNI }
 use_backend realitygrpc if { req.ssl_sni -m end $REALITY_GRPC_SNI }
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

 use_backend sub if { req.ssl_sni -m end $PANEL_DOMAIN }

backend sub
 mode tcp
 server srv1 127.0.0.1:$PANEL_PORT
EOF

echo -e "${YELLOW}Applying identical .env configurations...${NC}"
ENV_FILE="/opt/marzban/.env"

if [ -f "$ENV_FILE" ]; then
    if ! grep -q "^XRAY_FALLBACKS_INBOUND_TAG" "$ENV_FILE"; then
        echo 'XRAY_FALLBACKS_INBOUND_TAG = "TROJAN_FALLBACK_INBOUND"' >> "$ENV_FILE"
    fi
else
    echo 'XRAY_FALLBACKS_INBOUND_TAG = "TROJAN_FALLBACK_INBOUND"' > "$ENV_FILE"
fi

echo -e "${YELLOW}Testing HAProxy config and restarting services...${NC}"
if haproxy -c -f /etc/haproxy/haproxy.cfg; then
    systemctl restart haproxy
    
    if command -v marzban &> /dev/null; then
        marzban restart
    fi
    echo -e "${GREEN}====================================================${NC}"
    echo -e "${GREEN} Setup/Update Completed Successfully!${NC}"
    echo -e "${GREEN}====================================================${NC}"
else
    echo -e "${RED}HAProxy configuration test failed. Please check your inputs.${NC}"
fi
