#!/bin/bash

# Stardew Valley Sync Script
# Sincroniza el progreso del juego entre Android y macOS usando ADB

set -euo pipefail

# Configuración de directorios
MACOS_SAVE_DIR="${HOME}/.config/StardewValley/Saves"
ANDROID_SAVE_DIR="/storage/emulated/0/Android/data/com.chucklefish.stardewvalley/files/Saves"
TEMP_DIR="/tmp/stardew_valley_sync"

# Función para registrar mensajes
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Función para verificar la existencia de comandos necesarios
check_dependencies() {
    local deps=("adb" "rsync")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log "Error: $dep no está instalado. Por favor, instálalo e intenta de nuevo."
            exit 1
        fi
    done
}

# Función para verificar la conexión ADB
check_adb_connection() {
    log "Verificando conexión ADB..."
    adb devices
    if ! adb get-state &> /dev/null; then
        log "Error: No se detectó ningún dispositivo Android conectado."
        log "Salida de 'adb devices':"
        adb devices -l
        log "Intentando reiniciar el servidor ADB..."
        adb kill-server
        adb start-server
        log "Nuevo intento de conexión después de reiniciar el servidor:"
        adb devices -l
        if ! adb get-state &> /dev/null; then
            log "Por favor, asegúrate de que tu dispositivo esté conectado y que la depuración USB esté activada."
            log "Estado de ADB:"
            adb get-state
            exit 1
        fi
    fi
    log "Dispositivo Android detectado correctamente."
}

# Función para crear directorios si no existen
create_directories() {
    mkdir -p "$MACOS_SAVE_DIR" "$TEMP_DIR"
    adb shell "mkdir -p $ANDROID_SAVE_DIR"
}

# Función para obtener la fecha de modificación de un archivo
get_mod_time() {
    local file=$1
    if [[ $file == /* ]]; then
        # Archivo local
        stat -f "%m" "$file"
    else
        # Archivo en Android
        adb shell "stat -c %Y $file"
    fi
}

# Función para sincronizar una granja específica
sync_farm() {
    local farm_name=$1
    local android_farm_path="$ANDROID_SAVE_DIR/$farm_name"
    local macos_farm_path="$MACOS_SAVE_DIR/$farm_name"
    local temp_android_path="$TEMP_DIR/android/$farm_name"
    local temp_macos_path="$TEMP_DIR/macos/$farm_name"

    # Crear directorios temporales
    mkdir -p "$temp_android_path" "$temp_macos_path"

    # Copiar archivos de Android a directorio temporal
    adb pull "$android_farm_path" "$temp_android_path"

    # Copiar archivos de macOS a directorio temporal
    rsync -a "$macos_farm_path/" "$temp_macos_path/"

    # Comparar fechas de modificación
    local android_time=$(get_mod_time "$temp_android_path/$(ls -t "$temp_android_path" | head -1)")
    local macos_time=$(get_mod_time "$temp_macos_path/$(ls -t "$temp_macos_path" | head -1)")

    if [[ $android_time -gt $macos_time ]]; then
        log "La versión de Android es más reciente. Actualizando macOS..."
        rsync -a --delete "$temp_android_path/" "$macos_farm_path/"
    elif [[ $macos_time -gt $android_time ]]; then
        log "La versión de macOS es más reciente. Actualizando Android..."
        adb push "$temp_macos_path" "$android_farm_path"
        # Asegurar permisos correctos en Android
        adb shell "chmod -R 755 $android_farm_path"
    else
        log "Ambas versiones están sincronizadas para la granja $farm_name."
    fi

    # Limpiar directorios temporales
    rm -rf "$temp_android_path" "$temp_macos_path"
}

# Función principal
main() {
    log "Iniciando sincronización de Stardew Valley entre Android y macOS..."

    check_dependencies
    check_adb_connection
    create_directories

    # Obtener lista de granjas en Android
    android_farms=$(adb shell "ls $ANDROID_SAVE_DIR")
    
    # Obtener lista de granjas en macOS
    macos_farms=$(ls "$MACOS_SAVE_DIR")

    # Combinar y eliminar duplicados
    all_farms=$(echo "$android_farms $macos_farms" | tr ' ' '\n' | sort | uniq)

    # Sincronizar cada granja
    for farm in $all_farms; do
        log "Sincronizando granja: $farm"
        sync_farm "$farm"
    done

    log "Sincronización completada."
}

# Ejecutar la función principal
main

exit 0