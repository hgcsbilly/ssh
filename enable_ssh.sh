#!/usr/bin/env bash
# ==============================================================================
# Script de activación y configuración de SSH - Usuario: hgcsbilly
# Repositorio: https://github.com/hgcsbilly/ssh
# ==============================================================================
set -e

GITHUB_USER="hgcsbilly"
TARGET_USER="$(logname 2>/dev/null || echo "$SUDO_USER" || echo "$USER")"
USER_HOME="$(eval echo "~$TARGET_USER")"

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
    systemctl enable --now ssh 2>/dev/null || service ssh restart 2>/dev/null
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
    ufw reload
elif command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld 2>/dev/null; then
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --reload
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

echo ""
echo "================================================="
echo "  SSH HABILITADO CORRECTAMENTE"
echo "================================================="
echo "Usuario destino: $TARGET_USER"
echo "IPs detectadas en esta máquina:"
hostname -I 2>/dev/null || ip -br addr show 2>/dev/null | awk '{print $3}' || ifconfig 2>/dev/null | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}'
echo "-------------------------------------------------"
echo "Comando para conectarte desde otra PC:"
echo "  ssh $TARGET_USER@<IP_DE_LA_MAQUINA>"
echo "================================================="
