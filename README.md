# AriseClicker

Autoclicker per Windows con GUI minimal in dark mode (PowerShell + WinForms).

## Avvio rapido

Metodo consigliato (scarica il file e poi lo esegue - alcuni antivirus bloccano
lo scaricare-ed-eseguire-in-memoria in un unico comando):

```powershell
irm https://raw.githubusercontent.com/Melnyss/AriseClicker/main/AriseClicker.ps1 -OutFile "$env:TEMP\AriseClicker.ps1"
powershell -ExecutionPolicy Bypass -File "$env:TEMP\AriseClicker.ps1"
```

In alternativa, un unico comando (puo' essere bloccato da Windows Defender o
altri antivirus perche' il pattern "scarica ed esegui" e' un'euristica comune):

```powershell
powershell -ExecutionPolicy Bypass -Command "Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/Melnyss/AriseClicker/main/AriseClicker.ps1')"
```

Se ricevi un errore tipo "Accesso negato" nell'eseguire `powershell.exe`, usa il
metodo a due comandi sopra, oppure scarica `AriseClicker.ps1` e avvialo con
tasto destro > *Esegui con PowerShell*.

## Funzionalita

- Hotkey globale personalizzabile (default `F6`) per avviare/fermare da qualunque finestra
- Click sinistro o destro
- Velocita regolabile da 1 a 100 click al secondo tramite slider
- Click simulati con `SendInput` (Win32)

## Nota

Gli autoclicker violano i Termini di Servizio di molti giochi/servizi online (rischio ban).
Usalo solo dove e consentito esplicitamente (task ripetitivi locali, software che lo permette).
