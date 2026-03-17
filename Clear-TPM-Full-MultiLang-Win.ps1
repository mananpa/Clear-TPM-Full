# ============================================================
#   Clear-TPM-Full.ps1
#   Borrado completo: TPM + claves UEFI + Secure Boot Keys
#   Requiere: Administrador + Sistema UEFI (no Legacy BIOS)
#   v4.0: Deteccion de idioma automatica + teclas UEFI por marca
# ============================================================

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Run as Administrator / Ejecutar como Administrador."
    exit 1
}

# ╔══════════════════════════════════════════════════════════╗
# ║              DETECCION DE IDIOMA DEL SISTEMA            ║
# ╚══════════════════════════════════════════════════════════╝

function Get-SystemLanguage { try { return (Get-Culture).Name } catch { return "en-US" } }
function Get-LangBase { param([string]$c); if ($c -match "^([a-z]{2,3})-") { return $Matches[1] }; return $c.ToLower() }
$Lang = Get-LangBase (Get-SystemLanguage)

# ── Tabla de traducciones ─────────────────────────────────────────────────────
$Strings = @{
  "header_title"  = @{ es="Full TPM + Secure Boot Clear - Claves + UEFI"; en="Full TPM + Secure Boot Clear - Keys + UEFI"; fr="Effacement complet TPM + Secure Boot"; de="Vollständige TPM + Secure Boot Löschung"; it="Cancellazione completa TPM + Secure Boot"; pt="Limpeza completa TPM + Secure Boot"; nl="Volledige TPM + Secure Boot wissen"; pl="Pełne czyszczenie TPM + Secure Boot"; ru="Полная очистка TPM + Secure Boot"; ja="TPM + セキュアブート完全消去"; zh="完整清除 TPM + 安全启动"; ko="전체 TPM + 보안 부팅 지우기"; ar="مسح كامل TPM + Secure Boot"; tr="Tam TPM + Güvenli Önyükleme Temizleme"; sv="Fullständig rensning TPM + Secure Boot"; da="Fuld rensning TPM + Secure Boot"; fi="Täydellinen TPM + Secure Boot tyhjennys"; nb="Full tømming av TPM + Secure Boot"; cs="Úplné vymazání TPM + Secure Boot"; sk="Úplné vymazanie TPM + Secure Boot"; hu="Teljes TPM + Secure Boot törlés"; ro="Ștergere completă TPM + Secure Boot"; hr="Potpuno brisanje TPM + Secure Boot"; bg="Пълно изчистване TPM + Secure Boot"; uk="Повне очищення TPM + Secure Boot"; el="Πλήρης εκκαθάριση TPM + Secure Boot"; he="מחיקה מלאה של TPM + Secure Boot"; th="ล้าง TPM + Secure Boot ทั้งหมด"; vi="Xóa hoàn toàn TPM + Secure Boot"; id="Hapus Lengkap TPM + Secure Boot"; ms="Padam Penuh TPM + Secure Boot"; hi="पूर्ण TPM + सुरक्षित बूट क्लीयर"; fa="پاکسازی کامل TPM + Secure Boot"; ar="مسح كامل لـ TPM + Secure Boot"; sw="Futa Kamili TPM + Secure Boot"; af="Volledige TPM + Secure Boot Skoonmaak"; ca="Neteja completa TPM + Secure Boot"; eu="TPM + Secure Boot ezabatze osoa"; gl="Limpeza completa TPM + Secure Boot"; sr="Потпуно брисање TPM + Secure Boot"; default="Full TPM + Secure Boot Clear - Keys + UEFI" }
  "firmware_uefi" = @{ default="UEFI" }
  "firmware_leg"  = @{ es="Legacy BIOS (Secure Boot no aplica)"; en="Legacy BIOS (Secure Boot not applicable)"; fr="Legacy BIOS (Secure Boot non applicable)"; de="Legacy BIOS (Secure Boot nicht anwendbar)"; it="Legacy BIOS (Secure Boot non applicabile)"; pt="Legacy BIOS (Secure Boot não aplicável)"; ru="Legacy BIOS (Secure Boot не применимо)"; ja="レガシーBIOS（セキュアブート非対応）"; zh="传统BIOS（安全启动不适用）"; default="Legacy BIOS (Secure Boot not applicable)" }
  "tpm_status"    = @{ es="Estado del TPM:"; en="TPM Status:"; fr="État du TPM:"; de="TPM-Status:"; it="Stato del TPM:"; pt="Estado do TPM:"; ru="Состояние TPM:"; ja="TPMの状態:"; zh="TPM 状态:"; ko="TPM 상태:"; tr="TPM Durumu:"; default="TPM Status:" }
  "sb_status"     = @{ es="Estado de Secure Boot:"; en="Secure Boot Status:"; fr="État du Secure Boot:"; de="Secure Boot-Status:"; ru="Состояние Secure Boot:"; ja="セキュアブートの状態:"; zh="安全启动状态:"; default="Secure Boot Status:" }
  "present_kb"    = @{ es="presente"; en="present"; fr="présent"; de="vorhanden"; it="presente"; pt="presente"; ru="присутствует"; ja="存在"; zh="存在"; ko="있음"; default="present" }
  "empty_key"     = @{ es="vacio o inaccesible"; en="empty or inaccessible"; fr="vide ou inaccessible"; de="leer oder nicht zugänglich"; ru="пусто или недоступно"; ja="空または未アクセス"; zh="空或不可访问"; default="empty or inaccessible" }
  "warn_title"    = @{ es="ADVERTENCIA - SE BORRARA TODO:"; en="WARNING - THE FOLLOWING WILL BE ERASED:"; fr="AVERTISSEMENT - TOUT CE QUI SUIT SERA EFFACÉ:"; de="WARNUNG - FOLGENDES WIRD GELÖSCHT:"; it="ATTENZIONE - VERRÀ CANCELLATO TUTTO:"; pt="AVISO - O SEGUINTE SERÁ APAGADO:"; ru="ПРЕДУПРЕЖДЕНИЕ - БУДЕТ УДАЛЕНО:"; ja="警告 - 以下が消去されます:"; zh="警告 - 以下内容将被删除:"; ko="경고 - 다음이 지워집니다:"; tr="UYARI - SİLİNECEK:"; default="WARNING - THE FOLLOWING WILL BE ERASED:" }
  "warn1"         = @{ es="[TPM]  Todas las claves (Owner, SRK, EK, contrasenas)"; en="[TPM]  All keys (Owner, SRK, EK, passwords)"; fr="[TPM]  Toutes les clés (Owner, SRK, EK, mots de passe)"; de="[TPM]  Alle Schlüssel (Owner, SRK, EK, Passwörter)"; ru="[TPM]  Все ключи (Owner, SRK, EK, пароли)"; ja="[TPM]  すべてのキー"; zh="[TPM]  所有密钥"; default="[TPM]  All keys (Owner, SRK, EK, passwords)" }
  "warn2"         = @{ es="[TPM]  OwnerAuth retenido en registro de Windows"; en="[TPM]  OwnerAuth retained in Windows registry"; fr="[TPM]  OwnerAuth conservé dans le registre Windows"; de="[TPM]  OwnerAuth in der Windows-Registrierung"; ru="[TPM]  OwnerAuth в реестре Windows"; ja="[TPM]  WindowsレジストリのOwnerAuth"; zh="[TPM]  注册表中的 OwnerAuth"; default="[TPM]  OwnerAuth retained in Windows registry" }
  "warn3"         = @{ es="[UEFI] Physical Presence enviado al firmware"; en="[UEFI] Physical Presence sent to firmware"; fr="[UEFI] Physical Presence envoyé au firmware"; de="[UEFI] Physical Presence an Firmware gesendet"; ru="[UEFI] Physical Presence в прошивке"; ja="[UEFI] ファームウェアへPhysical Presence送信"; zh="[UEFI] Physical Presence 已发送到固件"; default="[UEFI] Physical Presence sent to firmware" }
  "warn4"         = @{ es="[SB]   Secure Boot: PK, KEK, db, dbx (Setup Mode)"; en="[SB]   Secure Boot: PK, KEK, db, dbx (Setup Mode)"; fr="[SB]   Secure Boot: PK, KEK, db, dbx (Mode Setup)"; de="[SB]   Secure Boot: PK, KEK, db, dbx (Setup-Modus)"; ru="[SB]   Secure Boot: PK, KEK, db, dbx"; ja="[SB]   Secure Boot: PK, KEK, db, dbx"; zh="[SB]   安全启动: PK, KEK, db, dbx"; default="[SB]   Secure Boot: PK, KEK, db, dbx (Setup Mode)" }
  "warn5"         = @{ es="El BIOS pedira confirmacion fisica al reiniciar."; en="BIOS will request physical confirmation on reboot."; fr="Le BIOS demandera confirmation physique au redémarrage."; de="BIOS fordert beim Neustart physische Bestätigung."; ru="BIOS запросит физическое подтверждение."; ja="再起動時BIOSが確認を要求します。"; zh="重启时 BIOS 将要求物理确认。"; default="BIOS will request physical confirmation on reboot." }
  "confirm_prompt"= @{ es="Escribe BORRAR para confirmar"; en="Type ERASE to confirm"; fr="Tapez EFFACER pour confirmer"; de="Geben Sie LOESCHEN ein"; it="Digita CANCELLA per confermare"; pt="Digite APAGAR para confirmar"; nl="Typ WISSEN om te bevestigen"; pl="Wpisz WYCZYSC aby potwierdzić"; ru="Введите УДАЛИТЬ для подтверждения"; ja="確認するには KESU と入力"; zh="输入 SHANCHU 确认"; ko="확인하려면 JUDA를 입력"; tr="Onaylamak için SIL yazın"; sv="Skriv RADERA för att bekräfta"; da="Skriv SLET for at bekræfte"; fi="Kirjoita TYHJENNA vahvistaaksesi"; nb="Skriv SLETT for å bekrefte"; cs="Napište VYMAZAT pro potvrzení"; hu="Írja be TORLES a megerősítéshez"; ro="Tastați STERGERE pentru confirmare"; el="Πληκτρολογήστε ΔΙΑΓΡΑΦΗ"; he="הקלד מחק לאישור"; th="พิมพ์ ลบ เพื่อยืนยัน"; vi="Nhập XOA để xác nhận"; id="Ketik HAPUS untuk konfirmasi"; ms="Taip PADAM untuk mengesahkan"; hi="MITA टाइप करें"; fa="HAZF را تایپ کنید"; ar="اكتب احذف للتأكيد"; sw="Andika FUTA kuthibitisha"; default="Type ERASE to confirm" }
  "confirm_word"  = @{ es="BORRAR"; en="ERASE"; fr="EFFACER"; de="LOESCHEN"; it="CANCELLA"; pt="APAGAR"; nl="WISSEN"; pl="WYCZYSC"; ru="УДАЛИТЬ"; ja="KESU"; zh="SHANCHU"; ko="JUDA"; tr="SIL"; sv="RADERA"; da="SLET"; fi="TYHJENNA"; nb="SLETT"; cs="VYMAZAT"; hu="TORLES"; ro="STERGERE"; el="ΔΙΑΓΡΑΦΗ"; he="מחק"; th="ลบ"; vi="XOA"; id="HAPUS"; ms="PADAM"; hi="MITA"; fa="HAZF"; ar="احذف"; sw="FUTA"; default="ERASE" }
  "cancelled"     = @{ es="Cancelado."; en="Cancelled."; fr="Annulé."; de="Abgebrochen."; it="Annullato."; pt="Cancelado."; ru="Отменено."; ja="キャンセルしました。"; zh="已取消。"; ko="취소됨."; tr="İptal edildi."; default="Cancelled." }
  "blk1_title"    = @{ es="BLOQUE 1: Limpieza de TPM"; en="BLOCK 1: TPM Cleanup"; fr="BLOC 1: Nettoyage TPM"; de="BLOCK 1: TPM-Bereinigung"; it="BLOCCO 1: Pulizia TPM"; pt="BLOCO 1: Limpeza TPM"; ru="БЛОК 1: Очистка TPM"; ja="ブロック1: TPMクリーンアップ"; zh="块1: TPM 清理"; default="BLOCK 1: TPM Cleanup" }
  "blk2_title"    = @{ es="BLOQUE 2: Limpieza de Secure Boot Keys"; en="BLOCK 2: Secure Boot Keys Cleanup"; fr="BLOC 2: Nettoyage clés Secure Boot"; de="BLOCK 2: Secure Boot-Schlüssel Bereinigung"; ru="БЛОК 2: Очистка ключей Secure Boot"; ja="ブロック2: セキュアブートキーのクリーンアップ"; zh="块2: 安全启动密钥清理"; default="BLOCK 2: Secure Boot Keys Cleanup" }
  "sum_title"     = @{ es="RESUMEN FINAL"; en="FINAL SUMMARY"; fr="RÉSUMÉ FINAL"; de="ABSCHLUSSZUSAMMENFASSUNG"; it="RIEPILOGO FINALE"; pt="RESUMO FINAL"; ru="ИТОГОВЫЙ ОТЧЕТ"; ja="最終サマリー"; zh="最终摘要"; ko="최종 요약"; tr="SON ÖZET"; default="FINAL SUMMARY" }
  "m1"            = @{ es="Metodo 1: Clear-Tpm (PowerShell nativo)"; en="Method 1: Clear-Tpm (native PowerShell)"; fr="Méthode 1: Clear-Tpm (PowerShell natif)"; de="Methode 1: Clear-Tpm (natives PowerShell)"; ru="Метод 1: Clear-Tpm"; ja="方法1: Clear-Tpm"; zh="方法1: Clear-Tpm"; default="Method 1: Clear-Tpm (native PowerShell)" }
  "m2"            = @{ es="Metodo 2: WMI Win32_Tpm"; en="Method 2: WMI Win32_Tpm"; fr="Méthode 2: WMI Win32_Tpm"; de="Methode 2: WMI Win32_Tpm"; ru="Метод 2: WMI Win32_Tpm"; ja="方法2: WMI Win32_Tpm"; zh="方法2: WMI Win32_Tpm"; default="Method 2: WMI Win32_Tpm" }
  "m3"            = @{ es="Metodo 3: WMIC legacy (cmd)"; en="Method 3: WMIC legacy (cmd)"; fr="Méthode 3: WMIC hérité (cmd)"; de="Methode 3: WMIC Legacy"; ru="Метод 3: WMIC legacy"; ja="方法3: WMICレガシー"; zh="方法3: WMIC 旧版"; default="Method 3: WMIC legacy (cmd)" }
  "ok"            = @{ default="OK" }
  "err"           = @{ es="Error"; en="Error"; fr="Erreur"; de="Fehler"; it="Errore"; pt="Erro"; ru="Ошибка"; ja="エラー"; zh="错误"; default="Error" }
  "next"          = @{ es="probando siguiente..."; en="trying next..."; fr="essai suivant..."; de="nächste versuchen..."; ru="пробую следующий..."; ja="次を試行中..."; zh="尝试下一个..."; default="trying next..." }
  "extra_a"       = @{ es="Extra A: Borrar OwnerAuth del registro"; en="Extra A: Clear OwnerAuth from registry"; fr="Extra A: Effacer OwnerAuth du registre"; de="Extra A: OwnerAuth aus Registrierung löschen"; ru="Доп. A: Удалить OwnerAuth из реестра"; ja="Extra A: レジストリからOwnerAuth削除"; zh="附加A: 清除注册表 OwnerAuth"; default="Extra A: Clear OwnerAuth from registry" }
  "extra_a_ok"    = @{ es="OwnerAuth reseteado (sin retencion)"; en="OwnerAuth reset (no retention)"; fr="OwnerAuth réinitialisé (sans rétention)"; de="OwnerAuth zurückgesetzt"; ru="OwnerAuth сброшен"; ja="OwnerAuthリセット済み"; zh="OwnerAuth 已重置"; default="OwnerAuth reset (no retention)" }
  "extra_b"       = @{ es="Extra B: Reset Platform Auth UEFI (op 21 + op 18)"; en="Extra B: Reset UEFI Platform Auth (op 21 + op 18)"; fr="Extra B: Réinitialisation Platform Auth UEFI"; de="Extra B: UEFI Platform Auth zurücksetzen"; ru="Доп. B: Сброс UEFI Platform Auth"; ja="Extra B: UEFIプラットフォーム認証リセット"; zh="附加B: 重置 UEFI 平台认证"; default="Extra B: Reset UEFI Platform Auth (op 21 + op 18)" }
  "sent_fw"       = @{ es="Enviado al firmware"; en="Sent to firmware"; fr="Envoyé au firmware"; de="An Firmware gesendet"; ru="Отправлено в прошивку"; ja="ファームウェアに送信済み"; zh="已发送到固件"; default="Sent to firmware" }
  "res_ok"        = @{ es="Resultado TPM: Limpiado correctamente"; en="TPM Result: Cleaned successfully"; fr="Résultat TPM: Nettoyé avec succès"; de="TPM-Ergebnis: Erfolgreich bereinigt"; ru="Результат TPM: Успешно очищен"; ja="TPM結果: 正常にクリーンアップ"; zh="TPM 结果：清理成功"; default="TPM Result: Cleaned successfully" }
  "res_fail"      = @{ es="Resultado TPM: Fallo - requiere BIOS manual"; en="TPM Result: Failed - requires manual BIOS"; fr="Résultat TPM: Échec - BIOS manuel requis"; de="TPM-Ergebnis: Fehlgeschlagen - manuelles BIOS"; ru="Результат TPM: Ошибка - ручной BIOS"; ja="TPM結果: 失敗 - 手動BIOS必要"; zh="TPM 结果：失败 - 需要手动 BIOS"; default="TPM Result: Failed - requires manual BIOS" }
  "sb_backup"     = @{ es="SB Backup: Guardando keys actuales"; en="SB Backup: Saving current keys"; fr="SB Sauvegarde: Enregistrement des clés"; de="SB-Sicherung: Schlüssel speichern"; ru="SB резервная копия: Сохранение ключей"; ja="SBバックアップ: 現在のキーを保存"; zh="SB 备份：保存当前密钥"; default="SB Backup: Saving current keys" }
  "sb_backup_in"  = @{ es="Backup en"; en="Backup in"; fr="Sauvegarde dans"; de="Sicherung in"; ru="Резервная копия в"; ja="バックアップ先"; zh="备份位置"; default="Backup in" }
  "sb_mode"       = @{ es="Modo Secure Boot"; en="Secure Boot Mode"; fr="Mode Secure Boot"; de="Secure Boot-Modus"; ru="Режим Secure Boot"; ja="セキュアブートモード"; zh="安全启动模式"; default="Secure Boot Mode" }
  "sb_setup_ok"   = @{ es="Firmware ya en Setup Mode. No se requiere accion adicional."; en="Firmware already in Setup Mode. No additional action required."; fr="Firmware déjà en mode Setup."; de="Firmware bereits im Setup-Modus."; ru="Прошивка уже в режиме Setup."; ja="ファームウェアはすでにセットアップモードです。"; zh="固件已处于设置模式。"; default="Firmware already in Setup Mode. No additional action required." }
  "sb_user_mode"  = @{ es="Firmware en User Mode."; en="Firmware in User Mode."; fr="Firmware en mode utilisateur."; de="Firmware im Benutzermodus."; ru="Прошивка в пользовательском режиме."; ja="ユーザーモードです。"; zh="固件处于用户模式。"; default="Firmware in User Mode." }
  "sb_pk_owner"   = @{ es="El PK activo pertenece al fabricante"; en="The active PK belongs to the manufacturer"; fr="La PK active appartient au fabricant"; de="Der aktive PK gehört dem Hersteller"; ru="Активный PK принадлежит производителю"; ja="PKはメーカーに属します"; zh="活动 PK 属于制造商"; default="The active PK belongs to the manufacturer" }
  "sb_pk_nokey"   = @{ es="Borrar el PK desde Windows requiere su clave privada (no disponible)."; en="Deleting PK from Windows requires its private key (not available)."; fr="La suppression PK nécessite sa clé privée (non disponible)."; de="PK-Löschung erfordert privaten Schlüssel (nicht verfügbar)."; ru="Удаление PK требует закрытого ключа (недоступен)."; ja="PK削除には秘密鍵が必要（利用不可）。"; zh="从 Windows 删除 PK 需要私钥（不可用）。"; default="Deleting PK from Windows requires its private key (not available)." }
  "sb_trying"     = @{ es="Intentando metodos alternativos..."; en="Trying alternative methods..."; fr="Tentative de méthodes alternatives..."; de="Alternative Methoden werden versucht..."; ru="Пробую альтернативные методы..."; ja="代替手段を試行中..."; zh="尝试替代方法..."; default="Trying alternative methods..." }
  "sb_all_fail"   = @{ es="Todos los metodos automaticos fallaron."; en="All automatic methods failed."; fr="Toutes les méthodes automatiques ont échoué."; de="Alle automatischen Methoden fehlgeschlagen."; ru="Все автоматические методы не сработали."; ja="すべての自動的な方法が失敗しました。"; zh="所有自动方法均失败。"; default="All automatic methods failed." }
  "sb_manual_req" = @{ es="Se requiere intervencion manual en el firmware UEFI."; en="Manual intervention in the UEFI firmware is required."; fr="Intervention manuelle dans le firmware UEFI requise."; de="Manueller Eingriff in UEFI-Firmware erforderlich."; ru="Требуется ручное вмешательство в UEFI."; ja="UEFIファームウェアへの手動操作が必要です。"; zh="需要手动操作 UEFI 固件。"; default="Manual intervention in the UEFI firmware is required." }
  "sbm1"          = @{ es="SB Metodo 1: Set-SecureBootUEFI con archivo firmado (.p7)"; en="SB Method 1: Set-SecureBootUEFI with signed file (.p7)"; fr="SB Méthode 1: Set-SecureBootUEFI avec fichier signé"; de="SB Methode 1: Set-SecureBootUEFI mit signierter Datei"; ru="SB Метод 1: Set-SecureBootUEFI с подписанным файлом"; ja="SB方法1: 署名済みファイルでSet-SecureBootUEFI"; zh="SB方法1: 使用签名文件Set-SecureBootUEFI"; default="SB Method 1: Set-SecureBootUEFI with signed file (.p7)" }
  "sbm1_need"     = @{ es="Necesitas archivo firmado con la clave privada del PK."; en="You need a file signed with the PK private key."; fr="Vous avez besoin d'un fichier signé avec la clé privée PK."; de="Sie benötigen eine mit dem privaten PK-Schlüssel signierte Datei."; ru="Нужен файл, подписанный закрытым ключом PK."; ja="PKの秘密鍵で署名されたファイルが必要です。"; zh="需要使用 PK 私钥签名的文件。"; default="You need a file signed with the PK private key." }
  "sbm1_oem"      = @{ es="En equipos OEM esto NO es posible sin el fabricante."; en="On OEM devices this is NOT possible without the manufacturer."; fr="Sur les appareils OEM cela n'est PAS possible sans le fabricant."; de="Bei OEM-Geräten NICHT möglich ohne den Hersteller."; ru="На OEM-устройствах НЕВОЗМОЖНО без производителя."; ja="OEMデバイスではメーカーなしでは不可能です。"; zh="在 OEM 设备上，没有制造商无法实现。"; default="On OEM devices this is NOT possible without the manufacturer." }
  "sbm1_path"     = @{ es="Ruta al archivo .p7 firmado (Enter para omitir)"; en="Path to signed .p7 file (Enter to skip)"; fr="Chemin vers le fichier .p7 signé (Entrée pour ignorer)"; de="Pfad zur signierten .p7-Datei (Eingabe zum Überspringen)"; ru="Путь к .p7 файлу (Enter для пропуска)"; ja=".p7ファイルのパス（スキップはEnter）"; zh=".p7 文件路径（回车跳过）"; default="Path to signed .p7 file (Enter to skip)" }
  "sbm1_skip"     = @{ es="Omitido."; en="Skipped."; fr="Ignoré."; de="Übersprungen."; ru="Пропущено."; ja="スキップ。"; zh="已跳过。"; default="Skipped." }
  "sbm1_nf"       = @{ es="Archivo no encontrado"; en="File not found"; fr="Fichier introuvable"; de="Datei nicht gefunden"; ru="Файл не найден"; ja="ファイルが見つかりません"; zh="文件未找到"; default="File not found" }
  "sbm2"          = @{ es="SB Metodo 2: Verificar si firmware entro en Setup Mode"; en="SB Method 2: Verify if firmware entered Setup Mode"; fr="SB Méthode 2: Vérifier si firmware est en mode Setup"; de="SB Methode 2: Prüfen ob Firmware in Setup-Modus"; ru="SB Метод 2: Проверить режим Setup прошивки"; ja="SB方法2: ファームウェアのSetupモード確認"; zh="SB方法2: 验证固件是否进入设置模式"; default="SB Method 2: Verify if firmware entered Setup Mode" }
  "sbm2_active"   = @{ es="PK activa - sigue en User Mode."; en="PK active - still in User Mode."; fr="PK active - toujours en mode utilisateur."; de="PK aktiv - noch im Benutzermodus."; ru="PK активен - всё ещё в User Mode."; ja="PKはアクティブ - ユーザーモード。"; zh="PK 活动 - 仍在用户模式。"; default="PK active - still in User Mode." }
  "sbm3"          = @{ es="SB Metodo 3: Reducir enforcement via bcdedit"; en="SB Method 3: Reduce enforcement via bcdedit"; fr="SB Méthode 3: Réduire l'application via bcdedit"; de="SB Methode 3: Durchsetzung über bcdedit reduzieren"; ru="SB Метод 3: Снизить принудительное через bcdedit"; ja="SB方法3: bcdeditで強制適用を低減"; zh="SB方法3: 通过 bcdedit 降低强制执行"; default="SB Method 3: Reduce enforcement via bcdedit" }
  "sbm3_note"     = @{ es="NOTA: No borra las keys, deshabilita la validacion en Windows."; en="NOTE: Does not delete keys, disables validation in Windows."; fr="REMARQUE: Ne supprime pas les clés, désactive la validation."; de="HINWEIS: Löscht keine Schlüssel, deaktiviert Validierung."; ru="ПРИМЕЧАНИЕ: Не удаляет ключи, отключает проверку."; ja="注意: キーは削除せず、Windowsでの検証を無効化。"; zh="注意：不删除密钥，禁用 Windows 中的验证。"; default="NOTE: Does not delete keys, disables validation in Windows." }
  "sum_dev"       = @{ es="Equipo             "; en="Device             "; fr="Appareil           "; de="Gerät              "; ru="Устройство         "; ja="デバイス           "; zh="设备               "; default="Device             " }
  "sum_tpm"       = @{ es="TPM limpiado       "; en="TPM cleaned        "; fr="TPM nettoyé        "; de="TPM bereinigt      "; ru="TPM очищен         "; ja="TPMクリーン        "; zh="TPM 已清理         "; default="TPM cleaned        " }
  "sum_owner"     = @{ es="OwnerAuth borrado  "; en="OwnerAuth cleared  "; fr="OwnerAuth effacé   "; de="OwnerAuth gelöscht "; ru="OwnerAuth удалён   "; ja="OwnerAuth消去      "; zh="OwnerAuth 已清除   "; default="OwnerAuth cleared  " }
  "sum_plat"      = @{ es="Platform Auth UEFI "; en="Platform Auth UEFI "; fr="Platform Auth UEFI "; de="Platform Auth UEFI "; ru="Platform Auth UEFI "; ja="プラットフォーム認証"; zh="平台认证 UEFI      "; default="Platform Auth UEFI " }
  "sum_sb"        = @{ es="Secure Boot keys   "; en="Secure Boot keys   "; fr="Clés Secure Boot   "; de="Secure Boot-Schlüssel"; ru="Ключи Secure Boot  "; ja="セキュアブートキー  "; zh="安全启动密钥       "; default="Secure Boot keys   " }
  "sum_yes"       = @{ es="SI (ejecutado siempre)"; en="YES (always executed)"; fr="OUI (toujours exécuté)"; de="JA (immer ausgeführt)"; ru="ДА (всегда)"; ja="はい（常に実行）"; zh="是（始终执行）"; default="YES (always executed)" }
  "sum_ok"        = @{ es="SI"; en="YES"; fr="OUI"; de="JA"; ru="ДА"; ja="はい"; zh="是"; ko="예"; default="YES" }
  "sum_no_bios"   = @{ es="NO - requiere BIOS"; en="NO - requires BIOS"; fr="NON - BIOS requis"; de="NEIN - BIOS nötig"; ru="НЕТ - нужен BIOS"; ja="いいえ - BIOS必要"; zh="否 - 需要 BIOS"; default="NO - requires BIOS" }
  "sum_manual"    = @{ es="Requiere UEFI manual"; en="Requires manual UEFI"; fr="UEFI manuel requis"; de="Manuelles UEFI nötig"; ru="Ручной UEFI"; ja="手動UEFI必要"; zh="需要手动 UEFI"; default="Requires manual UEFI" }
  "on_reboot"     = @{ es="AL REINICIAR:"; en="ON REBOOT:"; fr="AU REDÉMARRAGE:"; de="BEIM NEUSTART:"; ru="ПРИ ПЕРЕЗАГРУЗКЕ:"; ja="再起動時:"; zh="重启时:"; default="ON REBOOT:" }
  "reboot_conf"   = @{ es="El BIOS mostrara confirmacion de borrado de TPM."; en="BIOS will show TPM erase confirmation."; fr="Le BIOS affichera confirmation d'effacement TPM."; de="BIOS zeigt TPM-Löschbestätigung."; ru="BIOS покажет подтверждение удаления TPM."; ja="BIOSがTPM消去確認を表示。"; zh="BIOS 将显示 TPM 擦除确认。"; default="BIOS will show TPM erase confirmation." }
  "reboot_key"    = @{ es="Acepta con F10, F12 o Enter segun tu fabricante."; en="Accept with F10, F12 or Enter depending on manufacturer."; fr="Acceptez avec F10, F12 ou Entrée selon le fabricant."; de="Bestätigen mit F10, F12 oder Enter je nach Hersteller."; ru="Примите с F10, F12 или Enter."; ja="F10、F12またはEnterで確認。"; zh="按 F10、F12 或 Enter 确认。"; default="Accept with F10, F12 or Enter depending on manufacturer." }
  "sb_add_step"   = @{ es="PASO ADICIONAL - Secure Boot:"; en="ADDITIONAL STEP - Secure Boot:"; fr="ÉTAPE SUPPLÉMENTAIRE - Secure Boot:"; de="ZUSÄTZLICHER SCHRITT - Secure Boot:"; ru="ДОПОЛНИТЕЛЬНЫЙ ШАГ - Secure Boot:"; ja="追加手順 - セキュアブート:"; zh="额外步骤 - 安全启动:"; default="ADDITIONAL STEP - Secure Boot:" }
  "reboot_uefi"   = @{ es="Reinicia al UEFI con: shutdown /r /fw /t 0"; en="Reboot to UEFI with: shutdown /r /fw /t 0"; fr="Redémarrez vers UEFI: shutdown /r /fw /t 0"; de="Neustart zu UEFI: shutdown /r /fw /t 0"; ru="Перезагрузка в UEFI: shutdown /r /fw /t 0"; ja="UEFIへ再起動: shutdown /r /fw /t 0"; zh="重启到 UEFI: shutdown /r /fw /t 0"; default="Reboot to UEFI with: shutdown /r /fw /t 0" }
  "ask_reboot"    = @{ es="Reiniciar ahora? S = normal | U = directo al UEFI | N = cancelar"; en="Reboot now? S = normal | U = direct to UEFI | N = cancel"; fr="Redémarrer maintenant? S = normal | U = UEFI | N = annuler"; de="Jetzt neu starten? S = normal | U = UEFI | N = abbrechen"; ru="Перезагрузить? S = обычная | U = UEFI | N = отмена"; ja="再起動? S = 通常 | U = UEFI | N = キャンセル"; zh="现在重启? S=普通 | U=直接UEFI | N=取消"; default="Reboot now? S = normal | U = direct to UEFI | N = cancel" }
  "rebooting"     = @{ es="Reiniciando en 10 segundos... (Ctrl+C para cancelar)"; en="Rebooting in 10 seconds... (Ctrl+C to cancel)"; fr="Redémarrage dans 10 secondes... (Ctrl+C pour annuler)"; de="Neustart in 10 Sekunden... (Ctrl+C zum Abbrechen)"; ru="Перезагрузка через 10 секунд... (Ctrl+C для отмены)"; ja="10秒後再起動...（Ctrl+Cでキャンセル）"; zh="10秒后重启...（Ctrl+C 取消）"; default="Rebooting in 10 seconds... (Ctrl+C to cancel)" }
  "rebooting_fw"  = @{ es="Reiniciando directo al firmware UEFI..."; en="Rebooting directly to UEFI firmware..."; fr="Redémarrage direct vers UEFI..."; de="Direkter Neustart zur UEFI-Firmware..."; ru="Прямая перезагрузка в UEFI..."; ja="UEFIファームウェアへ直接再起動..."; zh="直接重启到 UEFI 固件..."; default="Rebooting directly to UEFI firmware..." }
  "cancel_reboot" = @{ es="Reinicio cancelado. Recuerda reiniciar manualmente."; en="Reboot cancelled. Remember to reboot manually."; fr="Redémarrage annulé. N'oubliez pas de redémarrer manuellement."; de="Neustart abgebrochen. Manuell neu starten."; ru="Перезагрузка отменена. Перезагрузитесь вручную."; ja="再起動キャンセル。手動で再起動してください。"; zh="重启已取消。记得手动重启。"; default="Reboot cancelled. Remember to reboot manually." }
  "tpm_fail_bios" = @{ es="TPM no pudo limpiarse. Entra al BIOS manualmente."; en="TPM could not be cleaned. Enter BIOS manually."; fr="TPM non nettoyé. Entrez dans le BIOS manuellement."; de="TPM nicht bereinigt. BIOS manuell aufrufen."; ru="TPM не очищен. Войдите в BIOS вручную."; ja="TPMをクリーンできません。BIOSに手動で入ってください。"; zh="无法清理 TPM。请手动进入 BIOS。"; default="TPM could not be cleaned. Enter BIOS manually." }
  "uefi_key_lbl"  = @{ es="Tecla UEFI del fabricante"; en="Manufacturer UEFI key"; fr="Touche UEFI du fabricant"; de="Hersteller UEFI-Taste"; ru="Клавиша UEFI производителя"; ja="メーカーUEFIキー"; zh="制造商 UEFI 按键"; default="Manufacturer UEFI key" }
  "sb_path_lbl"   = @{ es="Ruta Secure Boot en UEFI"; en="Secure Boot path in UEFI"; fr="Chemin Secure Boot dans UEFI"; de="Secure Boot-Pfad in UEFI"; ru="Путь Secure Boot в UEFI"; ja="UEFIのSecure Bootパス"; zh="UEFI 中安全启动路径"; default="Secure Boot path in UEFI" }
}

