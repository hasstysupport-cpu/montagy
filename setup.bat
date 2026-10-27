@echo off
REM Montagy setup - run ONCE inside the project folder (needs Flutter SDK in PATH)
echo == 1/3 flutter create ==
flutter create . --org com.montagy --project-name montagy --platforms android,ios

echo == 2/3 applying Montagy android patch ==
copy /Y android_patch\AndroidManifest.xml android\app\src\main\AndroidManifest.xml
copy /Y android_patch\app_build.gradle android\app\build.gradle
if not exist android\app\src\main\res\xml mkdir android\app\src\main\res\xml
copy /Y android_patch\file_paths.xml android\app\src\main\res\xml\file_paths.xml

echo == 3/3 pub get ==
flutter pub get

echo.
echo Setup complete! Run: flutter run
pause
