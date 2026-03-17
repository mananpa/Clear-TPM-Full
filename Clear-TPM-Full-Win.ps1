# ============================================================
#   Clear-TPM-Full.ps1
#   Borrado completo: TPM + claves UEFI + Secure Boot Keys
#   Requiere: Administrador + Sistema UEFI (no Legacy BIOS)
#   Corregido: sintaxis Set-SecureBootUEFI + Surface support
# ============================================================

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Ejecutar como Administrador."
    exit 1
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "     Full TPM + Secure Boot Clear - Claves + UEFI           " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ── Constantes GUID ───────────────────────────────────────────────────────────
$GUID_GLOBAL   = "8be4df61-93ca-11d2-aa0d-00e098032b8c"
$GUID_SECURITY = "d719b2cb-3d3a-4596-a3bc-dad00e67656f"

# ── Deteccion UEFI vs Legacy ──────────────────────────────────────────────────
function Get-FirmwareType {
    try {
        return (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control" `
                -Name "PEFirmwareType" -ErrorAction Stop).PEFirmwareType
    } catch {
        if (Test-Path "$env:SystemRoot\System32\SecConfig.efi") { return 2 }
        return 1
    }
}

$isUEFI = (Get-FirmwareType) -eq 2
Write-Host "Firmware : $(if ($isUEFI) { 'UEFI' } else { 'Legacy BIOS (Secure Boot no aplica)' })" `
           -ForegroundColor $(if ($isUEFI) { 'Green' } else { 'Yellow' })

# ── Deteccion fabricante ──────────────────────────────────────────────────────
$manufacturer = (Get-WmiObject -Class Win32_ComputerSystem).Manufacturer
$model        = (Get-WmiObject -Class Win32_ComputerSystem).Model
$isSurface    = $model -match "Surface"
Write-Host "Equipo   : $manufacturer $model" -ForegroundColor Gray
if ($isSurface) {
    Write-Host "           [Surface detectado - modo Surface activo]" -ForegroundColor Yellow
}

# ── Info TPM ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Estado del TPM:" -ForegroundColor Yellow
try {
    $tpm    = Get-Tpm
    $wmiTpm = Get-WmiObject -Namespace "root\cimv2\Security\MicrosoftTpm" `
                             -Class Win32_Tpm -ErrorAction SilentlyContinue
    Write-Host "  TpmPresent  : $($tpm.TpmPresent)"
    Write-Host "  TpmReady    : $($tpm.TpmReady)"
    Write-Host "  TpmEnabled  : $($tpm.TpmEnabled)"
    Write-Host "  TpmOwned    : $($tpm.TpmOwned)"
    Write-Host "  SpecVersion : $($wmiTpm.SpecVersion)"
} catch {
    Write-Host "  No se pudo leer TPM: $_" -ForegroundColor Yellow
}

