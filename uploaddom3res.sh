#!/bin/bash

PREFIX=$1
RESULTS_DIR=${2:-.}

GOOGLE_SCRIPT_URL="https://script.google.com/macros/s/AKfycbzgVAWR-72S6X4anfAR5Fm9TdfbfKdCMNyl1JeZDccvxkY0k4mqJ9FuxbjyLzRW6GDQvw/exec"

ASSIGNMENT="dom3"

if [ -z "$PREFIX" ]; then
  echo "Upotreba: sudo ./uploaddom3res.sh <studentski-prefiks>"
  echo "Primer: sudo ./uploaddom3res.sh pg20220043"
  exit 1
fi

SUMMARY_FILE="$RESULTS_DIR/sumarna-provera-domaci3-${PREFIX}.txt"
ZIP_FILE="$RESULTS_DIR/dokazi-domaci3-${PREFIX}.zip"
UPLOAD_RESPONSE_FILE="$RESULTS_DIR/google-upload-domaci3-${PREFIX}.json"

echo "======================================"
echo "UPLOAD OCENE ZA DOMAĆI 3: $PREFIX"
echo "======================================"
echo ""

# --------------------------------------
# Provera fajlova
# --------------------------------------

if [ ! -f "$SUMMARY_FILE" ]; then
  echo "[GREŠKA] Nije pronađen fajl sa sumarnom proverom:"
  echo "$SUMMARY_FILE"
  exit 1
fi

if [ ! -f "$ZIP_FILE" ]; then
  echo "[GREŠKA] Nije pronađen ZIP fajl sa dokazima:"
  echo "$ZIP_FILE"
  echo "Upload ocene nije dozvoljen bez prethodno kreiranog ZIP fajla."
  exit 1
fi

# --------------------------------------
# Čitanje broja poena
# --------------------------------------

GRADE=$(grep "UKUPNO USPEŠNO ISPUNJENIH ZAHTEVA" "$SUMMARY_FILE" | tail -n 1 | sed -E 's/.*: ([0-9]+)\/[0-9]+.*/\1/')

if ! [[ "$GRADE" =~ ^[0-9]+$ ]]; then
  echo "[GREŠKA] Nije moguće pročitati broj poena iz fajla:"
  echo "$SUMMARY_FILE"
  echo ""
  echo "Očekivani format linije:"
  echo "UKUPNO USPEŠNO ISPUNJENIH ZAHTEVA: 8/10"
  exit 1
fi

echo "[OK] Pronađen summary fajl: $SUMMARY_FILE"
echo "[OK] Pronađen ZIP fajl: $ZIP_FILE"
echo "[OK] Broj poena za upload: $GRADE"
echo "[OK] Assignment: $ASSIGNMENT"
echo ""

# --------------------------------------
# Unos šifre
# --------------------------------------

read -s -p "Unesite upload šifru: " UPLOAD_SECRET
echo ""
echo ""

if [ -z "$UPLOAD_SECRET" ]; then
  echo "[GREŠKA] Upload šifra nije uneta."
  exit 1
fi

if [ "$GOOGLE_SCRIPT_URL" = "OVDE_IDE_GOOGLE_APPS_SCRIPT_WEB_APP_URL" ]; then
  echo "[GREŠKA] Nije podešen GOOGLE_SCRIPT_URL u skripti."
  echo "Uredi skriptu i zameni OVDE_IDE_GOOGLE_APPS_SCRIPT_WEB_APP_URL stvarnim Web App URL-om."
  exit 1
fi

# --------------------------------------
# Slanje rezultata na Google Apps Script
# --------------------------------------

echo "Šaljem rezultat na Google Sheet..."
echo ""

RESPONSE=$(curl -L -s -w "\nHTTP_STATUS:%{http_code}" "$GOOGLE_SCRIPT_URL" \
  -H "Content-Type: application/json" \
  -d "{\"secret\":\"$UPLOAD_SECRET\",\"username\":\"$PREFIX\",\"grade\":$GRADE,\"assignment\":\"$ASSIGNMENT\"}")
  
HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | sed "s/HTTP_STATUS://")
BODY=$(echo "$RESPONSE" | sed "/HTTP_STATUS:/d")

echo "$BODY" > "$UPLOAD_RESPONSE_FILE"

echo "Google Apps Script odgovor:"
echo "$BODY"
echo ""

if [ "$HTTP_STATUS" = "200" ]; then
  if echo "$BODY" | grep -q '"success":true'; then
    echo "[OK] Rezultat je uspešno poslat u Google Sheet."
    echo "[OK] Odgovor je sačuvan u: $UPLOAD_RESPONSE_FILE"
  else
    echo "[GREŠKA] Google Apps Script je odgovorio statusom 200, ali upload nije uspešan."
    echo "Proveri odgovor u: $UPLOAD_RESPONSE_FILE"
    exit 1
  fi
else
  echo "[GREŠKA] Upload nije uspeo. HTTP status: $HTTP_STATUS"
  echo "Odgovor je sačuvan u: $UPLOAD_RESPONSE_FILE"
  exit 1
fi