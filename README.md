# Clear-TPM-Full
Advanced PowerShell tool for TPM cleanup, Secure Boot diagnostics, and UEFI guidance on modern Windows systems.

🧠 Overview

Clear-TPM-Full is a professional-grade script designed for low-level platform security management, combining:

TPM cleanup (multiple methods)

Secure Boot inspection and diagnostics

Firmware (UEFI/BIOS) detection

Interactive guidance for manual firmware operations

It is built for IT professionals, sysadmins, security researchers, and advanced users who need visibility and control over platform security components.

⚙️ Key Features
🔐 TPM (Trusted Platform Module)

Native cleanup via Clear-Tpm

Multi-layer fallback:

WMI (Win32_Tpm)

Physical Presence Interface (PPI op-codes: 14, 22, 5)

WMIC legacy method

OwnerAuth reset from Windows registry

Firmware-level requests (op 21 / 18)

🔑 Secure Boot

Detects User Mode vs Setup Mode

Enumerates keys:

PK (Platform Key)

KEK (Key Exchange Key)

db / dbx

Automatic backup of Secure Boot keys

Controlled attempts to transition to Setup Mode

Optional support for signed .p7 payloads

🧠 Smart Environment Detection

Detects:

Manufacturer and model

UEFI vs Legacy BIOS

Special devices (e.g., Microsoft Surface)

Provides vendor-specific instructions

🌍 Multilanguage Support

Automatic system language detection

Built-in translations (EN, ES, FR, DE, RU, JA, ZH, etc.)

Easily extendable translation system

🧭 Guided User Experience

Interactive prompts

Vendor-specific UEFI access keys

BIOS navigation paths for Secure Boot

Reboot options:

Normal reboot

Direct to UEFI firmware (shutdown /r /fw /t 0)

🖥️ Compatibility

Windows 10 / 11

TPM 1.2 / 2.0

UEFI firmware recommended

Requires Administrator privileges

⚠️ Important Limitations

❌ Does NOT remove BIOS/UEFI passwords

❌ Cannot modify Secure Boot without valid private keys (PK)

❌ Cannot bypass firmware protections (e.g., Surface DFCI / enterprise locks)

❌ Some operations require physical confirmation in firmware

🧪 Use Cases

TPM reset and diagnostics

Secure Boot auditing

Device preparation for redeployment

Troubleshooting platform security issues

Advanced system inspection

🚀 Usage
# Run as Administrator
.\Clear-TPM-Full.ps1
🎬 Demo

Example output (PowerShell):

Firmware : UEFI
Device   : Microsoft Surface Laptop Go

TPM Status:
  TpmPresent  : True
  TpmReady    : True

Secure Boot Status:
  Enabled : True
  PK      : present (1.3 KB)

WARNING - THE FOLLOWING WILL BE ERASED:
[TPM] All keys...
[SB]  Secure Boot keys...

Type ERASE to confirm:
📸 Screenshots

Add your screenshots in:

/docs/screenshots/main.png
/docs/screenshots/secureboot.png

And display them like this:

![Main](docs/screenshots/main.png)
![Secure Boot](docs/screenshots/secureboot.png)
🛣️ Roadmap

GUI version (WinForms / WPF)

Export diagnostic report (JSON / TXT)

Logging system

Dry-run / audit-only mode

Remote execution support (PowerShell Remoting)

Enhanced Surface / DFCI detection

Plugin system for OEM-specific behaviors

📌 Technical Note

This tool operates within Windows OS limitations.

Firmware-level protections (UEFI, Secure Boot, OEM security policies) are by design not bypassable via software.

🤝 Contributing

Contributions, improvements, and suggestions are welcome.

📄 License

MIT License