function T { param([string]$k); $t=$Strings[$k]; if(!$t){return "[$k]"}; if($t.ContainsKey($Lang)){return $t[$Lang]}; if($t.ContainsKey("default")){return $t["default"]}; return "[$k]" }

# ── Tabla de fabricantes: tecla UEFI + ruta Secure Boot ──────────────────────
$UEFIDb = @{
  "microsoft"  = @{ key="Vol+ (mantener al encender / hold on power)"; sb="Security -> Change Secure Boot setting -> Clear Secure Boot Keys" }
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
  "zebra"      = @{ key="Del / F2"; sb="Security -> Secure Boot -> Clear Keys" }
  "apple"      = @{ key="Cmd+R (boot) -> Startup Security Utility"; sb="Startup Security Utility -> No Security (disables Secure Boot)" }
  "default"    = @{ key="Del / F2 / F10 / F12 (varies by model)"; sb="Security -> Secure Boot -> Clear / Reset / Delete All Keys" }
}

function Get-UEFIInfo { param([string]$m); $ml=$m.ToLower(); foreach ($k in $UEFIDb.Keys) { if ($k -ne "default" -and $ml -match $k) { return $UEFIDb[$k] } }; return $UEFIDb["default"] }

# ── Deteccion de equipo y firmware ───────────────────────────────────────────
$manufacturer = (Get-WmiObject -Class Win32_ComputerSystem).Manufacturer
$model        = (Get-WmiObject -Class Win32_ComputerSystem).Model
$isSurface    = $model -match "Surface"
$uefiInfo     = Get-UEFIInfo $manufacturer

