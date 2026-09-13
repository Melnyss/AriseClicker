# AriseClicker

Autoclicker per Windows con GUI minimal in dark mode (PowerShell + WinForms).

Comando (puo' essere bloccato da Windows Defender o
altri antivirus perche' il pattern "scarica ed esegui" e' un'euristica comune):

```powershell
powershell -ExecutionPolicy Bypass -Command "Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/Melnyss/AriseClicker/main/AriseClicker.ps1')"
```

Se ricevi un errore tipo "Accesso negato" nell'eseguire `powershell.exe`, scarica `AriseClicker.ps1` e avvialo con
tasto destro > *Esegui con PowerShell*.

## Funzionalita

- Hotkey globale personalizzabile (default `F6`) per avviare/fermare da qualunque finestra
- Click sinistro o destro
- Velocita regolabile da 1 a 100 click al secondo tramite slider
- Click simulati con `SendInput` (Win32)
