# Stardew Valley Sync

## Descripción

Este script de bash permite a los usuarios sincronizar sus granjas de Stardew Valley entre dispositivos Android y macOS. Utiliza ADB (Android Debug Bridge) para la comunicación con dispositivos Android y es compatible tanto con conexiones USB como inalámbricas.

**Probado en macOS Sonoma**. El script puede funcionar también en sistemas Linux, pero puede requerir ajustar el path de los archivos de guardado del juego en la variable `GAME_SAVE_DIR`. Puedes revisar la [Wiki de Stardew Valley](https://stardewvalleywiki.com/Saves#Linux) para saber donde se ubican los archivos de guardado en Linux.

## Características

- Sincronización bidireccional entre Android y macOS
- Soporte para múltiples granjas
- Opción de conexión USB o inalámbrica
- Manejo de conflictos basado en la fecha de modificación de los archivos

## Requisitos

- [ADB](https://developer.android.com/tools/releases/platform-tools#downloads) (Android Debug Bridge).
- rsync (preinstalado en macOS y en varias distribuciones Linux)
- Depuración USB activada en el dispositivo Android.
- Depuración inalámbrica activada en el dispositivo Android (si se quieren sincronizar los archivos de forma inalámbrica).

## Instalación

1. Clone este repositorio o descargue el script `stardew_valley_sync.sh`.
2. Asegúrese de que ADB esté instalado en su sistema. Si no lo está, puede instalarlo con Homebrew en el caso de macOS o revisar la [documentación para su instalación en sistemas Linux](https://developer.android.com/tools/releases/platform-tools#downloads) :
   ```
   brew install android-platform-tools
   ```
3. Asegúrese de que rsync esté instalado en su sistema macOS. Viene preinstalado en la mayoría de las versiones de macOS y Linux.

## Uso

1. Abra una terminal y navegue hasta el directorio donde se encuentra el script.
2. Otorgue permisos de ejecución al script:
   ```
   chmod +x stardew_valley_sync.sh
   ```
3. Ejecute el script:
   ```
   ./stardew_valley_sync.sh
   ```
4. Siga las instrucciones en pantalla para elegir el método de conexión (USB o inalámbrico).
5. Si elige la conexión inalámbrica, asegúrese de que su dispositivo Android esté en la misma red Wi-Fi que su Mac y tenga la depuración inalámbrica activada.

## Configuración en Android

Para usar este script, necesita activar la depuración USB en su dispositivo Android:

1. Vaya a "Configuración" > "Acerca del teléfono" y toque "Número de compilación" 7 veces para habilitar las opciones de desarrollador.
2. Vuelva a la configuración principal y vaya a "Opciones de desarrollador".
3. Active "Depuración USB".
4. Para la depuración inalámbrica, active también "Depuración inalámbrica" en las opciones de desarrollador.

## Estructura de directorios

El script espera la siguiente estructura de directorios:

- En macOS: `~/.config/StardewValley/Saves`
- En Android: `/storage/emulated/0/Android/data/com.chucklefish.stardewvalley/files/Saves`

De ser diferente la estructura de directorios, puede configurarla ajustado el valor de las variables `GAME_SAVE_DIR` y `ANDROID_SAVE_DIR` en el script.

## Notas importantes

- El script ignora el archivo `steam_autocloud.vdf` para evitar conflictos con la sincronización de Steam.
- Asegúrese de tener copias de seguridad de sus granjas antes de usar este script por primera vez.
- La sincronización se basa en las fechas de modificación de los archivos. La versión más reciente sobrescribirá la más antigua.

## Solución de problemas

Si encuentra problemas con la conexión ADB:

1. Asegúrese de que su dispositivo Android esté correctamente conectado y que la depuración USB esté activada.
2. Para la conexión inalámbrica, verifique que ambos dispositivos estén en la misma red Wi-Fi.
3. Intente reiniciar el servidor ADB en su Mac:
   ```
   adb kill-server
   adb start-server
   ```

## Contribuciones

Las contribuciones a este proyecto son bienvenidas. Por favor, abra un issue para discutir cambios mayores antes de enviar un pull request.

## Licencia

Este proyecto está licenciado bajo la Licencia MIT. Consulte el archivo LICENSE para más detalles.