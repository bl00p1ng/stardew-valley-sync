#!/bin/bash

# Stardew Valley Sync Script
# Sincroniza el progreso del juego entre Android y macOS usando ADB (USB o inalámbrico)

set -euo pipefail

# Configuración de directorios
MACOS_SAVE_DIR="${HOME}/.config/StardewValley/Saves"
ANDROID_SAVE_DIR="/storage/emulated/0/Android/data/com.chucklefish.stardewvalley/files/Saves"
TEMP_DIR="/tmp/stardew_valley_sync"

# Archivo a ignorar
IGNORE_FILE="steam_autocloud.vdf"

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

# Función para elegir el método de conexión
choose_connection_method() {
    echo "Elige el método de conexión:"
    echo "1) USB"
    echo "2) Inalámbrico (ADB over Wi-Fi)"
    read -p "Ingresa tu elección (1 o 2): " choice

    case $choice in
        1) connect_usb ;;
        2) connect_wireless ;;
        *) log "Opción inválida. Saliendo."; exit 1 ;;
    esac
}

# Función para conexión USB
connect_usb() {
    log "Verificando conexión ADB por USB..."
    if ! adb get-state &> /dev/null; then
        log "Error: No se detectó ningún dispositivo Android conectado por USB."
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
    log "Dispositivo Android detectado correctamente por USB."
}

# Función para conexión inalámbrica
connect_wireless() {
    log "Configurando conexión ADB inalámbrica..."
    read -p "Ingresa la dirección IP y puerto del dispositivo (ejemplo: 192.168.1.100:37000): " ip_port
    read -p "Ingresa el código de emparejamiento mostrado en tu dispositivo Android: " pairing_code

    if ! adb pair $ip_port $pairing_code; then
        log "Error: No se pudo emparejar con el dispositivo. Verifica la IP, puerto y código de emparejamiento."
        exit 1
    fi

    ip=$(echo $ip_port | cut -d':' -f1)
    if ! adb connect $ip; then
        log "Error: No se pudo conectar al dispositivo después del emparejamiento."
        exit 1
    fi

    log "Conexión inalámbrica establecida correctamente."
}

# Función para verificar y crear directorios si no existen
create_directories() {
    mkdir -p "$MACOS_SAVE_DIR" "$TEMP_DIR"
    if ! adb shell "[ -d $ANDROID_SAVE_DIR ]"; then
        log "El directorio de guardado en Android no existe. Creándolo..."
        adb shell "mkdir -p $ANDROID_SAVE_DIR"
    fi
}

# Función para obtener la fecha de modificación de un archivo
get_mod_time() {
    local file=$1
    if [[ $file == /* ]]; then
        # Archivo local
        stat -f "%m" "$file" 2>/dev/null || echo 0
    else
        # Archivo en Android
        adb shell "stat -c %Y $file 2>/dev/null || echo 0"
    fi
}

# Función para sincronizar una granja específica
sync_farm() {
    local farm_name=$1
    local android_farm_path="$ANDROID_SAVE_DIR/$farm_name"
    local macos_farm_path="$MACOS_SAVE_DIR/$farm_name"
    local temp_android_path="$TEMP_DIR/android/$farm_name"
    local temp_macos_path="$TEMP_DIR/macos/$farm_name"

    # Ignorar si es el archivo steam_autocloud.vdf
    if [[ "$farm_name" == "$IGNORE_FILE" ]]; then
        log "Ignorando archivo $IGNORE_FILE"
        return
    fi

    # Crear directorios temporales
    mkdir -p "$temp_android_path" "$temp_macos_path"

    # Verificar si la granja existe en Android
    if adb shell "[ -d $android_farm_path ]"; then
        log "Copiando granja $farm_name desde Android..."
        adb pull "$android_farm_path" "$temp_android_path"
        # Mover los archivos un nivel arriba si se creó un subdirectorio
        if [ -d "$temp_android_path/$farm_name" ]; then
            mv "$temp_android_path/$farm_name"/* "$temp_android_path/"
            rmdir "$temp_android_path/$farm_name"
        fi
    else
        log "La granja $farm_name no existe en Android."
    fi

    # Verificar si la granja existe en macOS
    if [ -d "$macos_farm_path" ]; then
        log "Copiando granja $farm_name desde macOS..."
        rsync -a --exclude="$IGNORE_FILE" "$macos_farm_path/" "$temp_macos_path/"
    else
        log "La granja $farm_name no existe en macOS."
    fi

    # Comparar fechas de modificación
    local android_time=$(get_mod_time "$temp_android_path/$(ls -t "$temp_android_path" 2>/dev/null | head -1)")
    local macos_time=$(get_mod_time "$temp_macos_path/$(ls -t "$temp_macos_path" 2>/dev/null | head -1)")

    if [[ $android_time -gt $macos_time ]]; then
        log "La versión de Android es más reciente. Actualizando macOS..."
        rsync -a --delete --exclude="$IGNORE_FILE" "$temp_android_path/" "$macos_farm_path/"
    elif [[ $macos_time -gt $android_time ]]; then
        log "La versión de macOS es más reciente. Actualizando Android..."
        adb push "$temp_macos_path" "$android_farm_path"
        # Asegurar permisos correctos en Android
        adb shell "chmod -R 755 $android_farm_path"
    elif [[ $android_time -eq 0 && $macos_time -eq 0 ]]; then
        log "La granja $farm_name no existe en ninguna plataforma. Saltando..."
    else
        log "Ambas versiones están sincronizadas para la granja $farm_name."
    fi

    # Limpiar directorios temporales
    rm -rf "$temp_android_path" "$temp_macos_path"
}

# Función para obtener la lista de granjas
get_farms_list() {
    local android_farms=$(adb shell "ls $ANDROID_SAVE_DIR 2>/dev/null" | tr -d '\r')
    local macos_farms=$(ls "$MACOS_SAVE_DIR" 2>/dev/null)
    echo "$android_farms $macos_farms" | tr ' ' '\n' | sort | uniq | grep -v "$IGNORE_FILE"
}

# Función principal
main() {
    log "Iniciando sincronización de Stardew Valley entre Android y macOS..."

    check_dependencies
    choose_connection_method
    create_directories

    # Obtener lista de todas las granjas
    all_farms=$(get_farms_list)

    if [ -z "$all_farms" ]; then
        log "No se encontraron granjas para sincronizar."
        exit 0
    fi

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