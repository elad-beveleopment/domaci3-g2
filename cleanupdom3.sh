#!/bin/bash

PREFIX=$1

if [ -z "$PREFIX" ]; then
  echo "Upotreba: sudo ./cleanupdom3.sh <studentski-prefiks>"
  echo "Primer: sudo ./cleanupdom3.sh pg20220043"
  exit 1
fi

echo "======================================"
echo "CLEANUP DOMAĆI 3 ZA: $PREFIX"
echo "======================================"
echo ""

echo "[UPOZORENJE] Ova skripta briše:"
echo "- sve kontejnere, bez obzira na naziv"
echo "- sve image-e koji sadrže: $PREFIX"
echo "- sve volume-e koji sadrže: $PREFIX"
echo "- sve network-e koji sadrže: $PREFIX"
echo ""

read -p "Da li želiš da nastaviš? (da/ne): " CONFIRM

if [ "$CONFIRM" != "da" ]; then
  echo "Cleanup je otkazan."
  exit 0
fi

echo ""

# --------------------------------------
# 1. Brisanje svih kontejnera
# --------------------------------------

echo "1. BRISANJE SVIH KONTEJNERA"
echo "--------------------------------------"

ALL_CONTAINERS=$(sudo docker ps -aq)

if [ -n "$ALL_CONTAINERS" ]; then
  sudo docker rm -f $ALL_CONTAINERS > /dev/null 2>&1
  echo "[OK] Svi kontejneri su stopirani i obrisani."
else
  echo "[INFO] Nema kontejnera za brisanje."
fi

echo ""

# --------------------------------------
# 2. Brisanje image-a koji sadrže username
# --------------------------------------

echo "2. BRISANJE IMAGE-A KOJI SADRŽE: $PREFIX"
echo "--------------------------------------"

IMAGES=$(sudo docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep "$PREFIX" | awk '{print $2}' | sort -u)

if [ -n "$IMAGES" ]; then
  for IMG in $IMAGES; do
    sudo docker rmi -f "$IMG" > /dev/null 2>&1
    echo "[OK] Obrisan image ID: $IMG"
  done
else
  echo "[INFO] Nema image-a koji sadrže: $PREFIX"
fi

echo ""

# --------------------------------------
# 3. Brisanje volume-a koji sadrže username
# --------------------------------------

echo "3. BRISANJE VOLUME-A KOJI SADRŽE: $PREFIX"
echo "--------------------------------------"

VOLUMES=$(sudo docker volume ls --format "{{.Name}}" | grep "$PREFIX")

if [ -n "$VOLUMES" ]; then
  for VOL in $VOLUMES; do
    sudo docker volume rm -f "$VOL" > /dev/null 2>&1
    echo "[OK] Obrisan volume: $VOL"
  done
else
  echo "[INFO] Nema volume-a koji sadrže: $PREFIX"
fi

echo ""

# --------------------------------------
# 4. Brisanje network-a koji sadrže username
# --------------------------------------

echo "4. BRISANJE NETWORK-A KOJI SADRŽE: $PREFIX"
echo "--------------------------------------"

NETWORKS=$(sudo docker network ls --format "{{.Name}}" | grep "$PREFIX")

if [ -n "$NETWORKS" ]; then
  for NET in $NETWORKS; do
    if [ "$NET" = "bridge" ] || [ "$NET" = "host" ] || [ "$NET" = "none" ]; then
      echo "[SKIP] Sistemska mreža se ne briše: $NET"
    else
      sudo docker network rm "$NET" > /dev/null 2>&1
      echo "[OK] Obrisana mreža: $NET"
    fi
  done
else
  echo "[INFO] Nema mreža koje sadrže: $PREFIX"
fi

echo ""

# --------------------------------------
# 5. Završna provera
# --------------------------------------

echo "5. ZAVRŠNA PROVERA"
echo "--------------------------------------"

echo "Preostali kontejneri:"
sudo docker ps -a

echo ""
echo "Preostali image-i koji sadrže $PREFIX:"
sudo docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}" | grep "$PREFIX" || echo "[INFO] Nema image-a za $PREFIX"

echo ""
echo "Preostali volume-i koji sadrže $PREFIX:"
sudo docker volume ls --format "table {{.Name}}" | grep "$PREFIX" || echo "[INFO] Nema volume-a za $PREFIX"

echo ""
echo "Preostale mreže koje sadrže $PREFIX:"
sudo docker network ls --format "table {{.Name}}\t{{.Driver}}" | grep "$PREFIX" || echo "[INFO] Nema mreža za $PREFIX"

echo ""
echo "======================================"
echo "CLEANUP ZAVRŠEN ZA: $PREFIX"
echo "======================================"