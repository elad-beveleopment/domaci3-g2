#!/bin/bash

PREFIX=$1
RESULTS_DIR=${2:-.}

GOOGLE_SCRIPT_URL="https://script.google.com/macros/s/AKfycbzgVAWR-72S6X4anfAR5Fm9TdfbfKdCMNyl1JeZDccvxkY0k4mqJ9FuxbjyLzRW6GDQvw/exec"
ASSIGNMENT="dom3"

if [ -z "$PREFIX" ]; then
  echo "Upotreba: sudo ./uploaddom3res.sh <studentski-prefiks> [folder-sa-rezultatima]"
  echo "Primer: sudo ./uploaddom3res.sh pg20220043"
  exit 1
fi

SUMMARY_FILE="$RESULTS_DIR/sumarna-provera-domaci3-${PREFIX}.txt"
ZIP_FILE="$RESULTS_DIR/dokazi-domaci3-${PREFIX}.zip"
UPLOAD_RESPONSE_FILE="$RESULTS_DIR/google-upload-domaci3-${PREFIX}.json"

echo "======================================"
echo "UPLOAD OCENE I ZIP DOKAZA ZA DOMAĆI 3: $PREFIX"
echo "======================================"
echo ""

if [ ! -f "$SUMMARY_FILE" ]; then
  echo "[GREŠKA] Nije pronađen fajl sa sumarnom proverom:"
  echo "$SUMMARY_FILE"
  exit 1
fi

if [ ! -f "$ZIP_FILE" ]; then
  echo "[GREŠKA] Nije pronađen ZIP fajl sa dokazima:"
  echo "$ZIP_FILE"
  echo "Upload nije dozvoljen bez prethodno kreiranog ZIP fajla."
  exit 1
fi

GRADE=$(grep "UKUPNO USPEŠNO ISPUNJENIH ZAHTEVA" "$SUMMARY_FILE" | tail -n 1 | sed -E 's/.*: ([0-9]+)\/[0-9]+.*/\1/')

if ! [[ "$GRADE" =~ ^[0-9]+$ ]]; then
  echo "[GREŠKA] Nije moguće pročitati broj poena iz fajla:"
  echo "$SUMMARY_FILE"
  exit 1
fi

if [ "$GOOGLE_SCRIPT_URL" = "OVDE_IDE_GOOGLE_APPS_SCRIPT_WEB_APP_URL" ]; then
  echo "[GREŠKA] Nije podešen GOOGLE_SCRIPT_URL u skripti."
  exit 1
fi

ZIP_FILE_NAME=$(basename "$ZIP_FILE")

echo "[OK] Summary fajl: $SUMMARY_FILE"
echo "[OK] ZIP fajl: $ZIP_FILE"
echo "[OK] Broj poena: $GRADE"
echo "[OK] Assignment: $ASSIGNMENT"
echo ""

read -s -p "Unesite upload šifru: " UPLOAD_SECRET
echo ""
echo ""

if [ -z "$UPLOAD_SECRET" ]; then
  echo "[GREŠKA] Upload šifra nije uneta."
  exit 1
fi

echo "Pripremam ZIP za upload..."

if base64 --help 2>/dev/null | grep -q -- "-w"; then
  ZIP_BASE64=$(base64 -w 0 "$ZIP_FILE")
else
  ZIP_BASE64=$(base64 "$ZIP_FILE" | tr -d '\n')
fi

echo "[OK] ZIP je enkodovan."
echo "Šaljem rezultat i ZIP na Google Apps Script..."
echo ""

JSON_PAYLOAD=$(cat <<EOF
{
  "secret": "$UPLOAD_SECRET",
  "username": "$PREFIX",
  "grade": $GRADE,
  "assignment": "$ASSIGNMENT",
  "zipFileName": "$ZIP_FILE_NAME",
  "zipBase64": "$ZIP_BASE64"
}
EOF
)

RESPONSE=$(curl -L -s -w "\nHTTP_STATUS:%{http_code}" "$GOOGLE_SCRIPT_URL" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | sed "s/HTTP_STATUS://")
BODY=$(echo "$RESPONSE" | sed "/HTTP_STATUS:/d")

echo "$BODY" > "$UPLOAD_RESPONSE_FILE"

echo "Google Apps Script odgovor:"
echo "$BODY"
echo ""

if [ "$HTTP_STATUS" = "200" ] && echo "$BODY" | grep -q '"success":true'; then
  echo "[OK] Rezultat je uspešno poslat u Google Sheet."
  echo "[OK] ZIP dokaz je poslat na Google Drive."
  echo "[OK] Odgovor je sačuvan u: $UPLOAD_RESPONSE_FILE"
  echo ""

  echo "======================================"
  echo "GAŠENJE DOCKER COMPOSE APLIKACIJE"
  echo "======================================"

  if [ -f "compose.yaml" ]; then
    sudo docker compose down -v

    if [ $? -eq 0 ]; then
      echo "[OK] Izvršeno: sudo docker compose down -v"
      echo "[OK] Kontejneri, mreža i volume-i iz compose projekta su uklonjeni."
    else
      echo "[UPOZORENJE] Upload je uspeo, ali docker compose down -v nije uspešno izvršen."
    fi
  else
    echo "[UPOZORENJE] compose.yaml nije pronađen. Preskačem docker compose down -v."
  fi

else
  echo "[GREŠKA] Upload nije uspeo. HTTP status: $HTTP_STATUS"
  echo "Odgovor je sačuvan u: $UPLOAD_RESPONSE_FILE"
  exit 1
fi