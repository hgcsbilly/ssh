# ==============================================================================
# Script de activacion y configuracion de SSH para Windows - Usuario: hgcsbilly
# Repositorio: https://github.com/hgcsbilly/ssh
# ==============================================================================

# Requiere permisos de Administrador
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "[-] Este script requiere ser ejecutado como Administrador en PowerShell."
    exit 1
}

$telegramToken = "8978940332:AAGbP7p6uDIfBoUX4g91XcC8-F6utPtKTbA"
$telegramChatId = "877911662"

Write-Host "[*] Verificando e instalando OpenSSH Server en Windows..." -ForegroundColor Cyan
$sshCapability = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
if ($sshCapability.State -ne 'Installed') {
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
}

Write-Host "[*] Habilitando e iniciando el servicio sshd..." -ForegroundColor Cyan
Start-Service sshd -ErrorAction SilentlyContinue
Set-Service -Name sshd -StartupType 'Automatic'

Write-Host "[*] Configurando regla de Firewall..." -ForegroundColor Cyan
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
}

Write-Host "[*] Configurando llaves publicas autorizadas..." -ForegroundColor Cyan
$userSshDir = "$HOME\.ssh"
if (!(Test-Path $userSshDir)) { New-Item -ItemType Directory -Path $userSshDir -Force | Out-Null }

$authKeys = "$userSshDir\authorized_keys"
if (!(Test-Path $authKeys)) { New-Item -ItemType File -Path $authKeys -Force | Out-Null }

$progDataSsh = "$env:ProgramData\ssh"
if (!(Test-Path $progDataSsh)) { New-Item -ItemType Directory -Path $progDataSsh -Force | Out-Null }
$adminAuthKeys = "$progDataSsh\administrators_authorized_keys"
if (!(Test-Path $adminAuthKeys)) { New-Item -ItemType File -Path $adminAuthKeys -Force | Out-Null }

# Llaves preconfiguradas
$hardcodedKeys = @(
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO/K1yN+kqqx2coQ7HZ85ciCHdsbjx9XxdoYWngIpNRP opencode@windows",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILDcT8w5HbwAaN5twCYFQdDsr5n0GgtuhOEdoI4Rksd5 jael-hermes@contabo"
)

$currentKeys = Get-Content $authKeys -ErrorAction SilentlyContinue
if ($null -eq $currentKeys) { $currentKeys = @() }

foreach ($hk in $hardcodedKeys) {
    if ($currentKeys -notcontains $hk) {
        Add-Content -Path $authKeys -Value $hk
        Add-Content -Path $adminAuthKeys -Value $hk
        Write-Host "  [+] Llave autorizada agregada." -ForegroundColor Green
    }
}

try {
    $keysWeb = (Invoke-RestMethod -Uri "https://github.com/hgcsbilly.keys" -UseBasicParsing) -split "`n"
    foreach ($k in $keysWeb) {
        $cleanKey = $k.Trim()
        if ($cleanKey.Length -gt 10 -and ($currentKeys -notcontains $cleanKey)) {
            Add-Content -Path $authKeys -Value $cleanKey
            Add-Content -Path $adminAuthKeys -Value $cleanKey
            Write-Host "  [+] Llave de GitHub agregada a authorized_keys" -ForegroundColor Green
        }
    }
} catch {
    # Llaves remotas opcionales
}

# Configurar permisos seguros para OpenSSH en Windows
icacls.exe "$authKeys" /inheritance:r /grant:r "$($env:USERNAME):(R,W)" /grant:r "SYSTEM:(R,W)" /grant:r "Administrators:(R,W)" | Out-Null
icacls.exe "$adminAuthKeys" /inheritance:r /grant:r "SYSTEM:(R,W)" /grant:r "Administrators:(R,W)" | Out-Null

# Reiniciar servicio para aplicar
Restart-Service sshd -ErrorAction SilentlyContinue

# Detectar IPs y Hostname
$hostName = $env:COMPUTERNAME
$mdnsName = "$hostName.local"
$localIps = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceAlias -notmatch 'Loopback|vEthernet' -and $_.IPAddress -notmatch '^169\.' }).IPAddress
$primaryIp = if ($localIps) { ($localIps | Select-Object -First 1) } else { "127.0.0.1" }
$allIpsStr = if ($localIps) { $localIps -join ', ' } else { "127.0.0.1" }

$publicIp = "N/D"
try {
    $publicIp = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 3 -UseBasicParsing).Trim()
} catch {
    try {
        $publicIp = (Invoke-RestMethod -Uri "https://ifconfig.me" -TimeoutSec 3 -UseBasicParsing).Trim()
    } catch {}
}

$tailscaleIp = ""
try {
    $tsOut = (& tailscale ip -4 2>$null)
    if ($tsOut) { $tailscaleIp = $tsOut.Trim() }
} catch {}

# Notificación Telegram
if ($telegramToken -and $telegramChatId) {
    Write-Host "[*] Enviando notificacion a Telegram..." -ForegroundColor Cyan
    $bt = [char]96
    $msgLines = @(
        "🔔 *Acceso SSH Windows Habilitado*",
        "👤 *Usuario:* $env:USERNAME",
        "💻 *Host:* $hostName ($mdnsName)",
        "🏠 *IP Local:* $primaryIp",
        "🌐 *IP Publica:* $publicIp"
    )
    if ($tailscaleIp) {
        $msgLines += "🦎 *Tailscale:* $tailscaleIp"
    }
    $msgLines += ""
    $msgLines += "🚀 *Comando LAN:*"
    $msgLines += "${bt}ssh $env:USERNAME@$primaryIp${bt}"
    $msgLines += "🚀 *Comando mDNS:*"
    $msgLines += "${bt}ssh $env:USERNAME@$mdnsName${bt}"
    if ($tailscaleIp) {
        $msgLines += "🚀 *Comando Tailscale:*"
        $msgLines += "${bt}ssh $env:USERNAME@$tailscaleIp${bt}"
    }

    $msg = $msgLines -join "`n"

    try {
        $jsonPayload = @{
            chat_id = $telegramChatId
            parse_mode = "Markdown"
            text = $msg
        } | ConvertTo-Json -Compress

        $utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonPayload)
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$telegramToken/sendMessage" -Method Post -ContentType "application/json; charset=utf-8" -Body $utf8Bytes -TimeoutSec 5 | Out-Null
    } catch {}
}

Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "  OPENSSH HABILITADO CORRECTAMENTE EN WINDOWS    " -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host "Usuario destino : $env:USERNAME"
Write-Host "Hostname        : $hostName ($mdnsName)"
Write-Host "IP Local (LAN)  : $allIpsStr"
Write-Host "IP Publica      : $publicIp"
if ($tailscaleIp) { Write-Host "IP Tailscale    : $tailscaleIp" }
Write-Host "-------------------------------------------------"
Write-Host "Comandos para conectarte:"
Write-Host "  [En la misma red] : ssh $env:USERNAME@$primaryIp"
Write-Host "  [Por nombre mDNS] : ssh $env:USERNAME@$mdnsName"
if ($tailscaleIp) { Write-Host "  [Por Tailscale]   : ssh $env:USERNAME@$tailscaleIp" }
Write-Host "================================================="