function Get-FirmwareType { try { return (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control" -Name PEFirmwareType -EA Stop).PEFirmwareType } catch { if (Test-Path "$env:SystemRoot\System32\SecConfig.efi") { return 2 }; return 1 } }
$isUEFI = (Get-FirmwareType) -eq 2

# ── Cabecera ──────────────────────────────────────────────────────────────────
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  $(T 'header_title')" -ForegroundColor Cyan
Write-Host "  Lang: $Lang  |  Culture: $(Get-SystemLanguage)" -ForegroundColor DarkGray
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Firmware : $(if ($isUEFI) { T 'firmware_uefi' } else { T 'firmware_leg' })" -ForegroundColor $(if ($isUEFI){'Green'}else{'Yellow'})
Write-Host "Equipo   : $manufacturer $model" -ForegroundColor Gray
Write-Host "  $(T 'uefi_key_lbl') : $($uefiInfo.key)" -ForegroundColor DarkCyan
Write-Host "  $(T 'sb_path_lbl')  : $($uefiInfo.sb)" -ForegroundColor DarkCyan
if ($isSurface) { Write-Host "  [Surface detected]" -ForegroundColor Yellow }

# ── Info TPM ──────────────────────────────────────────────────────────────────
Write-Host ""; Write-Host "$(T 'tpm_status')" -ForegroundColor Yellow
try {
    $tpm=$Tpm=Get-Tpm; $wt=Get-WmiObject -Namespace root\cimv2\Security\MicrosoftTpm -Class Win32_Tpm -EA SilentlyContinue
    Write-Host "  TpmPresent  : $($tpm.TpmPresent)"; Write-Host "  TpmReady    : $($tpm.TpmReady)"
    Write-Host "  TpmEnabled  : $($tpm.TpmEnabled)"; Write-Host "  TpmOwned    : $($tpm.TpmOwned)"
    Write-Host "  SpecVersion : $($wt.SpecVersion)"
} catch { Write-Host "  $_" -ForegroundColor Yellow }

# ── Info Secure Boot ──────────────────────────────────────────────────────────
Write-Host ""; Write-Host "$(T 'sb_status')" -ForegroundColor Yellow
$sbOK=$false; $sbOn=$false
if ($isUEFI) {
    try {
        $sbOn=Confirm-SecureBootUEFI -EA Stop; $sbOK=$true
        Write-Host "  Enabled : $sbOn"
        foreach ($v in @("PK","KEK","db","dbx")) {
            try { $d=Get-SecureBootUEFI -Name $v -EA Stop; Write-Host "  $v : $(T 'present_kb') ($([math]::Round($d.Bytes.Length/1KB,1)) KB)" -ForegroundColor Green }
            catch { Write-Host "  $v : $(T 'empty_key')" -ForegroundColor Gray }
        }
    } catch { Write-Host "  $_" -ForegroundColor Yellow }
} else { Write-Host "  $(T 'firmware_leg')" -ForegroundColor Yellow }

# ── Confirmacion ──────────────────────────────────────────────────────────────
Write-Host ""; Write-Host "$(T 'warn_title')" -ForegroundColor Red
Write-Host "  $(T 'warn1')" -ForegroundColor Red; Write-Host "  $(T 'warn2')" -ForegroundColor Red
Write-Host "  $(T 'warn3')" -ForegroundColor Red; Write-Host "  $(T 'warn4')" -ForegroundColor Red
Write-Host "  $(T 'warn5')" -ForegroundColor Red; Write-Host ""
$cw=T "confirm_word"; $inp=Read-Host "$(T 'confirm_prompt') [$cw]"
if ($inp -ne $cw) { Write-Host "$(T 'cancelled')" -ForegroundColor Yellow; exit 0 }

# ╔══════════════════════════════════════════════════════════╗
# ║               BLOQUE 1 - LIMPIEZA TPM                   ║
# ╚══════════════════════════════════════════════════════════╝

function Try-ClearTpmNative {
    Write-Host ""; Write-Host "  $(T 'm1')" -ForegroundColor White
    try { Clear-Tpm -EA Stop; Write-Host "    $(T 'ok')" -ForegroundColor Green; return $true }
    catch { Write-Host "    $(T 'err'): $($_.Exception.Message)" -ForegroundColor Red; return $false }
}
function Try-ClearTpmWMI {
    Write-Host ""; Write-Host "  $(T 'm2')" -ForegroundColor White
    try {
        $wmi=Get-WmiObject -Namespace root\cimv2\Security\MicrosoftTpm -Class Win32_Tpm -EA Stop
        Write-Host "    SpecVersion: $($wmi.SpecVersion)" -ForegroundColor Gray
        foreach ($op in @(@{c=14;d="Clear TPM (PPI 1.2+)"},@{c=22;d="Clear+hierarchies (TPM 2.0)"},@{c=5;d="Enable+Activate+Clear"})) {
            Write-Host "    Op $($op.c): $($op.d)" -ForegroundColor Yellow
            $r=$wmi.SetPhysicalPresenceRequest($op.c)
            if ($r.ReturnValue -eq 0) { Write-Host "    $(T 'ok') (ReturnValue=0)" -ForegroundColor Green; return $true }
            Write-Host "    ReturnValue=$($r.ReturnValue), $(T 'next')" -ForegroundColor Red
        }; return $false
    } catch { Write-Host "    $(T 'err'): $($_.Exception.Message)" -ForegroundColor Red; return $false }
}
function Try-ClearTpmWmic {
    Write-Host ""; Write-Host "  $(T 'm3')" -ForegroundColor White
    try {
        $out=cmd /c 'wmic /namespace:\\root\cimv2\Security\MicrosoftTpm path Win32_Tpm call SetPhysicalPresenceRequest 14' 2>&1
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
        $wmi=Get-WmiObject -Namespace root\cimv2\Security\MicrosoftTpm -Class Win32_Tpm -EA Stop
        $r1=$wmi.SetPhysicalPresenceRequest(21); Write-Host "    Op 21 ReturnValue: $($r1.ReturnValue)" -ForegroundColor Gray
        $r2=$wmi.SetPhysicalPresenceRequest(18); Write-Host "    Op 18 ReturnValue: $($r2.ReturnValue)" -ForegroundColor Gray
        Write-Host "    $(T 'sent_fw')" -ForegroundColor Green
    } catch { Write-Host "    $($_.Exception.Message)" -ForegroundColor Yellow }
}

# ╔══════════════════════════════════════════════════════════╗
# ║            BLOQUE 2 - LIMPIEZA SECURE BOOT              ║
# ╚══════════════════════════════════════════════════════════╝

function Backup-SecureBootKeys {
    Write-Host ""; Write-Host "  $(T 'sb_backup')" -ForegroundColor White
    $p="$env:TEMP\SecureBoot_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $p -Force | Out-Null
    foreach ($v in @("PK","KEK","db","dbx")) {
        try { $d=Get-SecureBootUEFI -Name $v -EA Stop; [IO.File]::WriteAllBytes("$p\$v.bin",$d.Bytes); Write-Host "    $v -> $p\$v.bin ($([math]::Round($d.Bytes.Length/1KB,1)) KB)" -ForegroundColor Gray }
        catch { Write-Host "    $v : $(T 'empty_key')" -ForegroundColor Gray }
    }
    Write-Host "    $(T 'sb_backup_in'): $p" -ForegroundColor Green; return $p
}
function Get-SecureBootMode {
    try {
        $sb=Confirm-SecureBootUEFI -EA Stop
        try { $sm=(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State" -EA Stop).UEFISecureBootEnabled; if ($sm -eq 0){return "SetupMode"}; return "UserMode" }
        catch { if ($sb){return "UserMode"} else {return "SetupMode"} }
    } catch { return "Unknown" }
}
function Try-ClearSB-SignedFile {
    Write-Host ""; Write-Host "  $(T 'sbm1')" -ForegroundColor White
    Write-Host "    $(T 'sbm1_need')" -ForegroundColor Gray
    Write-Host "    $(T 'sbm1_oem')" -ForegroundColor Gray
    $sf=Read-Host "    $(T 'sbm1_path')"
    if ([string]::IsNullOrWhiteSpace($sf)) { Write-Host "    $(T 'sbm1_skip')" -ForegroundColor Yellow; return $false }
    if (-not (Test-Path $sf)) { Write-Host "    $(T 'sbm1_nf'): $sf" -ForegroundColor Red; return $false }
    try { Set-SecureBootUEFI -Name "PK" -Time (Get-Date) -SignedFilePath $sf -EA Stop; Write-Host "    $(T 'ok') -> Setup Mode" -ForegroundColor Green; return $true }
    catch { Write-Host "    $(T 'err'): $($_.Exception.Message)" -ForegroundColor Red; return $false }
}
function Try-ClearSB-VerifySetupMode {
    Write-Host ""; Write-Host "  $(T 'sbm2')" -ForegroundColor White
    try {
        $mode=Get-SecureBootMode; Write-Host "    $(T 'sb_mode'): $mode" -ForegroundColor Gray
        if ($mode -eq "SetupMode") { Write-Host "    $(T 'sb_setup_ok')" -ForegroundColor Green; return $true }
        try { $pk=Get-SecureBootUEFI -Name "PK" -EA Stop; Write-Host "    $(T 'sbm2_active') ($([math]::Round($pk.Bytes.Length/1KB,1)) KB)" -ForegroundColor Yellow }
        catch { Write-Host "    $(T 'ok') -> Setup Mode" -ForegroundColor Green; return $true }
        return $false
    } catch { Write-Host "    $(T 'err'): $($_.Exception.Message)" -ForegroundColor Red; return $false }
}
function Try-ClearSB-BcdEdit {
    Write-Host ""; Write-Host "  $(T 'sbm3')" -ForegroundColor White
    Write-Host "    $(T 'sbm3_note')" -ForegroundColor Gray
    try {
        $o1=bcdedit /set "{current}" testsigning on 2>&1
        $o2=bcdedit /set "{current}" nointegritychecks on 2>&1
        Write-Host "    testsigning      : $o1" -ForegroundColor Gray
        Write-Host "    nointegritychecks: $o2" -ForegroundColor Gray
        if (($o1 -match "correctamente|successfully|The operation completed") -or ($o2 -match "correctamente|successfully|The operation completed")) { Write-Host "    $(T 'ok')" -ForegroundColor Green; return $true }
        return $false
    } catch { Write-Host "    $(T 'err'): $($_.Exception.Message)" -ForegroundColor Red; return $false }
}
function Show-SBManualInstructions {
    Write-Host ""
    Write-Host "  ════ $(T 'uefi_key_lbl'): $($uefiInfo.key) ════" -ForegroundColor Cyan
    Write-Host "  ════ $(T 'sb_path_lbl') : $($uefiInfo.sb) ════" -ForegroundColor Cyan
    Write-Host ""
    if ($isSurface) {
        Write-Host "  Surface UEFI Access:" -ForegroundColor Yellow
        Write-Host "    1. Power off completely" -ForegroundColor White
        Write-Host "    2. Hold Vol+ button" -ForegroundColor White
        Write-Host "    3. Press power, release on Surface logo" -ForegroundColor White
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
    if (-not $sbOK) { Write-Host "  $(T 'sb_manual_req')" -ForegroundColor Yellow; Show-SBManualInstructions; return $false }
    Backup-SecureBootKeys | Out-Null
    $mode=Get-SecureBootMode
    Write-Host ""; Write-Host "  $(T 'sb_mode'): $mode" -ForegroundColor $(if($mode-eq"SetupMode"){'Green'}else{'Yellow'})
    if ($mode -eq "SetupMode") { Write-Host "  $(T 'sb_setup_ok')" -ForegroundColor Green; return $true }
    Write-Host "  $(T 'sb_user_mode')" -ForegroundColor Yellow
    Write-Host "  $(T 'sb_pk_owner'): $manufacturer" -ForegroundColor Yellow
    Write-Host "  $(T 'sb_pk_nokey')" -ForegroundColor Yellow
    Write-Host "  $(T 'sb_trying')" -ForegroundColor White
    $r=Try-ClearSB-SignedFile
    if (!$r){$r=Try-ClearSB-VerifySetupMode}
    if (!$r){$r=Try-ClearSB-BcdEdit}
    if (!$r) { Write-Host ""; Write-Host "  $(T 'sb_all_fail')" -ForegroundColor Red; Write-Host "  $(T 'sb_manual_req')" -ForegroundColor Yellow; Show-SBManualInstructions }
    return $r
}

# ╔══════════════════════════════════════════════════════════╗
# ║                  EJECUCION PRINCIPAL                    ║
# ╚══════════════════════════════════════════════════════════╝

Write-Host ""; Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  $(T 'blk1_title')" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$tpmOK=$false
$tpmOK=Try-ClearTpmNative
if(!$tpmOK){$tpmOK=Try-ClearTpmWMI}
if(!$tpmOK){$tpmOK=Try-ClearTpmWmic}
Clear-TpmOwnerAuth; Clear-UEFIPlatformAuth

Write-Host ""; Write-Host "  $(if($tpmOK){T 'res_ok'}else{T 'res_fail'})" -ForegroundColor $(if($tpmOK){'Green'}else{'Red'})

$sbOK2=Clear-SecureBootKeys

# ── Resumen ───────────────────────────────────────────────────────────────────
Write-Host ""; Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  $(T 'sum_title')" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  $(T 'sum_dev')   : $manufacturer $model"
Write-Host "  $(T 'sum_tpm')   : $(if($tpmOK){T 'sum_ok'}else{T 'sum_no_bios'})"
Write-Host "  $(T 'sum_owner') : $(T 'sum_yes')"
Write-Host "  $(T 'sum_plat')  : $(T 'sum_yes') (op 21+18)"
Write-Host "  $(T 'sum_sb')    : $(if($sbOK2){T 'sum_ok'}else{T 'sum_manual'})"
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
    $rb=Read-Host "$(T 'ask_reboot')"
    if ($rb -eq "S") { Write-Host "$(T 'rebooting')" -ForegroundColor Cyan; Start-Sleep 10; Restart-Computer -Force }
    elseif ($rb -eq "U") { Write-Host "$(T 'rebooting_fw')" -ForegroundColor Cyan; Start-Sleep 3; shutdown /r /fw /t 0 }
    else { Write-Host "$(T 'cancel_reboot')" -ForegroundColor Yellow }
} else {
    Write-Host "  $(T 'tpm_fail_bios')" -ForegroundColor Red
    Write-Host "  $(T 'uefi_key_lbl'): $($uefiInfo.key)" -ForegroundColor Cyan
    Write-Host "  $(T 'sb_path_lbl') : $($uefiInfo.sb)" -ForegroundColor Cyan
    exit 1
}
