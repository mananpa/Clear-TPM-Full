# ============================================================
#   Clear-TPM-Full.ps1
#   Borrado completo: TPM + claves UEFI + Secure Boot Keys
#   Requiere: Administrador + Sistema UEFI (no Legacy BIOS)
#   v4.2: Auto-elevacion + idioma automatico + teclas UEFI por marca
#   Encoding: UTF-8 BOM (requerido por PowerShell para Unicode)
# ============================================================

# Auto-elevacion: si no es Admin, relanzar como Admin via UAC
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal   = [Security.Principal.WindowsPrincipal]$currentUser
$isAdmin     = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Solicitando privilegios de Administrador..." -ForegroundColor Yellow
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    try {
        Start-Process -FilePath "powershell.exe" `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
            -Verb RunAs -ErrorAction Stop
        exit 0
    } catch {
        Write-Host ""
        Write-Host "ERROR: No se pudo elevar a Administrador." -ForegroundColor Red
        Write-Host "ERROR: Could not elevate to Administrator." -ForegroundColor Red
        Write-Host ""
        Write-Host "Opciones manuales / Manual options:" -ForegroundColor Yellow
        Write-Host "  1. Click derecho en el .ps1 -> Ejecutar con PowerShell" -ForegroundColor White
        Write-Host "  2. Abrir PowerShell como Admin y ejecutar el script" -ForegroundColor White
        Write-Host "  3. Right-click .ps1 -> Run with PowerShell" -ForegroundColor White
        Write-Host ""
        pause
        exit 1
    }
}

# ======================================================
#  DETECCION DE IDIOMA DEL SISTEMA
# ======================================================

function Get-SystemLanguage { try { return (Get-Culture).Name } catch { return "en-US" } }
function Get-LangBase { param([string]$c); if ($c -match "^([a-zA-Z]{2,3})-") { return $Matches[1].ToLower() }; return $c.ToLower() }
$Lang = Get-LangBase (Get-SystemLanguage)

# ======================================================
#  TABLA DE TRADUCCIONES
#  Idiomas con escritura latina: es en fr de it pt nl pl
#  cs sk hu ro hr sl sr ca eu gl af sv da fi nb tr id ms vi
#  Idiomas con Unicode: ru uk bg el he ar fa hi bn th ja zh ko sw
# ======================================================

$Strings = @{
  "header_title" = @{
    es="Full TPM + Secure Boot - Borrado Completo de Claves + UEFI"
    en="Full TPM + Secure Boot - Complete Keys + UEFI Wipe"
    fr="Effacement complet TPM + Secure Boot - Cles + UEFI"
    de="Vollstaendige TPM + Secure Boot Loeschung - Schluessel + UEFI"
    it="Cancellazione completa TPM + Secure Boot - Chiavi + UEFI"
    pt="Limpeza completa TPM + Secure Boot - Chaves + UEFI"
    nl="Volledige TPM + Secure Boot wissen - Sleutels + UEFI"
    pl="Pelne czyszczenie TPM + Secure Boot - Klucze + UEFI"
    ru="Полная очистка TPM + Secure Boot"
    uk="Повне очищення TPM + Secure Boot"
    bg="Пълно изчистване TPM + Secure Boot"
    el="Πλήρης εκκαθάριση TPM + Secure Boot"
    he="מחיקה מלאה של TPM + Secure Boot"
    ar="مسح كامل TPM + Secure Boot"
    fa="پاکسازی کامل TPM + Secure Boot"
    hi="पूर्ण TPM + सुरक्षित बूट क्लीयर"
    th="ล้าง TPM + Secure Boot ทั้งหมด"
    ja="TPM + セキュアブート完全消去"
    zh="完整清除 TPM + 安全启动"
    ko="전체 TPM + 보안 부팅 지우기"
    tr="Tam TPM + Guvenli Baslangic Temizleme"
    sv="Fullstandig TPM + Secure Boot rensning"
    da="Fuld TPM + Secure Boot rensning"
    fi="Taydellinen TPM + Secure Boot tyhjennys"
    nb="Full toemming av TPM + Secure Boot"
    cs="Uplne vymazani TPM + Secure Boot"
    sk="Uplne vymazanie TPM + Secure Boot"
    hu="Teljes TPM + Secure Boot torles"
    ro="Stergere completa TPM + Secure Boot"
    hr="Potpuno brisanje TPM + Secure Boot"
    id="Hapus Lengkap TPM + Secure Boot"
    ms="Padam Penuh TPM + Secure Boot"
    vi="Xoa hoan toan TPM + Secure Boot"
    sw="Futa Kamili TPM + Secure Boot"
    af="Volledige TPM + Secure Boot Skoonmaak"
    ca="Neteja completa TPM + Secure Boot"
    eu="TPM + Secure Boot ezabatze osoa"
    gl="Limpeza completa TPM + Secure Boot"
    default="Full TPM + Secure Boot - Complete Keys + UEFI Wipe"
  }
  "firmware_uefi" = @{ default="UEFI" }
  "firmware_leg"  = @{
    es="Legacy BIOS (Secure Boot no aplica)"
    en="Legacy BIOS (Secure Boot not applicable)"
    fr="Legacy BIOS (Secure Boot non applicable)"
    de="Legacy BIOS (Secure Boot nicht anwendbar)"
    it="Legacy BIOS (Secure Boot non applicabile)"
    pt="Legacy BIOS (Secure Boot nao aplicavel)"
    ru="Legacy BIOS (Secure Boot не применимо)"
    ja="レガシーBIOS（セキュアブート非対応）"
    zh="传统BIOS（安全启动不适用）"
    tr="Eski BIOS (Guvenli Baslangic gecerli degil)"
    default="Legacy BIOS (Secure Boot not applicable)"
  }
  "tpm_status"   = @{ es="Estado del TPM:"; en="TPM Status:"; fr="Etat du TPM:"; de="TPM-Status:"; it="Stato del TPM:"; pt="Estado do TPM:"; ru="TPM состояние:"; ja="TPMの状態:"; zh="TPM 状态:"; ko="TPM 상태:"; tr="TPM Durumu:"; default="TPM Status:" }
  "sb_status"    = @{ es="Estado de Secure Boot:"; en="Secure Boot Status:"; fr="Etat du Secure Boot:"; de="Secure Boot-Status:"; ru="Secure Boot состояние:"; ja="セキュアブート状態:"; zh="安全启动状态:"; default="Secure Boot Status:" }
  "present_kb"   = @{ es="presente"; en="present"; fr="present"; de="vorhanden"; it="presente"; pt="presente"; ru="присутствует"; ja="存在"; zh="存在"; ko="있음"; default="present" }
  "empty_key"    = @{ es="vacio o inaccesible"; en="empty or inaccessible"; fr="vide ou inaccessible"; de="leer oder nicht zugaenglich"; ru="пусто или недоступно"; ja="空またはアクセス不可"; zh="空或不可访问"; default="empty or inaccessible" }
  "warn_title"   = @{ es="ADVERTENCIA - SE BORRARA TODO:"; en="WARNING - THE FOLLOWING WILL BE ERASED:"; fr="AVERTISSEMENT - TOUT CE QUI SUIT SERA EFFACE:"; de="WARNUNG - FOLGENDES WIRD GELOESCHT:"; it="ATTENZIONE - VERRA CANCELLATO TUTTO:"; pt="AVISO - O SEGUINTE SERA APAGADO:"; ru="ПРЕДУПРЕЖДЕНИЕ - БУДЕТ УДАЛЕНО:"; ja="警告 - 以下が消去されます:"; zh="警告 - 以下内容将被删除:"; default="WARNING - THE FOLLOWING WILL BE ERASED:" }
  "warn1" = @{ es="[TPM]  Todas las claves (Owner, SRK, EK, contrasenas)"; en="[TPM]  All keys (Owner, SRK, EK, passwords)"; fr="[TPM]  Toutes les cles (Owner, SRK, EK, mots de passe)"; de="[TPM]  Alle Schluessel (Owner, SRK, EK, Passwoerter)"; ru="[TPM]  Все ключи (Owner, SRK, EK, пароли)"; ja="[TPM]  すべてのキー"; zh="[TPM]  所有密鑰"; default="[TPM]  All keys (Owner, SRK, EK, passwords)" }
  "warn2" = @{ es="[TPM]  OwnerAuth retenido en registro de Windows"; en="[TPM]  OwnerAuth retained in Windows registry"; fr="[TPM]  OwnerAuth conserve dans le registre Windows"; de="[TPM]  OwnerAuth in der Windows-Registrierung"; ru="[TPM]  OwnerAuth в реестре Windows"; ja="[TPM]  WindowsレジストリのOwnerAuth"; zh="[TPM]  注册表中的 OwnerAuth"; default="[TPM]  OwnerAuth retained in Windows registry" }
  "warn3" = @{ es="[UEFI] Physical Presence enviado al firmware"; en="[UEFI] Physical Presence sent to firmware"; fr="[UEFI] Physical Presence envoye au firmware"; de="[UEFI] Physical Presence an Firmware gesendet"; ru="[UEFI] Physical Presence в прошивке"; ja="[UEFI] ファームウェアへPhysical Presence送信"; zh="[UEFI] Physical Presence 已发送到固件"; default="[UEFI] Physical Presence sent to firmware" }
  "warn4" = @{ es="[SB]   Secure Boot: PK, KEK, db, dbx (Setup Mode)"; en="[SB]   Secure Boot: PK, KEK, db, dbx (Setup Mode)"; fr="[SB]   Secure Boot: PK, KEK, db, dbx (Mode Setup)"; de="[SB]   Secure Boot: PK, KEK, db, dbx (Setup-Modus)"; ru="[SB]   Secure Boot: PK, KEK, db, dbx"; ja="[SB]   Secure Boot: PK, KEK, db, dbx"; zh="[SB]   安全启动: PK, KEK, db, dbx"; default="[SB]   Secure Boot: PK, KEK, db, dbx (Setup Mode)" }
  "warn5" = @{ es="El BIOS pedira confirmacion fisica al reiniciar."; en="BIOS will request physical confirmation on reboot."; fr="Le BIOS demandera confirmation physique au redemarrage."; de="BIOS fordert beim Neustart physische Bestaetigung."; ru="Байос запросит подтверждение."; ja="BIOSが確認を要求します。"; zh="BIOS 将要求物理确认。"; default="BIOS will request physical confirmation on reboot." }
  "confirm_prompt" = @{
    es="Escribe BORRAR para confirmar"; en="Type ERASE to confirm"; fr="Tapez EFFACER pour confirmer"
    de="Geben Sie LOESCHEN ein"; it="Digita CANCELLA per confermare"; pt="Digite APAGAR para confirmar"
    nl="Typ WISSEN om te bevestigen"; pl="Wpisz WYCZYSC aby potwierdzic"; ru="Введите УДАЛИТЬ"
    ja="KESU と入力してください"; zh="输入 SHANCHU 确认"; ko="JUDA를 입력하세요"
    tr="Onaylamak icin SIL yazin"; sv="Skriv RADERA for att bekrafta"; da="Skriv SLET for at bekraefte"
    fi="Kirjoita TYHJENNA vahvistaaksesi"; nb="Skriv SLETT for aa bekrefte"; cs="Napiste VYMAZAT pro potvrzeni"
    sk="Napiste VYMAZAT pre potvrdenie"; hu="Irja be TORLES a megerositeshez"; ro="Tastati STERGERE pentru confirmare"
    hr="Unesite BRISANJE za potvrdu"; he="הקלד מחק לאישור"
    ar="اكتب احذف للتأكيد"
    th="พิมพ์ ลบ เพื่อยืนยัน"
    id="Ketik HAPUS untuk konfirmasi"; ms="Taip PADAM untuk mengesahkan"
    hi="MITA टाइप करें"; fa="HAZF را تایپ کنید"
    sw="Andika FUTA kuthibitisha"; default="Type ERASE to confirm"
  }
  "confirm_word" = @{
    es="BORRAR"; en="ERASE"; fr="EFFACER"; de="LOESCHEN"; it="CANCELLA"; pt="APAGAR"
    nl="WISSEN"; pl="WYCZYSC"; ru="УДАЛИТЬ"; ja="KESU"
    zh="SHANCHU"; ko="JUDA"; tr="SIL"; sv="RADERA"; da="SLET"; fi="TYHJENNA"; nb="SLETT"
    cs="VYMAZAT"; sk="VYMAZAT"; hu="TORLES"; ro="STERGERE"; hr="BRISANJE"
    he="מחק"; ar="احذف"; th="ลบ"
    id="HAPUS"; ms="PADAM"; hi="MITA"; fa="HAZF"; sw="FUTA"; default="ERASE"
  }
  "cancelled"    = @{ es="Cancelado."; en="Cancelled."; fr="Annule."; de="Abgebrochen."; it="Annullato."; pt="Cancelado."; ru="Отменено."; ja="キャンセル。"; zh="已取消。"; ko="취소."; tr="Iptal edildi."; default="Cancelled." }
  "blk1_title"   = @{ es="BLOQUE 1: Limpieza de TPM"; en="BLOCK 1: TPM Cleanup"; fr="BLOC 1: Nettoyage TPM"; de="BLOCK 1: TPM-Bereinigung"; it="BLOCCO 1: Pulizia TPM"; pt="BLOCO 1: Limpeza TPM"; ru="БЛОК 1: Очистка TPM"; ja="ブロック1: TPMクリーンアップ"; zh="兗1: TPM 清理"; default="BLOCK 1: TPM Cleanup" }
  "blk2_title"   = @{ es="BLOQUE 2: Limpieza de Secure Boot Keys"; en="BLOCK 2: Secure Boot Keys Cleanup"; fr="BLOC 2: Nettoyage cles Secure Boot"; de="BLOCK 2: Secure Boot-Schluessel Bereinigung"; ru="БЛОК 2: Очистка ключей Secure Boot"; ja="ブロック2: セキュアブートキークリーンアップ"; zh="兗2: 安全启动密鑰清理"; default="BLOCK 2: Secure Boot Keys Cleanup" }
  "sum_title"    = @{ es="RESUMEN FINAL"; en="FINAL SUMMARY"; fr="RESUME FINAL"; de="ABSCHLUSSZUSAMMENFASSUNG"; it="RIEPILOGO FINALE"; pt="RESUMO FINAL"; ru="ИТОГОВЫЙ ОТЧЕТ"; ja="最終サマリー"; zh="最终摘要"; ko="여과 요약"; default="FINAL SUMMARY" }
  "m1"    = @{ es="Metodo 1: Clear-Tpm (PowerShell nativo)"; en="Method 1: Clear-Tpm (native PowerShell)"; fr="Methode 1: Clear-Tpm (PowerShell natif)"; de="Methode 1: Clear-Tpm (natives PowerShell)"; ru="Метод 1: Clear-Tpm"; ja="方法1: Clear-Tpm"; zh="方法1: Clear-Tpm"; default="Method 1: Clear-Tpm (native PowerShell)" }
  "m2"    = @{ es="Metodo 2: WMI Win32_Tpm"; en="Method 2: WMI Win32_Tpm"; fr="Methode 2: WMI Win32_Tpm"; de="Methode 2: WMI Win32_Tpm"; ru="Метод 2: WMI Win32_Tpm"; ja="方法2: WMI Win32_Tpm"; zh="方法2: WMI Win32_Tpm"; default="Method 2: WMI Win32_Tpm" }
  "m3"    = @{ es="Metodo 3: WMIC legacy (cmd)"; en="Method 3: WMIC legacy (cmd)"; fr="Methode 3: WMIC heritage (cmd)"; de="Methode 3: WMIC Legacy (cmd)"; ru="Метод 3: WMIC legacy"; ja="方法3: WMIClegacy"; zh="方法3: WMIC 旧版"; default="Method 3: WMIC legacy (cmd)" }
  "ok"    = @{ default="OK" }
  "err"   = @{ es="Error"; en="Error"; fr="Erreur"; de="Fehler"; it="Errore"; pt="Erro"; ru="Ошибка"; ja="エラー"; zh="错误"; default="Error" }
  "next"  = @{ es="probando siguiente..."; en="trying next..."; fr="essai suivant..."; de="naechste versuchen..."; ru="пробую следующий..."; ja="次を試行中..."; zh="尝试下一个..."; default="trying next..." }
  "extra_a"    = @{ es="Extra A: Borrar OwnerAuth del registro"; en="Extra A: Clear OwnerAuth from registry"; fr="Extra A: Effacer OwnerAuth du registre"; de="Extra A: OwnerAuth aus Registrierung loeschen"; ru="Доп. A: Удалить OwnerAuth из реестра"; ja="Extra A: レジストリからOwnerAuth削除"; zh="附加A: 清除注册表 OwnerAuth"; default="Extra A: Clear OwnerAuth from registry" }
  "extra_a_ok" = @{ es="OwnerAuth reseteado (sin retencion)"; en="OwnerAuth reset (no retention)"; fr="OwnerAuth reinitialise (sans retention)"; de="OwnerAuth zurueckgesetzt"; ru="OwnerAuth сброшен"; ja="OwnerAuthリセット済み"; zh="OwnerAuth 已重置"; default="OwnerAuth reset (no retention)" }
  "extra_b"    = @{ es="Extra B: Reset Platform Auth UEFI (op 21 + op 18)"; en="Extra B: Reset UEFI Platform Auth (op 21 + op 18)"; fr="Extra B: Reinitialisation Platform Auth UEFI"; de="Extra B: UEFI Platform Auth zuruecksetzen"; ru="Доп. B: Сброс UEFI Platform Auth"; ja="Extra B: UEFIプラットフォーム認証リセット"; zh="附加B: 重置 UEFI 平台认证"; default="Extra B: Reset UEFI Platform Auth (op 21 + op 18)" }
  "sent_fw"    = @{ es="Enviado al firmware"; en="Sent to firmware"; fr="Envoye au firmware"; de="An Firmware gesendet"; ru="Отправлено в прошивку"; ja="ファームウェアに送信済み"; zh="已发送到固件"; default="Sent to firmware" }
  "res_ok"     = @{ es="Resultado TPM: Limpiado correctamente"; en="TPM Result: Cleaned successfully"; fr="Resultat TPM: Nettoye avec succes"; de="TPM-Ergebnis: Erfolgreich bereinigt"; ru="Результат TPM: Успешно очищен"; ja="TPM結果: 正常にクリーンアップ"; zh="TPM 结果：清理成功"; default="TPM Result: Cleaned successfully" }
  "res_fail"   = @{ es="Resultado TPM: Fallo - requiere BIOS manual"; en="TPM Result: Failed - requires manual BIOS"; fr="Resultat TPM: Echec - BIOS manuel requis"; de="TPM-Ergebnis: Fehlgeschlagen - manuelles BIOS"; ru="Результат TPM: Ошибка - ручной BIOS"; ja="TPM結果: 失敗 - 手動BIOS必要"; zh="TPM 结果：失败 - 需要手动 BIOS"; default="TPM Result: Failed - requires manual BIOS" }
  "sb_backup"  = @{ es="SB Backup: Guardando keys actuales"; en="SB Backup: Saving current keys"; fr="SB Sauvegarde: Enregistrement des cles"; de="SB-Sicherung: Schluessel speichern"; ru="SB резерв: Сохранение ключей"; ja="SBバックアップ: キー保存"; zh="SB 备份：保存当前密鑰"; default="SB Backup: Saving current keys" }
  "sb_backup_in"=@{ es="Backup en"; en="Backup in"; fr="Sauvegarde dans"; de="Sicherung in"; ru="Резервная копия в"; ja="バックアップ先"; zh="备份位置"; default="Backup in" }
  "sb_mode"    = @{ es="Modo Secure Boot"; en="Secure Boot Mode"; fr="Mode Secure Boot"; de="Secure Boot-Modus"; ru="Режим Secure Boot"; ja="セキュアブートモード"; zh="安全启动模式"; default="Secure Boot Mode" }
  "sb_setup_ok"= @{ es="Firmware ya en Setup Mode. No se requiere accion adicional."; en="Firmware already in Setup Mode. No additional action required."; fr="Firmware deja en mode Setup."; de="Firmware bereits im Setup-Modus."; ru="Прошивка уже в режиме Setup."; ja="ファームウェアはセットアップモードです。"; zh="固件已处于设置模式。"; default="Firmware already in Setup Mode. No additional action required." }
  "sb_user_mode"=@{ es="Firmware en User Mode."; en="Firmware in User Mode."; fr="Firmware en mode utilisateur."; de="Firmware im Benutzermodus."; ru="Прошивка в пользовательском режиме."; ja="ファームウェアはユーザーモードです。"; zh="固件处于用户模式。"; default="Firmware in User Mode." }
  "sb_pk_owner"= @{ es="El PK activo pertenece al fabricante"; en="The active PK belongs to the manufacturer"; fr="La PK active appartient au fabricant"; de="Der aktive PK gehoert dem Hersteller"; ru="Активный PK принадлежит производителю"; ja="PKはメーカーに属します"; zh="活动 PK 属于制造商"; default="The active PK belongs to the manufacturer" }
  "sb_pk_nokey"= @{ es="Borrar el PK desde Windows requiere su clave privada (no disponible)."; en="Deleting PK from Windows requires its private key (not available)."; fr="La suppression PK necessite sa cle privee (non disponible)."; de="PK-Loeschung erfordert privaten Schluessel (nicht verfuegbar)."; ru="Удаление PK требует закрытого ключа (недоступен)."; ja="PK削除には秘密鍵が必要（利用不可）。"; zh="删除 PK 需要私鑰（不可用）。"; default="Deleting PK from Windows requires its private key (not available)." }
  "sb_trying"  = @{ es="Intentando metodos alternativos..."; en="Trying alternative methods..."; fr="Tentative de methodes alternatives..."; de="Alternative Methoden werden versucht..."; ru="Пробую альтернативные методы..."; ja="代替手段を試行中..."; zh="尝试替代方法..."; default="Trying alternative methods..." }
  "sb_all_fail"= @{ es="Todos los metodos automaticos fallaron."; en="All automatic methods failed."; fr="Toutes les methodes automatiques ont echoue."; de="Alle automatischen Methoden fehlgeschlagen."; ru="Все автоматические методы не сработали."; ja="自動的な方法はすべて失敗しました。"; zh="所有自动方法均失败。"; default="All automatic methods failed." }
  "sb_manual_req"=@{ es="Se requiere intervencion manual en el firmware UEFI."; en="Manual intervention in the UEFI firmware is required."; fr="Intervention manuelle dans le firmware UEFI requise."; de="Manueller Eingriff in UEFI-Firmware erforderlich."; ru="Требуется ручное вмешательство в UEFI."; ja="UEFIファームウェアへの手動操作が必要です。"; zh="需要手动操作 UEFI 固件。"; default="Manual intervention in the UEFI firmware is required." }
  "sbm1"       = @{ es="SB Metodo 1: Set-SecureBootUEFI con archivo firmado (.p7)"; en="SB Method 1: Set-SecureBootUEFI with signed file (.p7)"; fr="SB Methode 1: Set-SecureBootUEFI avec fichier signe"; de="SB Methode 1: Set-SecureBootUEFI mit signierter Datei"; ru="SB Метод 1: Set-SecureBootUEFI с подписанным файлом"; default="SB Method 1: Set-SecureBootUEFI with signed file (.p7)" }
  "sbm1_need"  = @{ es="Necesitas archivo firmado con la clave privada del PK."; en="You need a file signed with the PK private key."; fr="Vous avez besoin d un fichier signe avec la cle privee PK."; de="Sie benoetigen eine mit dem privaten PK-Schluessel signierte Datei."; ru="Нужен файл, подписанный закрытым ключом PK."; default="You need a file signed with the PK private key." }
  "sbm1_oem"   = @{ es="En equipos OEM esto NO es posible sin el fabricante."; en="On OEM devices this is NOT possible without the manufacturer."; fr="Sur les appareils OEM cela n est PAS possible sans le fabricant."; de="Bei OEM-Geraeten NICHT moeglich ohne den Hersteller."; ru="На OEM-устройствах НЕВОЗМОЖНО без производителя."; default="On OEM devices this is NOT possible without the manufacturer." }
  "sbm1_path"  = @{ es="Ruta al archivo .p7 firmado (Enter para omitir)"; en="Path to signed .p7 file (Enter to skip)"; fr="Chemin vers le fichier .p7 signe (Entree pour ignorer)"; de="Pfad zur signierten .p7-Datei (Eingabe zum Ueberspringen)"; ru="Путь к .p7 файлу (Enter для пропуска)"; default="Path to signed .p7 file (Enter to skip)" }
  "sbm1_skip"  = @{ es="Omitido."; en="Skipped."; fr="Ignore."; de="Uebersprungen."; ru="Пропущено."; ja="スキップ。"; zh="已跳过。"; default="Skipped." }
  "sbm1_nf"    = @{ es="Archivo no encontrado"; en="File not found"; fr="Fichier introuvable"; de="Datei nicht gefunden"; ru="Файл не найден"; default="File not found" }
  "sbm2"       = @{ es="SB Metodo 2: Verificar si firmware entro en Setup Mode"; en="SB Method 2: Verify if firmware entered Setup Mode"; fr="SB Methode 2: Verifier si firmware est en mode Setup"; de="SB Methode 2: Pruefen ob Firmware in Setup-Modus"; ru="SB Метод 2: Проверить режим Setup"; default="SB Method 2: Verify if firmware entered Setup Mode" }
  "sbm2_active"= @{ es="PK activa - sigue en User Mode."; en="PK active - still in User Mode."; fr="PK active - toujours en mode utilisateur."; de="PK aktiv - noch im Benutzermodus."; ru="PK активен - всё ещё User Mode."; default="PK active - still in User Mode." }
  "sbm3"       = @{ es="SB Metodo 3: Reducir enforcement via bcdedit"; en="SB Method 3: Reduce enforcement via bcdedit"; fr="SB Methode 3: Reduire l enforcement via bcdedit"; de="SB Methode 3: Durchsetzung ueber bcdedit reduzieren"; ru="SB Метод 3: Снизить принудительное через bcdedit"; default="SB Method 3: Reduce enforcement via bcdedit" }
  "sbm3_note"  = @{ es="NOTA: No borra las keys, deshabilita la validacion en Windows."; en="NOTE: Does not delete keys, disables validation in Windows."; fr="REMARQUE: Ne supprime pas les cles, desactive la validation."; de="HINWEIS: Loescht keine Schluessel, deaktiviert Validierung."; ru="ПРИМЕЧАНИЕ: Не удаляет ключи, отключает проверку."; default="NOTE: Does not delete keys, disables validation in Windows." }
  "sum_dev"    = @{ es="Equipo            "; en="Device            "; fr="Appareil          "; de="Geraet            "; ru="Устройство      "; ja="デバイス          "; zh="设备              "; default="Device            " }
  "sum_tpm"    = @{ es="TPM limpiado      "; en="TPM cleaned       "; fr="TPM nettoye       "; de="TPM bereinigt     "; ru="TPM очищен       "; ja="TPMクリーン        "; zh="TPM 已清理         "; default="TPM cleaned       " }
  "sum_owner"  = @{ es="OwnerAuth borrado "; en="OwnerAuth cleared "; fr="OwnerAuth efface  "; de="OwnerAuth geloescht"; ru="OwnerAuth удалён  "; ja="OwnerAuth消去      "; zh="OwnerAuth 已清除    "; default="OwnerAuth cleared " }
  "sum_plat"   = @{ default="Platform Auth UEFI" }
  "sum_sb"     = @{ es="Secure Boot keys  "; en="Secure Boot keys  "; fr="Cles Secure Boot  "; de="Secure Boot-Schluessel"; ru="Ключи Secure Boot "; ja="セキュアブートキー  "; zh="安全启动密鑰       "; default="Secure Boot keys  " }
  "sum_yes"    = @{ es="SI (siempre ejecutado)"; en="YES (always executed)"; fr="OUI (toujours execute)"; de="JA (immer ausgefuehrt)"; ru="ДА (всегда)"; ja="はい（常に実行）"; zh="是（始终执行）"; default="YES (always executed)" }
  "sum_ok"     = @{ es="SI"; en="YES"; fr="OUI"; de="JA"; ru="ДА"; ja="はい"; zh="是"; ko="예"; default="YES" }
  "sum_no_bios"= @{ es="NO - requiere BIOS"; en="NO - requires BIOS"; fr="NON - BIOS requis"; de="NEIN - BIOS noetig"; ru="НЕТ - нужен BIOS"; ja="いいえ - BIOS必要"; zh="否 - 需要 BIOS"; default="NO - requires BIOS" }
  "sum_manual" = @{ es="Requiere UEFI manual"; en="Requires manual UEFI"; fr="UEFI manuel requis"; de="Manuelles UEFI noetig"; ru="Ручной UEFI"; ja="手動UEFI必要"; zh="需要手动 UEFI"; default="Requires manual UEFI" }
  "on_reboot"  = @{ es="AL REINICIAR:"; en="ON REBOOT:"; fr="AU REDEMARRAGE:"; de="BEIM NEUSTART:"; ru="ПРИ ПЕРЕЗАГРУЗКЕ:"; ja="再起動時:"; zh="重启时:"; default="ON REBOOT:" }
  "reboot_conf"= @{ es="El BIOS mostrara confirmacion de borrado de TPM."; en="BIOS will show TPM erase confirmation."; fr="Le BIOS affichera confirmation d effacement TPM."; de="BIOS zeigt TPM-Loeschbestaetigung."; ru="Байос покажет подтверждение удаления TPM."; ja="BIOSがTPM消去の確認を表示。"; zh="BIOS 将显示 TPM 擦除确认。"; default="BIOS will show TPM erase confirmation." }
  "reboot_key" = @{ es="Acepta con F10, F12 o Enter segun tu fabricante."; en="Accept with F10, F12 or Enter depending on manufacturer."; fr="Acceptez avec F10, F12 ou Entree selon le fabricant."; de="Bestaetigen mit F10, F12 oder Enter je nach Hersteller."; ru="Примите с F10, F12 или Enter."; ja="F10、F12またはEnterで確認。"; zh="按 F10、F12 或 Enter 确认。"; default="Accept with F10, F12 or Enter depending on manufacturer." }
  "sb_add_step"= @{ es="PASO ADICIONAL - Secure Boot:"; en="ADDITIONAL STEP - Secure Boot:"; fr="ETAPE SUPPLEMENTAIRE - Secure Boot:"; de="ZUSAETZLICHER SCHRITT - Secure Boot:"; ru="ДОПОЛНИТЕЛЬНЫЙ ШАГ - Secure Boot:"; ja="追加手順 - Secure Boot:"; zh="额外步骤 - 安全启动:"; default="ADDITIONAL STEP - Secure Boot:" }
  "reboot_uefi"= @{ es="Reinicia al UEFI con: shutdown /r /fw /t 0"; en="Reboot to UEFI with: shutdown /r /fw /t 0"; fr="Redemarrez vers UEFI: shutdown /r /fw /t 0"; de="Neustart zu UEFI: shutdown /r /fw /t 0"; ru="Перезагрузка в UEFI: shutdown /r /fw /t 0"; ja="UEFIへ再起動: shutdown /r /fw /t 0"; zh="重启到 UEFI: shutdown /r /fw /t 0"; default="Reboot to UEFI with: shutdown /r /fw /t 0" }
  "ask_reboot" = @{ es="Reiniciar ahora? S = normal | U = directo al UEFI | N = cancelar"; en="Reboot now? S = normal | U = direct to UEFI | N = cancel"; fr="Redemarrer maintenant? S = normal | U = UEFI | N = annuler"; de="Jetzt neu starten? S = normal | U = UEFI | N = abbrechen"; ru="Перезагрузить? S = обычная | U = UEFI | N = отмена"; ja="再起動? S=通常 | U=UEFI | N=キャンセル"; zh="现在重启? S=普通 | U=直接UEFI | N=取消"; default="Reboot now? S = normal | U = direct to UEFI | N = cancel" }
  "rebooting"  = @{ es="Reiniciando en 10 segundos... (Ctrl+C para cancelar)"; en="Rebooting in 10 seconds... (Ctrl+C to cancel)"; fr="Redemarrage dans 10 secondes... (Ctrl+C pour annuler)"; de="Neustart in 10 Sekunden... (Ctrl+C zum Abbrechen)"; ru="Перезагрузка через 10 секунд... (Ctrl+C для отмены)"; default="Rebooting in 10 seconds... (Ctrl+C to cancel)" }
  "rebooting_fw"=@{ es="Reiniciando directo al firmware UEFI..."; en="Rebooting directly to UEFI firmware..."; fr="Redemarrage direct vers UEFI..."; de="Direkter Neustart zur UEFI-Firmware..."; ru="Прямая перезагрузка в UEFI..."; default="Rebooting directly to UEFI firmware..." }
  "cancel_reboot"=@{ es="Reinicio cancelado. Recuerda reiniciar manualmente."; en="Reboot cancelled. Remember to reboot manually."; fr="Redemarrage annule. N oubliez pas de redemarrer manuellement."; de="Neustart abgebrochen. Manuell neu starten."; ru="Перезагрузка отменена. Перезагрузите вручную."; default="Reboot cancelled. Remember to reboot manually." }
  "tpm_fail_bios"=@{ es="TPM no pudo limpiarse. Entra al BIOS manualmente."; en="TPM could not be cleaned. Enter BIOS manually."; fr="TPM non nettoye. Entrez dans le BIOS manuellement."; de="TPM nicht bereinigt. BIOS manuell aufrufen."; ru="TPM не очищен. Войдите в BIOS вручную."; default="TPM could not be cleaned. Enter BIOS manually." }
  "uefi_key_lbl"=@{ es="Tecla UEFI del fabricante"; en="Manufacturer UEFI key"; fr="Touche UEFI du fabricant"; de="Hersteller UEFI-Taste"; ru="Клавиша UEFI производителя"; ja="メーカーUEFIキー"; zh="制造商 UEFI 按键"; default="Manufacturer UEFI key" }
  "sb_path_lbl" =@{ es="Ruta Secure Boot en UEFI"; en="Secure Boot path in UEFI"; fr="Chemin Secure Boot dans UEFI"; de="Secure Boot-Pfad in UEFI"; ru="Путь Secure Boot в UEFI"; ja="UEFIのSecure Bootパス"; zh="UEFI 中安全启动路径"; default="Secure Boot path in UEFI" }
}

function T { param([string]$k); $t=$Strings[$k]; if(!$t){return "[$k]"}; if($t.ContainsKey($Lang)){return $t[$Lang]}; if($t.ContainsKey("default")){return $t["default"]}; return "[$k]" }

# ======================================================
#  TABLA DE FABRICANTES: TECLA UEFI + RUTA SECURE BOOT
# ======================================================

$UEFIDb = @{
  "microsoft"  = @{ key="Vol+ (hold on power / mantener al encender)"; sb="Security -> Change Secure Boot setting -> Clear Secure Boot Keys" }
  "hp"         = @{ key="F10 / Esc"; sb="Security -> Secure Boot Configuration -> Reset to Factory Defaults" }
  "hewlett"    = @{ key="F10 / Esc"; sb="Security -> Secure Boot Configuration -> Reset to Factory Defaults" }
  "dell"       = @{ key="F2 / F12"; sb="Secure Boot -> Delete All Secure Boot Keys / Reset to Default" }
  "alienware"  = @{ key="F2 / F12"; sb="Secure Boot -> Delete All Secure Boot Keys" }
  "lenovo"     = @{ key="F1 / F2 / Fn+F2"; sb="Security -> Secure Boot -> Reset to Setup Mode / Clear All Keys" }
  "thinkpad"   = @{ key="F1 / F2"; sb="Security -> Secure Boot -> Reset to Setup Mode" }
  "asus"       = @{ key="Del / F2"; sb="Boot -> Secure Boot -> Key Management -> Delete All Secure Boot Keys" }
  "acer"       = @{ key="F2 / Del"; sb="Security -> Secure Boot -> Disable / Clear Keys" }
  "msi"        = @{ key="Del"; sb="Settings -> Security -> Secure Boot -> Erase all Secure Boot Keys" }
  "gigabyte"   = @{ key="Del / F2"; sb="Boot -> Secure Boot -> Setup Mode / Clear Keys" }
  "asrock"     = @{ key="Del / F2"; sb="Security -> Secure Boot -> Clear Secure Boot Keys" }
  "samsung"    = @{ key="F2"; sb="Security -> Secure Boot -> Restore Factory Keys" }
  "toshiba"    = @{ key="F2 / F12"; sb="Security -> Secure Boot -> Clear Secure Boot Keys" }
  "dynabook"   = @{ key="F2"; sb="Security -> Secure Boot -> Clear Keys" }
  "fujitsu"    = @{ key="F2"; sb="Security -> Secure Boot -> Reset Secure Boot Keys" }
  "panasonic"  = @{ key="F2 / Del"; sb="Security -> Secure Boot -> Clear Keys" }
  "sony"       = @{ key="F2 / Assist"; sb="Security -> Secure Boot -> Clear / Restore Keys" }
  "vaio"       = @{ key="F2 / Assist"; sb="Security -> Secure Boot -> Clear / Restore Keys" }
  "huawei"     = @{ key="F2"; sb="Security -> Secure Boot -> Reset to Factory Settings" }
  "honor"      = @{ key="F2"; sb="Security -> Secure Boot -> Clear Keys" }
  "xiaomi"     = @{ key="F2"; sb="Security -> Secure Boot -> Disable" }
  "razer"      = @{ key="Del / F1"; sb="Security -> Secure Boot -> Clear All Secure Boot Keys" }
  "biostar"    = @{ key="Del / F2"; sb="Security -> Secure Boot -> Clear Keys" }
  "evga"       = @{ key="Del"; sb="Security -> Secure Boot -> Erase Keys" }
  "supermicro" = @{ key="Del / F2"; sb="Security -> Secure Boot -> Delete All Keys" }
  "intel"      = @{ key="F2"; sb="Boot -> Secure Boot -> Reset to Factory Defaults" }
  "nec"        = @{ key="F2"; sb="Security -> Secure Boot -> Clear Keys" }
  "medion"     = @{ key="F2 / Del"; sb="Security -> Secure Boot -> Clear Keys" }
  "clevo"      = @{ key="Del / F2"; sb="Security -> Secure Boot -> Clear Keys" }
  "tuxedo"     = @{ key="Del / F2"; sb="Security -> Secure Boot -> Clear Keys" }
  "system76"   = @{ key="F2"; sb="Security -> Secure Boot -> Clear Keys" }
  "getac"      = @{ key="F2"; sb="Security -> Secure Boot -> Clear Keys" }
  "apple"      = @{ key="Cmd+R (boot) -> Startup Security Utility"; sb="Startup Security Utility -> No Security" }
  "default"    = @{ key="Del / F2 / F10 / F12 (varies by model)"; sb="Security -> Secure Boot -> Clear / Reset / Delete All Keys" }
}
function Get-UEFIInfo { param([string]$m); $ml=$m.ToLower(); foreach ($k in $UEFIDb.Keys) { if ($k -ne "default" -and $ml -match $k) { return $UEFIDb[$k] } }; return $UEFIDb["default"] }

# ======================================================
#  DETECCION DE EQUIPO Y FIRMWARE
# ======================================================

$manufacturer = (Get-WmiObject -Class Win32_ComputerSystem).Manufacturer
$model        = (Get-WmiObject -Class Win32_ComputerSystem).Model
$isSurface    = $model -match "Surface"
$uefiInfo     = Get-UEFIInfo $manufacturer

function Get-FirmwareType { try { return (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control" -Name PEFirmwareType -EA Stop).PEFirmwareType } catch { if (Test-Path "$env:SystemRoot\System32\SecConfig.efi") { return 2 }; return 1 } }
$isUEFI = (Get-FirmwareType) -eq 2

# ======================================================
#  CABECERA
# ======================================================

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  $(T 'header_title')" -ForegroundColor Cyan
Write-Host "  Lang: $Lang  |  Culture: $(Get-SystemLanguage)" -ForegroundColor DarkGray
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Firmware : $(if ($isUEFI) { T 'firmware_uefi' } else { T 'firmware_leg' })" -ForegroundColor $(if($isUEFI){'Green'}else{'Yellow'})
Write-Host "Equipo   : $manufacturer $model" -ForegroundColor Gray
Write-Host "  $(T 'uefi_key_lbl') : $($uefiInfo.key)" -ForegroundColor DarkCyan
Write-Host "  $(T 'sb_path_lbl')  : $($uefiInfo.sb)" -ForegroundColor DarkCyan
if ($isSurface) { Write-Host "  [Surface detected]" -ForegroundColor Yellow }

# ======================================================
#  INFO TPM
# ======================================================

Write-Host ""; Write-Host "$(T 'tpm_status')" -ForegroundColor Yellow
try {
    $tpm = Get-Tpm
    $wt  = Get-WmiObject -Namespace root\cimv2\Security\MicrosoftTpm -Class Win32_Tpm -EA SilentlyContinue
    Write-Host "  TpmPresent  : $($tpm.TpmPresent)"
    Write-Host "  TpmReady    : $($tpm.TpmReady)"
    Write-Host "  TpmEnabled  : $($tpm.TpmEnabled)"
    Write-Host "  TpmOwned    : $($tpm.TpmOwned)"
    Write-Host "  SpecVersion : $($wt.SpecVersion)"
} catch { Write-Host "  $_" -ForegroundColor Yellow }

# ======================================================
#  INFO SECURE BOOT
# ======================================================

Write-Host ""; Write-Host "$(T 'sb_status')" -ForegroundColor Yellow
$sbOK = $false
if ($isUEFI) {
    try {
        $sbOn = Confirm-SecureBootUEFI -EA Stop; $sbOK = $true
        Write-Host "  Enabled : $sbOn"
        foreach ($v in @("PK","KEK","db","dbx")) {
            try { $d = Get-SecureBootUEFI -Name $v -EA Stop; Write-Host "  $v : $(T 'present_kb') ($([math]::Round($d.Bytes.Length/1KB,1)) KB)" -ForegroundColor Green }
            catch { Write-Host "  $v : $(T 'empty_key')" -ForegroundColor Gray }
        }
    } catch { Write-Host "  $_" -ForegroundColor Yellow }
} else { Write-Host "  $(T 'firmware_leg')" -ForegroundColor Yellow }

# ======================================================
#  CONFIRMACION
# ======================================================

Write-Host ""; Write-Host "$(T 'warn_title')" -ForegroundColor Red
Write-Host "  $(T 'warn1')" -ForegroundColor Red
Write-Host "  $(T 'warn2')" -ForegroundColor Red
Write-Host "  $(T 'warn3')" -ForegroundColor Red
Write-Host "  $(T 'warn4')" -ForegroundColor Red
Write-Host "  $(T 'warn5')" -ForegroundColor Red
Write-Host ""
$cw  = T "confirm_word"
$inp = Read-Host "$(T 'confirm_prompt') [$cw]"
if ($inp -ne $cw) { Write-Host "$(T 'cancelled')" -ForegroundColor Yellow; exit 0 }

# ======================================================
#  BLOQUE 1 - LIMPIEZA TPM
# ======================================================

function Try-ClearTpmNative {
    Write-Host ""; Write-Host "  $(T 'm1')" -ForegroundColor White
    try { Clear-Tpm -EA Stop; Write-Host "    $(T 'ok')" -ForegroundColor Green; return $true }
    catch { Write-Host "    $(T 'err'): $($_.Exception.Message)" -ForegroundColor Red; return $false }
}
function Try-ClearTpmWMI {
    Write-Host ""; Write-Host "  $(T 'm2')" -ForegroundColor White
    try {
        $wmi = Get-WmiObject -Namespace root\cimv2\Security\MicrosoftTpm -Class Win32_Tpm -EA Stop
        Write-Host "    SpecVersion: $($wmi.SpecVersion)" -ForegroundColor Gray
        foreach ($op in @(@{c=14;d="Clear TPM (PPI 1.2+)"},@{c=22;d="Clear+hierarchies (TPM 2.0)"},@{c=5;d="Enable+Activate+Clear"})) {
            Write-Host "    Op $($op.c): $($op.d)" -ForegroundColor Yellow
            $r = $wmi.SetPhysicalPresenceRequest($op.c)
            if ($r.ReturnValue -eq 0) { Write-Host "    $(T 'ok') (ReturnValue=0)" -ForegroundColor Green; return $true }
            Write-Host "    ReturnValue=$($r.ReturnValue), $(T 'next')" -ForegroundColor Red
        }
        return $false
    } catch { Write-Host "    $(T 'err'): $($_.Exception.Message)" -ForegroundColor Red; return $false }
}
function Try-ClearTpmWmic {
    Write-Host ""; Write-Host "  $(T 'm3')" -ForegroundColor White
    try {
        $out = cmd /c 'wmic /namespace:\\root\cimv2\Security\MicrosoftTpm path Win32_Tpm call SetPhysicalPresenceRequest 14' 2>&1
        Write-Host "    $out" -ForegroundColor Gray
        if ($out -match "ReturnValue = 0") { Write-Host "    $(T 'ok')" -ForegroundColor Green; return $true }
        Write-Host "    ReturnValue != 0" -ForegroundColor Red; return $false
    } catch { Write-Host "    $(T 'err'): $($_.Exception.Message)" -ForegroundColor Red; return $false }
}
function Clear-TpmOwnerAuth {
    Write-Host ""; Write-Host "  $(T 'extra_a')" -ForegroundColor White
    try {
        reg add "HKLM\SOFTWARE\Policies\Microsoft\TPM" /v OSManagedAuthLevel /t REG_DWORD /d 0 /f | Out-Null
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\TPM" -Name "OSManagedAuthLevel" -EA SilentlyContinue
        Write-Host "    $(T 'extra_a_ok')" -ForegroundColor Green
    } catch { Write-Host "    $($_.Exception.Message)" -ForegroundColor Yellow }
}
function Clear-UEFIPlatformAuth {
    Write-Host ""; Write-Host "  $(T 'extra_b')" -ForegroundColor White
    try {
        $wmi = Get-WmiObject -Namespace root\cimv2\Security\MicrosoftTpm -Class Win32_Tpm -EA Stop
        $r1  = $wmi.SetPhysicalPresenceRequest(21); Write-Host "    Op 21 ReturnValue: $($r1.ReturnValue)" -ForegroundColor Gray
        $r2  = $wmi.SetPhysicalPresenceRequest(18); Write-Host "    Op 18 ReturnValue: $($r2.ReturnValue)" -ForegroundColor Gray
        Write-Host "    $(T 'sent_fw')" -ForegroundColor Green
    } catch { Write-Host "    $($_.Exception.Message)" -ForegroundColor Yellow }
}

# ======================================================
#  BLOQUE 2 - LIMPIEZA SECURE BOOT
# ======================================================

function Backup-SecureBootKeys {
    Write-Host ""; Write-Host "  $(T 'sb_backup')" -ForegroundColor White
    $p = "$env:TEMP\SecureBoot_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $p -Force | Out-Null
    foreach ($v in @("PK","KEK","db","dbx")) {
        try { $d = Get-SecureBootUEFI -Name $v -EA Stop; [IO.File]::WriteAllBytes("$p\$v.bin",$d.Bytes); Write-Host "    $v -> $p\$v.bin ($([math]::Round($d.Bytes.Length/1KB,1)) KB)" -ForegroundColor Gray }
        catch { Write-Host "    $v : $(T 'empty_key')" -ForegroundColor Gray }
    }
    Write-Host "    $(T 'sb_backup_in'): $p" -ForegroundColor Green
}
function Get-SecureBootMode {
    try {
        $sb = Confirm-SecureBootUEFI -EA Stop
        try { $sm = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State" -EA Stop).UEFISecureBootEnabled; if ($sm -eq 0) { return "SetupMode" }; return "UserMode" }
        catch { if ($sb) { return "UserMode" } else { return "SetupMode" } }
    } catch { return "Unknown" }
}
function Try-ClearSB-SignedFile {
    Write-Host ""; Write-Host "  $(T 'sbm1')" -ForegroundColor White
    Write-Host "    $(T 'sbm1_need')" -ForegroundColor Gray
    Write-Host "    $(T 'sbm1_oem')" -ForegroundColor Gray
    $sf = Read-Host "    $(T 'sbm1_path')"
    if ([string]::IsNullOrWhiteSpace($sf)) { Write-Host "    $(T 'sbm1_skip')" -ForegroundColor Yellow; return $false }
    if (-not (Test-Path $sf)) { Write-Host "    $(T 'sbm1_nf'): $sf" -ForegroundColor Red; return $false }
    try { Set-SecureBootUEFI -Name "PK" -Time (Get-Date) -SignedFilePath $sf -EA Stop; Write-Host "    $(T 'ok') -> Setup Mode" -ForegroundColor Green; return $true }
    catch { Write-Host "    $(T 'err'): $($_.Exception.Message)" -ForegroundColor Red; return $false }
}
function Try-ClearSB-VerifySetupMode {
    Write-Host ""; Write-Host "  $(T 'sbm2')" -ForegroundColor White
    try {
        $mode = Get-SecureBootMode; Write-Host "    $(T 'sb_mode'): $mode" -ForegroundColor Gray
        if ($mode -eq "SetupMode") { Write-Host "    $(T 'sb_setup_ok')" -ForegroundColor Green; return $true }
        try { $pk = Get-SecureBootUEFI -Name "PK" -EA Stop; Write-Host "    $(T 'sbm2_active') ($([math]::Round($pk.Bytes.Length/1KB,1)) KB)" -ForegroundColor Yellow }
        catch { Write-Host "    $(T 'ok') -> Setup Mode" -ForegroundColor Green; return $true }
        return $false
    } catch { Write-Host "    $(T 'err'): $($_.Exception.Message)" -ForegroundColor Red; return $false }
}
function Try-ClearSB-BcdEdit {
    Write-Host ""; Write-Host "  $(T 'sbm3')" -ForegroundColor White
    Write-Host "    $(T 'sbm3_note')" -ForegroundColor Gray
    try {
        $o1 = bcdedit /set "{current}" testsigning on 2>&1
        $o2 = bcdedit /set "{current}" nointegritychecks on 2>&1
        Write-Host "    testsigning      : $o1" -ForegroundColor Gray
        Write-Host "    nointegritychecks: $o2" -ForegroundColor Gray
        if (($o1 -match "correctamente|successfully|The operation completed") -or ($o2 -match "correctamente|successfully|The operation completed")) { Write-Host "    $(T 'ok')" -ForegroundColor Green; return $true }
        return $false
    } catch { Write-Host "    $(T 'err'): $($_.Exception.Message)" -ForegroundColor Red; return $false }
}
function Show-SBManualInstructions {
    Write-Host ""
    Write-Host "  $(T 'uefi_key_lbl') : $($uefiInfo.key)" -ForegroundColor Cyan
    Write-Host "  $(T 'sb_path_lbl')  : $($uefiInfo.sb)" -ForegroundColor Cyan
    Write-Host ""
    if ($isSurface) {
        Write-Host "  Surface UEFI Access:" -ForegroundColor Yellow
        Write-Host "    1. Power off completely / Apaga completamente" -ForegroundColor White
        Write-Host "    2. Hold Vol+ / Mantener Vol+" -ForegroundColor White
        Write-Host "    3. Press power, release on logo / Pulsa encendido, suelta al logo" -ForegroundColor White
        Write-Host "    4. $($uefiInfo.sb)" -ForegroundColor White
        Write-Host "    5. Exit -> Restart Now" -ForegroundColor White
    } else {
        Write-Host "  $(T 'uefi_key_lbl') : $($uefiInfo.key)" -ForegroundColor White
        Write-Host "  $(T 'sb_path_lbl')  : $($uefiInfo.sb)" -ForegroundColor White
    }
    Write-Host ""; Write-Host "  $(T 'reboot_uefi')" -ForegroundColor Cyan
}
function Clear-SecureBootKeys {
    Write-Host ""; Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "  $(T 'blk2_title')" -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
    if (-not $isUEFI) { Write-Host "  $(T 'firmware_leg')" -ForegroundColor Yellow; return $true }
    if (-not $sbOK)   { Write-Host "  $(T 'sb_manual_req')" -ForegroundColor Yellow; Show-SBManualInstructions; return $false }
    Backup-SecureBootKeys
    $mode = Get-SecureBootMode
    Write-Host ""; Write-Host "  $(T 'sb_mode'): $mode" -ForegroundColor $(if($mode -eq "SetupMode"){'Green'}else{'Yellow'})
    if ($mode -eq "SetupMode") { Write-Host "  $(T 'sb_setup_ok')" -ForegroundColor Green; return $true }
    Write-Host "  $(T 'sb_user_mode')" -ForegroundColor Yellow
    Write-Host "  $(T 'sb_pk_owner'): $manufacturer" -ForegroundColor Yellow
    Write-Host "  $(T 'sb_pk_nokey')" -ForegroundColor Yellow
    Write-Host "  $(T 'sb_trying')" -ForegroundColor White
    $r = Try-ClearSB-SignedFile
    if (!$r) { $r = Try-ClearSB-VerifySetupMode }
    if (!$r) { $r = Try-ClearSB-BcdEdit }
    if (!$r) { Write-Host ""; Write-Host "  $(T 'sb_all_fail')" -ForegroundColor Red; Write-Host "  $(T 'sb_manual_req')" -ForegroundColor Yellow; Show-SBManualInstructions }
    return $r
}

# ======================================================
#  EJECUCION PRINCIPAL
# ======================================================

Write-Host ""; Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  $(T 'blk1_title')" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$tpmOK = $false
$tpmOK = Try-ClearTpmNative
if (!$tpmOK) { $tpmOK = Try-ClearTpmWMI  }
if (!$tpmOK) { $tpmOK = Try-ClearTpmWmic }
Clear-TpmOwnerAuth
Clear-UEFIPlatformAuth

Write-Host ""; Write-Host "  $(if($tpmOK){ T 'res_ok' }else{ T 'res_fail' })" -ForegroundColor $(if($tpmOK){'Green'}else{'Red'})

$sbOK2 = Clear-SecureBootKeys

# ======================================================
#  RESUMEN FINAL
# ======================================================

Write-Host ""; Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  $(T 'sum_title')" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  $(T 'sum_dev')   : $manufacturer $model"
Write-Host "  $(T 'sum_tpm')   : $(if($tpmOK){ T 'sum_ok' }else{ T 'sum_no_bios' })"
Write-Host "  $(T 'sum_owner') : $(T 'sum_yes')"
Write-Host "  $(T 'sum_plat')  : $(T 'sum_yes') (op 21+18)"
Write-Host "  $(T 'sum_sb')    : $(if($sbOK2){ T 'sum_ok' }else{ T 'sum_manual' })"
Write-Host ""

if ($tpmOK) {
    Write-Host "  $(T 'on_reboot')" -ForegroundColor Yellow
    Write-Host "    $(T 'reboot_conf')" -ForegroundColor White
    Write-Host "    $(T 'reboot_key')" -ForegroundColor White
    Write-Host ""
    if (-not $sbOK2 -and $isUEFI) {
        Write-Host "  $(T 'sb_add_step')" -ForegroundColor Red
        Write-Host "    $(T 'reboot_uefi')" -ForegroundColor Cyan
        Write-Host "    $($uefiInfo.sb)" -ForegroundColor White
        Write-Host ""
    }
    $rb = Read-Host "$(T 'ask_reboot')"
    if     ($rb -eq "S") { Write-Host "$(T 'rebooting')"   -ForegroundColor Cyan; Start-Sleep 10; Restart-Computer -Force }
    elseif ($rb -eq "U") { Write-Host "$(T 'rebooting_fw')" -ForegroundColor Cyan; Start-Sleep 3;  shutdown /r /fw /t 0 }
    else                 { Write-Host "$(T 'cancel_reboot')" -ForegroundColor Yellow }
} else {
    Write-Host "  $(T 'tpm_fail_bios')" -ForegroundColor Red
    Write-Host "  $(T 'uefi_key_lbl'): $($uefiInfo.key)" -ForegroundColor Cyan
    Write-Host "  $(T 'sb_path_lbl') : $($uefiInfo.sb)" -ForegroundColor Cyan
    exit 1
}
