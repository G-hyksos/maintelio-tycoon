#!/usr/bin/env python3
"""Configure les dossiers android/ et ios/ générés par `flutter create`.

Idempotent : peut être relancé sans dupliquer les modifications.
- Android : nom affiché, mode portrait, désucrage Java (notifications),
  récepteurs de notifications planifiées, signature release via key.properties.
- iOS : nom affiché, portrait uniquement, plein écran sur iPad.
"""
import pathlib
import plistlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP_NAME = "Maintelio Tycoon"

RECEIVERS = """        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""

SIGNING_HEADER = """import java.io.FileInputStream
import java.util.Properties

"""

SIGNING_PROPERTIES = """val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {"""

SIGNING_CONFIG = """    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {"""


def fail(message: str) -> None:
    print(f"patch_platforms: {message}", file=sys.stderr)
    sys.exit(1)


def replace_once(text: str, old: str, new: str, what: str) -> str:
    if old not in text:
        fail(f"motif introuvable ({what})")
    return text.replace(old, new, 1)


def patch_gradle() -> None:
    path = ROOT / "android" / "app" / "build.gradle.kts"
    if not path.exists():
        fail(f"{path} absent : lancez d'abord `flutter create`")
    text = path.read_text(encoding="utf-8")

    if "isCoreLibraryDesugaringEnabled" not in text:
        text = replace_once(
            text,
            "compileOptions {",
            "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
            "compileOptions",
        )
    if "desugar_jdk_libs" not in text:
        text += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'

    if "key.properties" not in text:
        text = SIGNING_HEADER + text
        text = replace_once(text, "android {", SIGNING_PROPERTIES, "bloc android")
        text = replace_once(text, "    buildTypes {", SIGNING_CONFIG, "buildTypes")
        text = replace_once(
            text,
            'signingConfig = signingConfigs.getByName("debug")',
            'signingConfig = if (keystorePropertiesFile.exists()) '
            'signingConfigs.getByName("release") else signingConfigs.getByName("debug")',
            "signingConfig",
        )
    path.write_text(text, encoding="utf-8")
    print("Android : build.gradle.kts configuré")


def patch_manifest() -> None:
    path = ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if not path.exists():
        fail(f"{path} absent")
    text = path.read_text(encoding="utf-8")

    text = re.sub(r'android:label="[^"]*"', f'android:label="{APP_NAME}"', text, count=1)
    if "RECEIVE_BOOT_COMPLETED" not in text:
        text = re.sub(
            r"(<manifest[^>]*>)",
            r'\1\n    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>',
            text,
            count=1,
        )
    if "android:screenOrientation" not in text:
        text = replace_once(
            text,
            'android:name=".MainActivity"',
            'android:name=".MainActivity"\n            android:screenOrientation="portrait"',
            "MainActivity",
        )
    if "ScheduledNotificationReceiver" not in text:
        text = replace_once(text, "    </application>", RECEIVERS + "    </application>", "</application>")
    path.write_text(text, encoding="utf-8")
    print("Android : AndroidManifest.xml configuré")


def patch_info_plist() -> None:
    path = ROOT / "ios" / "Runner" / "Info.plist"
    if not path.exists():
        fail(f"{path} absent")
    with path.open("rb") as handle:
        info = plistlib.load(handle)
    info["CFBundleDisplayName"] = APP_NAME
    info["UISupportedInterfaceOrientations"] = ["UIInterfaceOrientationPortrait"]
    info["UISupportedInterfaceOrientations~ipad"] = [
        "UIInterfaceOrientationPortrait",
        "UIInterfaceOrientationPortraitUpsideDown",
    ]
    info["UIRequiresFullScreen"] = True
    info["ITSAppUsesNonExemptEncryption"] = False
    with path.open("wb") as handle:
        plistlib.dump(info, handle)
    print("iOS : Info.plist configuré")


if __name__ == "__main__":
    patch_gradle()
    patch_manifest()
    patch_info_plist()
