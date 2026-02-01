#!/bin/bash

# Variables
CACHE_FOLDER=/tmp
DOWNLOAD_DIR=${CACHE_FOLDER}/Libreoffice
LIBREOFFICE_URL="https://download.documentfoundation.org/libreoffice/stable/"
VERSION=$(wget -qO- $LIBREOFFICE_URL | grep -oP '[0-9]+(\.[0-9]+)+' | sort -V | tail -1)
if [ -z "$VERSION" ] ; then
	echo Can\'t connect to documentfoundation.org, aborting
	exit 22
fi
VERSION_INSTALLED=$(/usr/local/bin/libreoffice* --version 2>/dev/null | awk '{print $2}' )

#sudo find $DOWNLOAD_DIR -type f -name "*.tar.gz" -exec rm {} \; >/dev/null 2>&1
 sudo find $DOWNLOAD_DIR -type f -name "*.deb"    -exec rm {} \; >/dev/null 2>&1
#sudo rm -rf $DOWNLOAD_DIR >/dev/null 2>&1

# Detectar el idioma del sistema
LANGUAGE=$(echo $LANG | cut -d'_' -f1)

# Mensajes en español e inglés
if [ "$LANGUAGE" == "es" ]; then
        LO_LANG=es
        MSG_INSTALLED="LibreOffice está instalado. ---------------------------"
           MSG_PROMPT="¿Quieres eliminar LibreOffice? (s/n): "
         MSG_REMOVING="Eliminando LibreOffice. -------------------------------"
          MSG_REMOVED="LibreOffice ha sido eliminado. ------------------------"
      MSG_NOT_REMOVED="No se ha eliminado LibreOffice. -----------------------"
    MSG_NOT_INSTALLED="LibreOffice no está instalado. ------------------------"
         MSG_SAME_VER="No es necesario actualizar. Esta actualizado. ---------"
          MSG_UPGRADE="Es necesario actualizar. ------------------------------"
       ACCEPTED_REGEX="^[Ss]$"
      MSG_DOWNLOADING="Descargando LibreOffice. ------------------------------"
    MSG_UNCOMPRESSING="Descomprimiendo los archivos tar. ---------------------"
       MSG_INSTALLING="Instalando LibreOffice y sus paquetes de lenguaje. ----"
          MSG_OPENING="Abriendo todas las aplicaciones para probarlas. -------"
             MSG_DONE="Se finalizó la instalación de Libreoffice $VERSION"
else
        if [ "$LANGUAGE" == "de" ] || [ "$LANGUAGE" == "fr" ] || [ "$LANGUAGE" == "ja" ] || [ "$LANGUAGE" == "pl" ] \
        || [ "$LANGUAGE" == "ru" ] || [ "$LANGUAGE" == "ro" ] || [ "$LANGUAGE" == "it" ] || [ "$LANGUAGE" == "ko" ] \
        || [ "$LANGUAGE" == "gl" ]      ; then
                LO_LANG=$LANGUAGE
        elif [ "$LANGUAGE" == "en" ] ; then
                LO_LANG=""
        else
                LANG_LIST=$(wget -qO- ${LIBREOFFICE_URL}${VERSION}/deb/x86_64/ | grep -oP 'langpack_\K[^.]+(?=\.tar\.gz<)')
                OPTIONS=()
                for LANG in $LANG_LIST; do
                    OPTIONS+=("$LANG" "$LANG")
                done
                LO_LANG=$(whiptail --title "Select your language" --menu "Use the arrows and enter to select:" 20 60 10 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)
        fi
        MSG_INSTALLED="LibreOffice is installed. -----------------------------"
           MSG_PROMPT="Do you want to remove LibreOffice? (y/n): "
         MSG_REMOVING="Removing LibreOffice. ---------------------------------"
          MSG_REMOVED="LibreOffice has been removed. -------------------------"
      MSG_NOT_REMOVED="LibreOffice was not removed. --------------------------"
    MSG_NOT_INSTALLED="LibreOffice is not installed. -------------------------"
         MSG_SAME_VER="Upgrade is not needed. It is up to date. --------------"
          MSG_UPGRADE="Upgrade is needed. ------------------------------------"
       ACCEPTED_REGEX="^[Yy]$"
      MSG_DOWNLOADING="Downloading LibreOffice. ------------------------------"
    MSG_UNCOMPRESSING="Uncompressing tar files. ------------------------------"
       MSG_INSTALLING="Installing LibreOffice and its language pack. ---------"
          MSG_OPENING="Opening all applications to test. ---------------------"
             MSG_DONE="Installation done. Libreoffice $VERSION "
