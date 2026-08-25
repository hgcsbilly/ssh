#!/usr/bin/env bash
# ==============================================================================
# Script de activación y configuración de SSH - Usuario: hgcsbilly
# Repositorio: https://github.com/hgcsbilly/ssh
# ==============================================================================
set -e

GITHUB_USER="hgcsbilly"
TARGET_USER="$(logname 2>/dev/null || echo "$SUDO_USER" || echo "$USER")"
USER_HOME="$(eval echo "~$TARGET_USER")"

echo "[*] Detectando sistema e instalando OpenSSH Server..."
if command -v apt-get &>/dev/null; then
    apt-get update -y && apt-get install -y openssh-server curl
    SERVICE="ssh"
elif command -v dnf &>/dev/null; then
    dnf install -y openssh-server curl
    SERVICE="sshd"
elif command -v yum &>/dev/null; then
    yum install -y openssh-server curl
    SERVICE="sshd"
elif command -v pacman &>/dev/null; then
    pacman -Sy --noconfirm openssh curl
    SERVICE="sshd"
elif command -v zypper &>/dev/null; then
    zypper install -y openssh curl
    SERVICE="sshd"
elif command -v apk &>/dev/null; then
    apk add openssh curl
    SERVICE="sshd"
else
    echo "[-] Gestor de paquetes no compatible."
    exit 1
fi

echo "[*] Habilitando e iniciando servicio SSH..."
systemctl enable --now "$SERVICE" 2>/dev/null || service "$SERVICE" restart 2>/dev/null

echo "[*] Configurando Firewall..."
if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
    ufw allow 22/tcp
    ufw reload
elif command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld 2>/dev/null; then
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --reload
fi

# Configurar llaves públicas de GitHub para acceso sin contraseña
if [ -n "$GITHUB_USER" ] && [ -d "$USER_HOME" ]; then
    echo "[*] Importando llaves públicas de GitHub (${GITHUB_USER})..."
    SSH_DIR="$USER_HOME/.ssh"
    AUTH_KEYS="$SSH_DIR/authorized_keys"

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    touch "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"

    TEMP_KEYS=$(mktemp)
    if curl -fsSL "https://github.com/${GITHUB_USER}.keys" -o "$TEMP_KEYS" && [ -s "$TEMP_KEYS" ]; then
        while IFS= read -r key; do
            if ! grep -qF "$key" "$AUTH_KEYS"; then
                echo "$key" >> "$AUTH_KEYS"
                echo "  [+] Llave agregada."
            fi
        done < "$TEMP_KEYS"
        chown -R "$TARGET_USER":"$TARGET_USER" "$SSH_DIR"
    else
        echo "  [i] No se encontraron llaves públicas en https://github.com/${GITHUB_USER}.keys."
    fi
    rm -f "$TEMP_KEYS"
fi

echo ""
echo "================================================="
echo "  SSH HABILITADO CORRECTAMENTE"
echo "================================================="
echo "Usuario destino: $TARGET_USER"
echo "IPs detectadas en esta máquina:"
hostname -I 2>/dev/null || ip -br addr show | awk '{print $3}'
echo "-------------------------------------------------"
echo "Comando para conectarte desde otra PC:"
echo "  ssh $TARGET_USER@<IP_DE_LA_MAQUINA>"
echo "================================================="
