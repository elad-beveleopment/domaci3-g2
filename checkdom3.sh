#!/bin/bash

PREFIX=$1

if [ -z "$PREFIX" ]; then
  echo "Upotreba: sudo ./checkdom3.sh <studentski-prefiks>"
  echo "Primer: sudo ./checkdom3.sh pg20220043"
  exit 1
fi

PROJECT_NAME="${PREFIX}-app"

BACK_CONT="${PREFIX}-back"
FRONT_CONT="${PREFIX}-front"
DB_CONT="${PREFIX}-db"

BACK_IMG="${PREFIX}-img1"
FRONT_IMG="${PREFIX}-img2"

NETWORK="${PREFIX}-network"

# Database volume može biti:
# 1) Compose-generisan: pg20220043-app_mysql-data
# 2) Eksplicitno imenovan: pg20220043-mysql-data
VOLUME_KEY="mysql-data"
COMPOSE_VOLUME="${PROJECT_NAME}_${VOLUME_KEY}"
EXPLICIT_VOLUME="${PREFIX}-mysql-data"

COMPOSE_FILE="compose.yaml"
BACKEND_ENV="env/backend.env"
FRONTEND_ENV="env/frontend.env"
STATUS_FILE="${PREFIX}.txt"

REPORT="provera-domaci3-${PREFIX}.txt"
SUMMARY_FILE="sumarna-provera-domaci3-${PREFIX}.txt"
API_RESPONSE_FILE="api-projects-${PREFIX}.json"

OK_COUNT=0
TOTAL_REQUIREMENTS=10

echo "PROVERA DOMAĆEG 3 G2 ZA: $PREFIX" > "$REPORT"
echo "======================================" >> "$REPORT"
echo "" >> "$REPORT"

echo "SUMARNA PROVERA DOMAĆEG 3 G2 ZA: $PREFIX" > "$SUMMARY_FILE"
echo "======================================" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

print_result() {
  local REQ=$1
  local STATUS=$2
  local MESSAGE=$3

  if [ "$STATUS" = "OK" ]; then
    OK_COUNT=$((OK_COUNT + 1))
  fi

  echo "Zahtev $REQ: [$STATUS] $MESSAGE"
  echo "Zahtev $REQ: [$STATUS] $MESSAGE" >> "$REPORT"
  echo "Zahtev $REQ: [$STATUS] $MESSAGE" >> "$SUMMARY_FILE"
}

section() {
  echo ""
  echo "$1"
  echo "$1" >> "$REPORT"
  echo "--------------------------------------" >> "$REPORT"
}

container_exists() {
  sudo docker container inspect "$1" > /dev/null 2>&1
}

