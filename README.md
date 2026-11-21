# BrownieNote

App de notas y tareas hecha con Flutter. Todo se guarda en tu dispositivo: no necesitas cuenta ni conexión.

## Funciones

- Cuadernos, con conjuntos de notas dentro de cada uno.
- Notas por bloques (texto, listas, títulos, bloques plegables).
- Tareas con fecha, hora y prioridad, y una vista de próximas tareas.
- Calendario con las notas y tareas de cada día.

## Instalar en tu computadora (Windows)

1. Instala [Flutter](https://docs.flutter.dev/get-started/install) y sigue la guía de Windows para tener Visual Studio con C++.
2. Clona el repo y entra a la app:
   ```
   git clone https://github.com/oscarrdel/BrownieNote.git
   cd BrownieNote/browninote
   flutter pub get
   ```
3. Genera la versión de escritorio:
   ```
   flutter build windows --release
   ```
   El ejecutable queda en `browninote\build\windows\x64\runner\Release\`.

## Instalar en Android

```
cd browninote
flutter build apk --release
```

El APK queda en `browninote\build\app\outputs\flutter-apk\app-release.apk`. Pásalo a tu teléfono e instálalo.

## Desarrollo

```
cd browninote
flutter run
flutter test
```

## Licencia

GPL-3.0. Consulta el archivo [LICENSE](LICENSE).
