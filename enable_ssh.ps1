# ==============================================================================
# Script de activacion y configuracion de SSH para Windows - Usuario: hgcsbilly
# Repositorio: https://github.com/hgcsbilly/ssh
# ==============================================================================

# Requiere permisos de Administrador
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "[-] Este script requiere ser ejecutado como Administrador en PowerShell."
    exit 1
}

Write-Host "[*] Verificando e instalando OpenSSH Server en Windows..." -ForegroundColor Cyan
$sshCapability = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
if ($sshCapability.State -ne 'Installed') {
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
}

Write-Host "[*] Habilitando e iniciando el servicio sshd..." -ForegroundColor Cyan
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

Write-Host "[*] Configurando regla de Firewall..." -ForegroundColor Cyan
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
}

Write-Host "[*] Importando llaves publicas de GitHub (hgcsbilly)..." -ForegroundColor Cyan
$userSshDir = "$HOME\.ssh"
if (!(Test-Path $userSshDir)) {
    New-Item -ItemType Directory -Path $userSshDir -Force | Out-Null
}

$authKeys = "$userSshDir\authorized_keys"
if (!(Test-Path $authKeys)) {
    New-Item -ItemType File -Path $authKeys -Force | Out-Null
}

try {
    $keysWeb = (Invoke-RestMethod -Uri "https://github.com/hgcsbilly.keys" -UseBasicParsing) -split "`n"
    $currentKeys = Get-Content $authKeys -ErrorAction SilentlyContinue
    foreach ($k in $keysWeb) {
        $cleanKey = $k.Trim()
        if ($cleanKey.Length -gt 10 -and ($currentKeys -notcontains $cleanKey)) {
            Add-Content -Path $authKeys -Value $cleanKey
            Write-Host "  [+] Llave agregada a authorized_keys" -ForegroundColor Green
        }
    }
} catch {
    Write-Warning "  [!] No se pudieron descargar las llaves publicas de GitHub."
}

# Configurar permisos seguros para OpenSSH en Windows
icacls.exe "$authKeys" /inheritance:r /grant:r "$($env:USERNAME):(R,W)" /grant:r "SYSTEM:(R,W)" | Out-Null

$ipAddresses = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback|vEthernet' -and $_.IPAddress -notmatch '^169\.' }).IPAddress -join ', '

Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "  OPENSSH HABILITADO CORRECTAMENTE EN WINDOWS    " -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host "Usuario destino: $env:USERNAME"
Write-Host "IPs detectadas : $ipAddresses"
Write-Host "-------------------------------------------------"
Write-Host "Comando para conectarte desde otra PC:"
Write-Host "  ssh $env:USERNAME@<IP_DE_LA_MAQUINA>"
Write-Host "================================================="
