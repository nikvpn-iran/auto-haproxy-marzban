#!/bin/bash

# مشخص کردن رنگ‌ها برای زیبایی خروجی
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}====================================================${NC}"
echo -e "${YELLOW}  Marzban All-on-One-Port (HAProxy) Auto Setup${NC}"
echo -e "${GREEN}====================================================${NC}"
echo ""

# مرحله 1: دریافت اطلاعات از کاربر
read -p "Enter Panel & Subscription Domain (e.g., panel.example.com): " PANEL_DOMAIN
read -p "Enter REALITY SNI Domain (e.g., reality.com): " REALITY_DOMAIN

read -p "Enter Local Panel Port [Default: 10000]: " PANEL_PORT
PANEL_PORT=${PANEL_PORT:-10000}

read -p "Enter Local Fallback Port (for TLS Configs) [Default: 11000]: " FALLBACK_PORT
FALLBACK_PORT=${FALLBACK_PORT:-11000}

read -p "Enter Local REALITY Port [Default: 12000]: " REALITY_PORT
REALITY_PORT=${REALITY_PORT:-12000}

echo -e "\n${YELLOW}Installing HAProxy...${NC}"
# مرحله 2: نصب پیش‌نیازها
apt-get update
apt-get install -y haproxy

# بک‌آپ‌گیری از کانفیگ فعلی HAProxy
if [ -f /etc/haproxy/haproxy.cfg ]; then
    cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak
    echo -e "${GREEN}Backup of existing HAProxy config created.${NC}"
fi

echo -e "\n${YELLOW}Configuring HAProxy...${NC}"
# مرحله 3: ایجاد فایل پیکربندی HAProxy
cat <<EOF > /etc/haproxy/haproxy.cfg
listen front
    mode tcp
    bind *:443
    tcp-request inspect-delay 5s
    tcp-request content accept if { req_ssl_hello_type 1 }
    
    # Routing based on SNI
    use_backend panel if { req.ssl_sni -m end $PANEL_DOMAIN }
    use_backend reality if { req.ssl_sni -m end $REALITY_DOMAIN }
    default_backend fallback

backend panel
    mode tcp
    server srv1 127.0.0.1:$PANEL_PORT

backend fallback
    mode tcp
    server srv1 127.0.0.1:$FALLBACK_PORT

backend reality
    mode tcp
    server srv1 127.0.0.1:$REALITY_PORT send-proxy
EOF

echo -e "\n${YELLOW}Configuring Marzban .env...${NC}"
# مرحله 4: ویرایش فایل .env مرزبان
MARZBAN_ENV="/opt/marzban/.env"
if [ -f "$MARZBAN_ENV" ]; then
    # تغییر یا افزودن UVICORN_HOST
    if grep -q "^UVICORN_HOST" "$MARZBAN_ENV"; then
        sed -i 's/^UVICORN_HOST.*/UVICORN_HOST = "127.0.0.1"/' "$MARZBAN_ENV"
    else
        echo 'UVICORN_HOST = "127.0.0.1"' >> "$MARZBAN_ENV"
    fi

    # تغییر یا افزودن UVICORN_PORT
    if grep -q "^UVICORN_PORT" "$MARZBAN_ENV"; then
        sed -i "s/^UVICORN_PORT.*/UVICORN_PORT = $PANEL_PORT/" "$MARZBAN_ENV"
    else
        echo "UVICORN_PORT = $PANEL_PORT" >> "$MARZBAN_ENV"
    fi
    echo -e "${GREEN}Marzban .env updated successfully.${NC}"
else
    echo -e "${RED}Warning: /opt/marzban/.env not found! Please update UVICORN settings manually.${NC}"
fi

echo -e "\n${YELLOW}Restarting Services...${NC}"
# مرحله 5: ریستارت سرویس‌ها
systemctl restart haproxy
systemctl enable haproxy

if command -v marzban &> /dev/null; then
    marzban restart
else
    echo -e "${RED}Warning: 'marzban' command not found. Please restart Marzban manually.${NC}"
fi

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN} Setup Completed Successfully!${NC}"
echo -e " HAProxy is now listening on port 443."
echo -e "${YELLOW} IMPORTANT NEXT STEPS:${NC}"
echo -e " 1. Go to Marzban Core Settings."
echo -e " 2. Set your REALITY inbound 'listen' to 127.0.0.1 and port to $REALITY_PORT."
echo -e " 3. Enable 'acceptProxyProtocol': true for REALITY."
echo -e " 4. Setup your Fallback inbound on port $FALLBACK_PORT."
echo -e " 5. Change ports to 443 in Marzban Host Settings."
echo -e "${GREEN}====================================================${NC}"