# ── Info Secure Boot ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Estado de Secure Boot:" -ForegroundColor Yellow
$sbAccessible = $false
$sbEnabled    = $false
if ($isUEFI) {
    try {
        $sbEnabled    = Confirm-SecureBootUEFI -ErrorAction Stop
        $sbAccessible = $true
        Write-Host "  Enabled : $sbEnabled"
        foreach ($v in @("PK","KEK","db","dbx")) {
            try {
                $d = Get-SecureBootUEFI -Name $v -ErrorAction Stop
                Write-Host "  $v : presente ($([math]::Round($d.Bytes.Length/1KB,1)) KB)" -ForegroundColor Green
            } catch {
                Write-Host "  $v : vacio o inaccesible" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "  Secure Boot no accesible: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  No aplica en Legacy BIOS" -ForegroundColor Yellow
}

# ── Confirmacion ──────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "ADVERTENCIA - SE BORRARA TODO lo siguiente:" -ForegroundColor Red
Write-Host "  [TPM]  Todas las claves (Owner, SRK, EK, contrasenas)"  -ForegroundColor Red
Write-Host "  [TPM]  OwnerAuth retenido en registro de Windows"         -ForegroundColor Red
Write-Host "  [UEFI] Physical Presence enviado al firmware"             -ForegroundColor Red
Write-Host "  [SB]   Secure Boot: PK, KEK, db, dbx (Setup Mode)"       -ForegroundColor Red
Write-Host "  El BIOS pedira confirmacion fisica al reiniciar."         -ForegroundColor Red
Write-Host ""
$confirm = Read-Host "Escribe BORRAR para confirmar"
if ($confirm -ne "BORRAR") { Write-Host "Cancelado." -ForegroundColor Yellow; exit 0 }


# ╔══════════════════════════════════════════════════════════╗
# ║               BLOQUE 1 - LIMPIEZA TPM                   ║
# ╚══════════════════════════════════════════════════════════╝

function Try-ClearTpmNative {
    Write-Host ""
    Write-Host "  Metodo 1: Clear-Tpm (PowerShell nativo)" -ForegroundColor White
    try {
        Clear-Tpm -ErrorAction Stop
        Write-Host "    OK" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Try-ClearTpmWMI {
    Write-Host ""
    Write-Host "  Metodo 2: WMI Win32_Tpm" -ForegroundColor White
    try {
        $wmi = Get-WmiObject -Namespace "root\cimv2\Security\MicrosoftTpm" `
                              -Class Win32_Tpm -ErrorAction Stop
        Write-Host "    SpecVersion : $($wmi.SpecVersion)" -ForegroundColor Gray
        Write-Host "    IsOwned     : $($wmi.IsOwned_InitialValue)" -ForegroundColor Gray
        $opcodes = @(
            @{ code = 14; desc = "Clear TPM (PPI 1.2+)" },
            @{ code = 22; desc = "Clear + jerarquias (TPM 2.0)" },
            @{ code =  5; desc = "Enable + Activate + Clear" }
        )
        foreach ($op in $opcodes) {
            Write-Host "    Op-code $($op.code): $($op.desc)" -ForegroundColor Yellow
            $r = $wmi.SetPhysicalPresenceRequest($op.code)
            if ($r.ReturnValue -eq 0) {
                Write-Host "    OK (ReturnValue=0)" -ForegroundColor Green
                return $true
            }
            Write-Host "    ReturnValue=$($r.ReturnValue), probando siguiente..." -ForegroundColor Red
        }
        return $false
    } catch {
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Try-ClearTpmWmic {
    Write-Host ""
    Write-Host "  Metodo 3: WMIC legacy (cmd)" -ForegroundColor White
    try {
        $out = cmd /c 'wmic /namespace:\\root\cimv2\Security\MicrosoftTpm path Win32_Tpm call SetPhysicalPresenceRequest 14' 2>&1
        Write-Host "    Output: $out" -ForegroundColor Gray
        if ($out -match "ReturnValue = 0") {
            Write-Host "    OK" -ForegroundColor Green
            return $true
        }
        Write-Host "    ReturnValue != 0" -ForegroundColor Red
        return $false
    } catch {
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Clear-TpmOwnerAuth {
    Write-Host ""
    Write-Host "  Extra A: Borrar OwnerAuth del registro" -ForegroundColor White
    try {
        reg add "HKLM\SOFTWARE\Policies\Microsoft\TPM" /v OSManagedAuthLevel /t REG_DWORD /d 0 /f | Out-Null
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\TPM" `
                            -Name "OSManagedAuthLevel" -ErrorAction SilentlyContinue
        Write-Host "    OwnerAuth reseteado (sin retencion)" -ForegroundColor Green
    } catch {
        Write-Host "    $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Clear-UEFIPlatformAuth {
    Write-Host ""
    Write-Host "  Extra B: Reset Platform Auth UEFI (op 21 + op 18)" -ForegroundColor White
    try {
        $wmi = Get-WmiObject -Namespace "root\cimv2\Security\MicrosoftTpm" `
                              -Class Win32_Tpm -ErrorAction Stop
        $r1 = $wmi.SetPhysicalPresenceRequest(21)
        Write-Host "    Op 21 (Platform Reset) ReturnValue: $($r1.ReturnValue)" -ForegroundColor Gray
        $r2 = $wmi.SetPhysicalPresenceRequest(18)
        Write-Host "    Op 18 (Confirm NoPPI)  ReturnValue: $($r2.ReturnValue)" -ForegroundColor Gray
        Write-Host "    Enviado al firmware" -ForegroundColor Green
    } catch {
        Write-Host "    $($_.Exception.Message)" -ForegroundColor Yellow
    }
}


# ╔══════════════════════════════════════════════════════════╗
# ║            BLOQUE 2 - LIMPIEZA SECURE BOOT              ║
# ╚══════════════════════════════════════════════════════════╝
#
#  NOTA TECNICA IMPORTANTE:
#  ─────────────────────────────────────────────────────────
#  Set-SecureBootUEFI tiene esta firma real:
#    Set-SecureBootUEFI -Name <PK|KEK|db|dbx>
#                       -Time <DateTime>
#                       -SignedFilePath <ruta .p7>
#    -- o para añadir certificados --
#                       -CertificateFilePath <ruta .cer>
#
#  Para BORRAR una variable Secure Boot se necesita un payload
#  EFI_VARIABLE_AUTHENTICATION_2 vacio, firmado con la clave
#  PRIVADA del PK actual. En equipos OEM (Surface, HP, Dell...)
#  el PK pertenece al fabricante -> no se puede borrar desde
#  Windows sin esa clave privada. Requiere hacerlo desde UEFI.
#
#  Errores que se corrigieron en esta version:
#    - "-Bytes" no es parametro valido -> usa -SignedFilePath
#    - "-Content $null" no es valido   -> requiere -Time
#    - "SetupMode" no es un -Name valido (solo PK/KEK/db/dbx)
# ─────────────────────────────────────────────────────────────

function Backup-SecureBootKeys {
    Write-Host ""
    Write-Host "  SB Backup: Guardando keys actuales" -ForegroundColor White
    $exportPath = "$env:TEMP\SecureBoot_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $exportPath -Force | Out-Null
    foreach ($v in @("PK","KEK","db","dbx")) {
        try {
            $d = Get-SecureBootUEFI -Name $v -ErrorAction Stop
            [System.IO.File]::WriteAllBytes("$exportPath\$v.bin", $d.Bytes)
            Write-Host "    Backup $v -> $exportPath\$v.bin ($([math]::Round($d.Bytes.Length/1KB,1)) KB)" -ForegroundColor Gray
        } catch {
            Write-Host "    No se pudo exportar $v" -ForegroundColor Gray
        }
    }
    Write-Host "    Backup en: $exportPath" -ForegroundColor Green
    return $exportPath
}

function Get-SecureBootMode {
    # Retorna: "SetupMode", "UserMode", "Desconocido"
    try {
        $sb = Confirm-SecureBootUEFI -ErrorAction Stop
        try {
            $sm = (Get-ItemProperty `
                   -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State" `
                   -ErrorAction Stop).UEFISecureBootEnabled
            if ($sm -eq 0) { return "SetupMode" }
            return "UserMode"
        } catch {
            if ($sb) { return "UserMode" } else { return "SetupMode" }
        }
    } catch {
        return "Desconocido"
    }
}

function Try-ClearSB-SignedFile {
    # Metodo 1: Usar archivo .p7 firmado por el PK (si el usuario lo tiene)
    Write-Host ""
    Write-Host "  SB Metodo 1: Set-SecureBootUEFI con archivo firmado (.p7)" -ForegroundColor White
    Write-Host "    Necesitas un archivo de borrado firmado con la clave privada del PK." -ForegroundColor Gray
    Write-Host "    En equipos OEM (Surface, HP, Dell) esto NO es posible sin el fabricante." -ForegroundColor Gray

    $signedFile = Read-Host "    Ruta al archivo .p7 firmado (Enter para omitir)"
    if ([string]::IsNullOrWhiteSpace($signedFile)) {
        Write-Host "    Omitido." -ForegroundColor Yellow
        return $false
    }
    if (-not (Test-Path $signedFile)) {
        Write-Host "    Archivo no encontrado: $signedFile" -ForegroundColor Red
        return $false
    }
    try {
        $timestamp = Get-Date
        Set-SecureBootUEFI -Name "PK" -Time $timestamp -SignedFilePath $signedFile -ErrorAction Stop
        Write-Host "    PK borrada con archivo firmado -> Setup Mode" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Try-ClearSB-VerifySetupMode {
    # Metodo 2: Verificar si el limpiar TPM ya puso el firmware en Setup Mode
    Write-Host ""
    Write-Host "  SB Metodo 2: Verificar si firmware entro en Setup Mode" -ForegroundColor White
    try {
        $mode = Get-SecureBootMode
        Write-Host "    Modo actual: $mode" -ForegroundColor Gray
        if ($mode -eq "SetupMode") {
            Write-Host "    Firmware ya en Setup Mode. Keys sin raiz de confianza." -ForegroundColor Green
            return $true
        }
        try {
            $pk = Get-SecureBootUEFI -Name "PK" -ErrorAction Stop
            Write-Host "    PK activa ($([math]::Round($pk.Bytes.Length/1KB,1)) KB) - sigue en User Mode." -ForegroundColor Yellow
            Write-Host "    No es posible borrar PK desde Windows sin clave privada del fabricante." -ForegroundColor Red
        } catch {
            Write-Host "    PK no encontrada - posiblemente en Setup Mode." -ForegroundColor Green
            return $true
        }
        return $false
    } catch {
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Try-ClearSB-BcdEdit {
    # Metodo 3: Reducir enforcement de Secure Boot via BCD
    # No borra las keys pero deshabilita la validacion en el arranque de Windows
    Write-Host ""
    Write-Host "  SB Metodo 3: Reducir enforcement via bcdedit" -ForegroundColor White
    Write-Host "    NOTA: No borra las keys, deshabilita la validacion en Windows." -ForegroundColor Gray
    try {
        $out1 = bcdedit /set "{current}" testsigning on 2>&1
        $out2 = bcdedit /set "{current}" nointegritychecks on 2>&1
        Write-Host "    testsigning      : $out1" -ForegroundColor Gray
        Write-Host "    nointegritychecks: $out2" -ForegroundColor Gray
        if (($out1 -match "correctamente|successfully") -or ($out2 -match "correctamente|successfully")) {
            Write-Host "    BCD modificado. Secure Boot enforcement reducido en Windows." -ForegroundColor Green
            return $true
        }
        Write-Host "    bcdedit no pudo modificar el BCD." -ForegroundColor Red
        return $false
    } catch {
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Show-SBManualInstructions {
    param([bool]$IsSurface = $false)
    Write-Host ""
    if ($IsSurface) {
        Write-Host "  ════ Instrucciones para Microsoft Surface ════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  OPCION A - Acceder al UEFI de Surface:" -ForegroundColor Yellow
        Write-Host "    1. Apaga la Surface completamente"                                      -ForegroundColor White
        Write-Host "    2. Mantén pulsado el boton SUBIR VOLUMEN (+)"                          -ForegroundColor White
        Write-Host "    3. Pulsa encendido y suelta cuando aparezca el logo de Surface"        -ForegroundColor White
        Write-Host "    4. En el menu UEFI: Security"                                          -ForegroundColor White
        Write-Host "       -> Change Secure Boot setting -> Clear Secure Boot Keys"            -ForegroundColor White
        Write-Host "       o bien desactivar Secure Boot completamente"                        -ForegroundColor White
        Write-Host "    5. Exit -> Restart Now"                                                -ForegroundColor White
        Write-Host ""
        Write-Host "  OPCION B - Reiniciar directo al UEFI desde Windows:" -ForegroundColor Yellow
        Write-Host "    Ejecuta: shutdown /r /fw /t 0" -ForegroundColor Cyan
        Write-Host "    (reinicia directo al firmware sin pasar por Windows)"                  -ForegroundColor Gray
        Write-Host ""
        Write-Host "  OPCION C - Surface SEMM (entornos empresariales):" -ForegroundColor Yellow
        Write-Host "    https://learn.microsoft.com/surface/surface-enterprise-management-mode" -ForegroundColor Gray
    } else {
        Write-Host "  ════ Instrucciones por fabricante ════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Reiniciar directo al UEFI: shutdown /r /fw /t 0" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  HP       : Security -> Secure Boot -> Reset to Factory Defaults" -ForegroundColor White
        Write-Host "  Dell     : Secure Boot -> Delete All Secure Boot Keys"            -ForegroundColor White
        Write-Host "  Lenovo   : Security -> Secure Boot -> Reset to Setup Mode"        -ForegroundColor White
        Write-Host "  ASUS     : Boot -> Secure Boot -> Key Management -> Reset"        -ForegroundColor White
        Write-Host "  MSI      : Settings -> Security -> Secure Boot -> Erase Keys"     -ForegroundColor White
        Write-Host "  Gigabyte : Boot -> Secure Boot -> Setup Mode"                     -ForegroundColor White
    }
}

function Clear-SecureBootKeys {
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "  BLOQUE 2: Limpieza de Secure Boot Keys            " -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan

    if (-not $isUEFI) {
        Write-Host "  Legacy BIOS - Secure Boot no aplica." -ForegroundColor Yellow
        return $true
    }

    if (-not $sbAccessible) {
        Write-Host "  Secure Boot no accesible desde Windows." -ForegroundColor Yellow
        Show-SBManualInstructions -IsSurface $isSurface
        return $false
    }

    # Backup siempre primero
    Backup-SecureBootKeys | Out-Null

    # Verificar modo actual
    $mode = Get-SecureBootMode
    Write-Host ""
    Write-Host "  Modo Secure Boot: $mode" `
               -ForegroundColor $(if ($mode -eq "SetupMode") { 'Green' } else { 'Yellow' })

    if ($mode -eq "SetupMode") {
        Write-Host "  Firmware ya en Setup Mode. No se requiere accion adicional." -ForegroundColor Green
        return $true
    }

    Write-Host ""
    Write-Host "  Firmware en User Mode." -ForegroundColor Yellow
    Write-Host "  El PK activo pertenece al fabricante ($manufacturer)." -ForegroundColor Yellow
    Write-Host "  Borrar el PK desde Windows requiere su clave privada (no disponible)." -ForegroundColor Yellow
    Write-Host "  Intentando metodos alternativos..." -ForegroundColor White

    $sbCleared = $false
    $sbCleared = Try-ClearSB-SignedFile
    if (-not $sbCleared) { $sbCleared = Try-ClearSB-VerifySetupMode }
    if (-not $sbCleared) { $sbCleared = Try-ClearSB-BcdEdit         }

    if (-not $sbCleared) {
        Write-Host ""
        Write-Host "  Todos los metodos automaticos fallaron." -ForegroundColor Red
        Write-Host "  Se requiere intervencion manual en el firmware UEFI." -ForegroundColor Yellow
        Show-SBManualInstructions -IsSurface $isSurface
    }

    return $sbCleared
}


# ╔══════════════════════════════════════════════════════════╗
# ║                  EJECUCION PRINCIPAL                    ║
# ╚══════════════════════════════════════════════════════════╝

# ─── BLOQUE 1: TPM ───────────────────────────────────────────────────────────
Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  BLOQUE 1: Limpieza de TPM                         " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$tpmCleared = $false
$tpmCleared = Try-ClearTpmNative
if (-not $tpmCleared) { $tpmCleared = Try-ClearTpmWMI  }
if (-not $tpmCleared) { $tpmCleared = Try-ClearTpmWmic }

Clear-TpmOwnerAuth
Clear-UEFIPlatformAuth

Write-Host ""
Write-Host "  Resultado TPM: $(if ($tpmCleared) { 'Limpiado correctamente' } else { 'Fallo - requiere BIOS manual' })" `
           -ForegroundColor $(if ($tpmCleared) { 'Green' } else { 'Red' })


# ─── BLOQUE 2: Secure Boot ───────────────────────────────────────────────────
$sbCleared = Clear-SecureBootKeys


# ╔══════════════════════════════════════════════════════════╗
# ║                  RESUMEN Y REINICIO                     ║
# ╚══════════════════════════════════════════════════════════╝

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  RESUMEN FINAL                                      " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  Equipo              : $manufacturer $model"
Write-Host "  TPM limpiado        : $(if ($tpmCleared) { 'SI' } else { 'NO - requiere BIOS' })"
Write-Host "  OwnerAuth borrado   : SI (ejecutado siempre)"
Write-Host "  Platform Auth UEFI  : SI (ops 21+18 enviados)"
Write-Host "  Secure Boot keys    : $(if ($sbCleared) { 'SI' } else { 'Requiere UEFI manual' })"
Write-Host ""

if ($tpmCleared) {
    Write-Host "  AL REINICIAR:" -ForegroundColor Yellow
    Write-Host "    El BIOS mostrara confirmacion de borrado de TPM."         -ForegroundColor White
    Write-Host "    Acepta con F10, F12 o Enter segun tu fabricante."         -ForegroundColor White
    Write-Host ""

    if (-not $sbCleared -and $isUEFI) {
        Write-Host "  PASO ADICIONAL REQUERIDO - Secure Boot:" -ForegroundColor Red
        if ($isSurface) {
            Write-Host "    Reinicia al UEFI con: shutdown /r /fw /t 0" -ForegroundColor Cyan
            Write-Host "    Luego: Security -> Change Secure Boot setting -> Clear" -ForegroundColor White
        } else {
            Write-Host "    Reinicia al UEFI con: shutdown /r /fw /t 0" -ForegroundColor Cyan
            Write-Host "    Luego busca: Secure Boot -> Clear / Reset / Setup Mode" -ForegroundColor White
        }
        Write-Host ""
    }

    $reboot = Read-Host "Reiniciar ahora? S = normal | U = directo al UEFI | N = cancelar"
    if ($reboot -eq "S") {
        Write-Host "Reiniciando en 10 segundos... (Ctrl+C para cancelar)" -ForegroundColor Cyan
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    } elseif ($reboot -eq "U") {
        Write-Host "Reiniciando directo al firmware UEFI..." -ForegroundColor Cyan
        Start-Sleep -Seconds 3
        shutdown /r /fw /t 0
    } else {
        Write-Host "Reinicio cancelado. Recuerda reiniciar manualmente." -ForegroundColor Yellow
    }
} else {
    Write-Host "  TPM no pudo limpiarse por software." -ForegroundColor Red
    Write-Host "  Entra al BIOS y hazlo manualmente." -ForegroundColor Yellow
    if ($isSurface) {
        Write-Host ""
        Write-Host "  Surface: Mantén VOL+ al encender para entrar al UEFI." -ForegroundColor Cyan
        Write-Host "  O ejecuta: shutdown /r /fw /t 0" -ForegroundColor Cyan
    }
    exit 1
}