container_running() {
  [ "$(sudo docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = "true" ]
}

image_exists() {
  sudo docker image inspect "$1" > /dev/null 2>&1
}

network_exists() {
  sudo docker network inspect "$1" > /dev/null 2>&1
}

volume_exists() {
  sudo docker volume inspect "$1" > /dev/null 2>&1
}

get_existing_volume() {
  if sudo docker volume inspect "$COMPOSE_VOLUME" > /dev/null 2>&1; then
    echo "$COMPOSE_VOLUME"
  elif sudo docker volume inspect "$EXPLICIT_VOLUME" > /dev/null 2>&1; then
    echo "$EXPLICIT_VOLUME"
  else
    echo ""
  fi
}

container_in_network() {
  local CONTAINER=$1
  local NETWORK_NAME=$2

  sudo docker network inspect "$NETWORK_NAME" 2>/dev/null | grep -q "\"Name\": \"$CONTAINER\""
}

port_available() {
  local PORT=$1
  curl -s --max-time 5 "http://localhost:$PORT" > /dev/null 2>&1
}

compose_has_service() {
  local SERVICE=$1
  grep -Eq "^[[:space:]]{2}${SERVICE}:" "$COMPOSE_FILE" 2>/dev/null
}

compose_contains() {
  local PATTERN=$1
  grep -q "$PATTERN" "$COMPOSE_FILE" 2>/dev/null
}

compose_contains_regex() {
  local PATTERN=$1
  grep -Eq "$PATTERN" "$COMPOSE_FILE" 2>/dev/null
}

# --------------------------------------
# 0. Osnovna provera
# --------------------------------------

section "0. OSNOVNA PROVERA"

if [ -f "$COMPOSE_FILE" ]; then
  echo "[OK] compose.yaml postoji."
  echo "[OK] compose.yaml postoji." >> "$REPORT"
else
  echo "[GREŠKA] compose.yaml ne postoji. Dalje provere će verovatno pasti."
  echo "[GREŠKA] compose.yaml ne postoji." >> "$REPORT"
fi

# --------------------------------------
# Zahtev 1
# compose.yaml postoji + name projekta
# --------------------------------------

section "1. PROVERA COMPOSE FAJLA I NAZIVA PROJEKTA"

if [ -f "$COMPOSE_FILE" ] \
  && grep -Eq "^[[:space:]]*name:[[:space:]]*[\"']?${PROJECT_NAME}[\"']?" "$COMPOSE_FILE"; then
  print_result "1" "OK" "compose.yaml postoji i naziv projekta je $PROJECT_NAME."
else
  print_result "1" "NIJE OK" "Nedostaje compose.yaml ili naziv projekta nije u odgovarajućem formatu."
fi

# --------------------------------------
# Zahtev 2
# servisi backend, frontend, database
# --------------------------------------

section "2. PROVERA DEFINISANIH SERVISA"

if [ -f "$COMPOSE_FILE" ] \
  && compose_has_service "backend" \
  && compose_has_service "frontend" \
  && compose_has_service "database"; then
  print_result "2" "OK" "Definisani su servisi backend, frontend i database."
else
  print_result "2" "NIJE OK" "Nisu pronađena sva tri servisa: backend, frontend i database."
fi

# --------------------------------------
# Zahtev 3
# build/image, container_name, env_file, mreža, DB_HOST
# --------------------------------------

# --------------------------------------
# Zahtev 3
# build/image, container_name, env_file, mreža, DB_HOST
# --------------------------------------

section "3. PROVERA SERVISA, IMAGE-A, KONTEJNERA, ENV I DB_HOST"

BACKEND_ENV_OK=false
MYSQL_IMAGE_OK=false

if [ -f "$BACKEND_ENV" ] && grep -Eq "^DB_HOST=${DB_CONT}[[:space:]]*$" "$BACKEND_ENV"; then
  BACKEND_ENV_OK=true
fi

if [ -f "$COMPOSE_FILE" ] && grep -Eq "image:[[:space:]]*(.*/)?mysql(:[A-Za-z0-9._-]+)?" "$COMPOSE_FILE"; then
  MYSQL_IMAGE_OK=true
fi

if [ -f "$COMPOSE_FILE" ] \
  && grep -q "container_name: $BACK_CONT" "$COMPOSE_FILE" \
  && grep -q "container_name: $FRONT_CONT" "$COMPOSE_FILE" \
  && grep -q "container_name: $DB_CONT" "$COMPOSE_FILE" \
  && [ "$MYSQL_IMAGE_OK" = true ] \
  && grep -q "image: $BACK_IMG" "$COMPOSE_FILE" \
  && grep -q "image: $FRONT_IMG" "$COMPOSE_FILE" \
  && grep -q "context: ./backend" "$COMPOSE_FILE" \
  && grep -q "context: ./frontend" "$COMPOSE_FILE" \
  && grep -q "env_file:" "$COMPOSE_FILE" \
  && grep -q "./env/backend.env" "$COMPOSE_FILE" \
  && grep -q "$NETWORK" "$COMPOSE_FILE" \
  && [ "$BACKEND_ENV_OK" = true ]; then
  print_result "3" "OK" "Servisi imaju odgovarajuće build/image vrednosti, nazive kontejnera, env podešavanja, mrežu i DB_HOST=$DB_CONT."
else
  print_result "3" "NIJE OK" "Nedostaju očekivane build/image/container/env/network vrednosti, MySQL image nije definisan ili DB_HOST nije podešen u backend-u."
fi

# --------------------------------------
# Zahtev 4
# volumes za backend, frontend i database
# --------------------------------------

section "4. PROVERA VOLUMENA U COMPOSE FAJLU"

if [ -f "$COMPOSE_FILE" ] \
  && grep -q "./backend:/app" "$COMPOSE_FILE" \
  && grep -q "/app/__pycache__" "$COMPOSE_FILE" \
  && grep -q "./frontend:/app" "$COMPOSE_FILE" \
  && grep -q "/app/node_modules" "$COMPOSE_FILE" \
  && grep -q "mysql-data:/var/lib/mysql" "$COMPOSE_FILE" \
  && grep -q "./db/init.sql:/docker-entrypoint-initdb.d/init.sql" "$COMPOSE_FILE" \
  && grep -q "./db/my.cnf:/etc/mysql/conf.d/my-custom.cnf:ro" "$COMPOSE_FILE"; then
  print_result "4" "OK" "Definisani su očekivani volume-i za backend, frontend i database."
else
  print_result "4" "NIJE OK" "Nedostaje neki od očekivanih volume-a za backend, frontend ili database."
fi

# --------------------------------------
# Zahtev 5
# portovi, frontend.env, depends_on
# --------------------------------------

section "5. PROVERA PORTOVA, FRONTEND_ENV I ZAVISNOSTI"

FRONTEND_ENV_OK=false

if [ -f "$FRONTEND_ENV" ] && grep -Eq "5000" "$FRONTEND_ENV"; then
  FRONTEND_ENV_OK=true
fi

if [ -f "$COMPOSE_FILE" ] \
  && grep -Eq "[\"']?5000:3000[\"']?" "$COMPOSE_FILE" \
  && grep -Eq "[\"']?7000:3000[\"']?" "$COMPOSE_FILE" \
  && grep -q "depends_on:" "$COMPOSE_FILE" \
  && grep -q "condition: service_healthy" "$COMPOSE_FILE" \
  && grep -q "backend" "$COMPOSE_FILE" \
  && [ "$FRONTEND_ENV_OK" = true ]; then
  print_result "5" "OK" "Backend je dostupan na portu 5000, frontend na portu 7000, frontend.env pokazuje na backend port 5000 i zavisnosti su definisane."
else
  print_result "5" "NIJE OK" "Nedostaju portovi definisani zadatkom, frontend.env nije podešen na odgovarajući port ili depends_on uslovi nisu definisani."
fi

# --------------------------------------
# Zahtev 6
# healthcheck za database
# --------------------------------------

section "6. PROVERA HEALTHCHECK-A BAZE"

if [ -f "$COMPOSE_FILE" ] \
  && grep -q "healthcheck:" "$COMPOSE_FILE" \
  && grep -q "mysqladmin" "$COMPOSE_FILE" \
  && grep -q "ping" "$COMPOSE_FILE" \
  && grep -q "student" "$COMPOSE_FILE" \
  && grep -q -- "--password=student" "$COMPOSE_FILE" \
  && grep -q "interval: 10s" "$COMPOSE_FILE" \
  && grep -q "timeout: 10s" "$COMPOSE_FILE" \
  && grep -q "retries: 6" "$COMPOSE_FILE"; then
  print_result "6" "OK" "Database servis ima definisan očekivani healthcheck."
else
  print_result "6" "NIJE OK" "Healthcheck za database nije definisan u očekivanom obliku."
fi

# --------------------------------------
# Zahtev 7
# mreža definisana i kreirana
# --------------------------------------

section "7. PROVERA MREŽE"

if [ -f "$COMPOSE_FILE" ] \
  && grep -q "networks:" "$COMPOSE_FILE" \
  && grep -q "$NETWORK" "$COMPOSE_FILE" \
  && grep -Eq "name:[[:space:]]*[\"']?${NETWORK}[\"']?" "$COMPOSE_FILE" \
  && network_exists "$NETWORK"; then
  print_result "7" "OK" "Mreža $NETWORK je eksplicitno definisana u compose.yaml i kreirana u Docker-u."
else
  print_result "7" "NIJE OK" "Mreža nije eksplicitno definisana kroz name: ili nije kreirana."
fi

# --------------------------------------
# Zahtev 8
# imenovani database volume definisan i kreiran
# --------------------------------------

section "8. PROVERA VOLUMENA"

REAL_VOLUME=$(get_existing_volume)

if [ -f "$COMPOSE_FILE" ] \
  && grep -q "volumes:" "$COMPOSE_FILE" \
  && grep -q "$VOLUME_KEY" "$COMPOSE_FILE" \
  && [ -n "$REAL_VOLUME" ]; then
  print_result "8" "OK" "Database volume je definisan i kreiran kao Docker volume: $REAL_VOLUME."
else
  print_result "8" "NIJE OK" "Database volume nije definisan na odgovarajući način ili nije kreiran."
fi

# --------------------------------------
# Zahtev 9
# aplikacija pokrenuta + unos dom3 u bazu
# --------------------------------------

section "9. PROVERA POKRENUTE APLIKACIJE I PODATAKA U BAZI"

DB_HEALTH=$(sudo docker inspect -f '{{.State.Health.Status}}' "$DB_CONT" 2>/dev/null)

API_STATUS=$(curl -s --max-time 5 -o "$API_RESPONSE_FILE" -w "%{http_code}" "http://localhost:5000/projects")
API_COUNT=$(grep -o '"count":[[:space:]]*[0-9]*' "$API_RESPONSE_FILE" 2>/dev/null | head -n 1 | grep -o '[0-9]*')
API_HAS_DOM3=$(grep -i "dom3" "$API_RESPONSE_FILE" 2>/dev/null)

DB_HAS_DOM3=false
if container_exists "$DB_CONT" && container_running "$DB_CONT"; then
  if sudo docker exec "$DB_CONT" mysql -ustudent -pstudent projects_db -e "SELECT * FROM student_projects;" 2>/dev/null | grep -iq "dom3"; then
    DB_HAS_DOM3=true
  fi
fi

if container_exists "$BACK_CONT" \
  && container_exists "$FRONT_CONT" \
  && container_exists "$DB_CONT" \
  && container_running "$BACK_CONT" \
  && container_running "$FRONT_CONT" \
  && container_running "$DB_CONT" \
  && image_exists "$BACK_IMG" \
  && image_exists "$FRONT_IMG" \
  && network_exists "$NETWORK" \
  && container_in_network "$BACK_CONT" "$NETWORK" \
  && container_in_network "$FRONT_CONT" "$NETWORK" \
  && container_in_network "$DB_CONT" "$NETWORK" \
  && port_available "5000" \
  && port_available "7000" \
  && [ "$DB_HEALTH" = "healthy" ] \
  && [ "$API_STATUS" = "200" ] \
  && [ -n "$API_COUNT" ] \
  && [ "$API_COUNT" -gt 0 ] \
  && [ -n "$API_HAS_DOM3" ] \
  && [ "$DB_HAS_DOM3" = true ]; then
  print_result "9" "OK" "Sva tri kontejnera rade, baza je healthy, aplikacija je dostupna na portovima 5000 i 7000, a u bazi/API-ju postoji unos sa vrednošću dom3."
else
  print_result "9" "NIJE OK" "Aplikacija nije kompletno funkcionalna ili nije pronađen unos dom3. API status: ${API_STATUS:-nema}, count: ${API_COUNT:-nema}, DB health: ${DB_HEALTH:-nema}."
fi

# --------------------------------------
# Zahtev 10
# status fajl sa Docker objektima
# --------------------------------------

section "10. PROVERA STATUS FAJLA SA DOCKER OBJEKTIMA"

if [ -f "$STATUS_FILE" ] \
  && grep -q "IMAGES" "$STATUS_FILE" \
  && grep -q "CONTS" "$STATUS_FILE" \
  && grep -q "VOLUMES" "$STATUS_FILE" \
  && grep -q "NETWORKS" "$STATUS_FILE" \
  && grep -q "$BACK_IMG" "$STATUS_FILE" \
  && grep -q "$FRONT_IMG" "$STATUS_FILE" \
  && grep -q "$BACK_CONT" "$STATUS_FILE" \
  && grep -q "$FRONT_CONT" "$STATUS_FILE" \
  && grep -q "$DB_CONT" "$STATUS_FILE" \
  && grep -q "$NETWORK" "$STATUS_FILE"; then
  print_result "10" "OK" "Fajl $STATUS_FILE postoji i sadrži sekcije IMAGES, CONTS, VOLUMES, NETWORKS i očekivane Docker objekte."
else
  print_result "10" "NIJE OK" "Nedostaje $STATUS_FILE ili ne sadrži očekivane sekcije i Docker objekte."
fi

# --------------------------------------
# Dodatni izveštaji
# --------------------------------------

echo "" >> "$REPORT"
echo "======================================" >> "$REPORT"
echo "DODATNI DOCKER STATUS" >> "$REPORT"
echo "======================================" >> "$REPORT"

echo "" >> "$REPORT"
echo "docker compose ps:" >> "$REPORT"
sudo docker compose ps >> "$REPORT" 2>&1

echo "" >> "$REPORT"
echo "docker ps -a:" >> "$REPORT"
sudo docker ps -a >> "$REPORT" 2>&1

echo "" >> "$REPORT"
echo "docker images:" >> "$REPORT"
sudo docker images >> "$REPORT" 2>&1

echo "" >> "$REPORT"
echo "docker volume ls:" >> "$REPORT"
sudo docker volume ls >> "$REPORT" 2>&1

echo "" >> "$REPORT"
echo "docker network ls:" >> "$REPORT"
sudo docker network ls >> "$REPORT" 2>&1

if network_exists "$NETWORK"; then
  echo "" >> "$REPORT"
  echo "docker network inspect $NETWORK:" >> "$REPORT"
  sudo docker network inspect "$NETWORK" >> "$REPORT" 2>&1
fi

if [ -n "$REAL_VOLUME" ]; then
  echo "" >> "$REPORT"
  echo "docker volume inspect $REAL_VOLUME:" >> "$REPORT"
  sudo docker volume inspect "$REAL_VOLUME" >> "$REPORT" 2>&1
fi

if [ -f "$API_RESPONSE_FILE" ]; then
  echo "" >> "$REPORT"
  echo "API odgovor /projects:" >> "$REPORT"
  cat "$API_RESPONSE_FILE" >> "$REPORT"
fi

# --------------------------------------
# Ukupan rezultat
# --------------------------------------

echo ""
echo "======================================"
echo "UKUPNO USPEŠNO ISPUNJENIH ZAHTEVA: $OK_COUNT/$TOTAL_REQUIREMENTS"
echo "======================================"

echo "" >> "$REPORT"
echo "======================================" >> "$REPORT"
echo "UKUPNO USPEŠNO ISPUNJENIH ZAHTEVA: $OK_COUNT/$TOTAL_REQUIREMENTS" >> "$REPORT"
echo "======================================" >> "$REPORT"

echo "" >> "$SUMMARY_FILE"
echo "======================================" >> "$SUMMARY_FILE"
echo "UKUPNO USPEŠNO ISPUNJENIH ZAHTEVA: $OK_COUNT/$TOTAL_REQUIREMENTS" >> "$SUMMARY_FILE"
echo "======================================" >> "$SUMMARY_FILE"

echo ""
echo "Glavni izveštaj: $REPORT"
echo "Sumarna provera: $SUMMARY_FILE"

# --------------------------------------
# ZIP arhiva sa dokazima
# --------------------------------------

ARCHIVE_DIR="dokazi-domaci3-${PREFIX}"
ZIP_FILE="dokazi-domaci3-${PREFIX}.zip"

rm -rf "$ARCHIVE_DIR"
mkdir -p "$ARCHIVE_DIR"

if [ -f "$COMPOSE_FILE" ]; then
  cp "$COMPOSE_FILE" "$ARCHIVE_DIR/"
fi

if [ -f "$REPORT" ]; then
  cp "$REPORT" "$ARCHIVE_DIR/"
fi

if [ -f "$SUMMARY_FILE" ]; then
  cp "$SUMMARY_FILE" "$ARCHIVE_DIR/"
fi

if [ -f "$STATUS_FILE" ]; then
  cp "$STATUS_FILE" "$ARCHIVE_DIR/"
fi

if [ -f "$API_RESPONSE_FILE" ]; then
  cp "$API_RESPONSE_FILE" "$ARCHIVE_DIR/"
fi

if [ -f "$BACKEND_ENV" ]; then
  mkdir -p "$ARCHIVE_DIR/env"
  cp "$BACKEND_ENV" "$ARCHIVE_DIR/env/"
fi

if [ -f "$FRONTEND_ENV" ]; then
  mkdir -p "$ARCHIVE_DIR/env"
  cp "$FRONTEND_ENV" "$ARCHIVE_DIR/env/"
fi


if command -v zip > /dev/null 2>&1; then
  zip -r "$ZIP_FILE" "$ARCHIVE_DIR" > /dev/null
  echo "[OK] Kreirana ZIP arhiva: $ZIP_FILE"
  echo "[OK] Kreirana ZIP arhiva: $ZIP_FILE" >> "$REPORT"
else
  echo "[UPOZORENJE] Komanda zip nije instalirana. Instaliraj je komandom: sudo apt install zip"
  echo "[UPOZORENJE] Komanda zip nije instalirana. Instaliraj je komandom: sudo apt install zip" >> "$REPORT"
fi

echo ""
echo "ZIP arhiva: $ZIP_FILE"
echo "Folder sa dokazima: $ARCHIVE_DIR"