fi

# TODO remove this line
export LC_ALL=C LANGUAGE=C LANG=C

# Verificar si LibreOffice está instalado
if dpkg -l | grep -q libreoffice ; then
    echo "$MSG_INSTALLED"
    dpkg -l | grep libreoffice
    echo $VERSION_INSTALLED | grep $VERSION >/dev/null
    if [ "$?" == "0" ] ; then
        echo WEB "$VERSION" LOCAL "$VERSION_INSTALLED"
        echo "$MSG_SAME_VER"
        exit
    else
        echo WEB "$VERSION" LOCAL "$VERSION_INSTALLED"
        echo "$MSG_UPGRADE"
    fi
    read -p "$MSG_PROMPT" respuesta
    if [[ "$respuesta" =~ $ACCEPTED_REGEX ]]; then
        echo "$MSG_REMOVING"
        sudo apt-get remove --purge -y $(dpkg -l | awk '{print $2}' | grep ^libreoffice) >/dev/null
        sudo apt-get autoremove -y >/dev/null
        sudo apt-get clean >/dev/null 2>&1
        echo "$MSG_REMOVED"
    else
        echo "$MSG_NOT_REMOVED"
    fi
else
    echo "$MSG_NOT_INSTALLED"
fi

echo "$MSG_DOWNLOADING"
sudo apt install aria2 -y &>/dev/null
mkdir -p $DOWNLOAD_DIR >/dev/null 2>&1

cat << EOF > /tmp/downloads.list
${LIBREOFFICE_URL}${VERSION}/deb/x86_64/LibreOffice_${VERSION}_Linux_x86-64_deb.tar.gz
  dir=${DOWNLOAD_DIR}
  out=LibreOffice_${VERSION}_Linux_x86-64_deb.tar.gz
EOF

if [ ! -z "$LO_LANG" ] ; then
cat << EOF >> /tmp/downloads.list
${LIBREOFFICE_URL}${VERSION}/deb/x86_64/LibreOffice_${VERSION}_Linux_x86-64_deb_langpack_$LO_LANG.tar.gz
  dir=${DOWNLOAD_DIR}
  out=LibreOffice_${VERSION}_Linux_x86-64_deb_langpack_$LO_LANG.tar.gz
${LIBREOFFICE_URL}${VERSION}/deb/x86_64/LibreOffice_${VERSION}_Linux_x86-64_deb_helppack_$LO_LANG.tar.gz 
  dir=${DOWNLOAD_DIR}
  out=LibreOffice_${VERSION}_Linux_x86-64_deb_helppack_$LO_LANG.tar.gz 
EOF
fi
time aria2c \
-i /tmp/downloads.list \
-j 5 \
-x 4 \
-c \
--allow-overwrite=true \
--auto-file-renaming=false \
--truncate-console-readout=true \
--console-log-level=warn \
--download-result=hide \
--summary-interval=0

echo "$MSG_UNCOMPRESSING"
        sudo tar -xzf $DOWNLOAD_DIR/LibreOffice_${VERSION}_Linux_x86-64_deb.tar.gz -C $DOWNLOAD_DIR
        if [ ! -z "$LO_LANG" ] ; then
                sudo tar -xzf $DOWNLOAD_DIR/LibreOffice_${VERSION}_Linux_x86-64_deb_langpack_$LO_LANG.tar.gz -C $DOWNLOAD_DIR
                sudo tar -xzf $DOWNLOAD_DIR/LibreOffice_${VERSION}_Linux_x86-64_deb_helppack_$LO_LANG.tar.gz -C $DOWNLOAD_DIR
        fi

echo "$MSG_INSTALLING"
        time sudo dpkg -i $(find $DOWNLOAD_DIR/ -type f -name \*.deb) >/dev/null 2>&1
        sudo apt install --fix-broken -y >/dev/null 2>&1

echo "$MSG_DONE"
        dpkg -l | grep libreoffice
