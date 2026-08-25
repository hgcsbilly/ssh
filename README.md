# 🚀 One-Liner SSH Setup (`hgcsbilly`)

Configuración y activación instantánea de servidor SSH con importación automática de llaves públicas de GitHub (`hgcsbilly`) en **Linux**, **macOS** y **Windows**.

---

## 🐧 Linux (Ubuntu, Debian, Fedora, Arch, Alpine, Rocky, etc.)

Ejecuta en la terminal con `sudo`:

```bash
curl -fsSL https://raw.githubusercontent.com/hgcsbilly/ssh/main/enable_ssh.sh | sudo bash
```

*O con `install.sh`:*
```bash
curl -fsSL https://raw.githubusercontent.com/hgcsbilly/ssh/main/install.sh | sudo bash
```

---

## 🍏 macOS

Abre Terminal y ejecuta:

```bash
curl -fsSL https://raw.githubusercontent.com/hgcsbilly/ssh/main/enable_ssh.sh | sudo bash
```

---

## 🪟 Windows (10 / 11 / Server)

Abre **PowerShell como Administrador** y ejecuta:

```powershell
irm https://raw.githubusercontent.com/hgcsbilly/ssh/main/enable_ssh.ps1 | iex
```

---

## ✨ ¿Qué hace este script?
1. Detecta el sistema operativo y el gestor de paquetes.
2. Instala y habilita el servicio OpenSSH Server (`ssh`/`sshd`).
3. Abre automáticamente el puerto 22 en el firewall (`ufw`, `firewalld`, `Windows Defender Firewall`).
4. Descarga e instala las llaves públicas de [`github.com/hgcsbilly.keys`](https://github.com/hgcsbilly.keys) en `authorized_keys`.
5. Muestra la IP local y el comando exacto para conectarte.
