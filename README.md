# 🚀 Configuración Automática de Acceso SSH (hgcsbilly)

Scripts para activar y configurar un servidor SSH (OpenSSH) de forma automática con llaves autorizadas preconfiguradas, reglas de Firewall, detección de red y notificación automática a Telegram.

---

## ⚡ Comandos de Ejecución Rápida (One-Liners)

### 🐧 Linux & 🍏 macOS
Ejecutar en una terminal con permisos `sudo`:
```bash
curl -fsSL https://raw.githubusercontent.com/hgcsbilly/ssh/main/enable_ssh.sh | sudo bash
```
*(También disponible como `install.sh`)*

### 🪟 Windows
Abrir **PowerShell como Administrador** y ejecutar:
```powershell
irm https://raw.githubusercontent.com/hgcsbilly/ssh/main/enable_ssh.ps1 | iex
```

---

## 📡 Detección y Notificación Automática

Al terminar la instalación, el script:
1. Imprime en pantalla la **IP Local**, la **IP Pública**, el nombre **mDNS** (`equipo.local`) y la IP de **Tailscale** (si está activa).
2. Envía una notificación instantánea a tu **Telegram** con el comando exacto listo para conectar:
   ```bash
   ssh usuario@192.168.1.X
   # o
   ssh usuario@hostname.local
   ```

---

## 🌐 Cómo Conectarse según el Escenario de Red

| Escenario | Método de Conexión | Comando |
| :--- | :--- | :--- |
| **Misma Red Local (Wi-Fi/LAN)** | IP Local directa | `ssh usuario@192.168.1.X` |
| **Misma Red Local (Sin saber la IP)** | ZeroConf / mDNS | `ssh usuario@hostname.local` |
| **Remoto (Cualquier Red / CGNAT)** | Tailscale VPN | `ssh usuario@100.X.Y.Z` |
| **Remoto Temporal (Sin VPN)** | Túnel Inverso Pinggy | `ssh -p 443 -R0:localhost:22 qr@a.pinggy.io` |
