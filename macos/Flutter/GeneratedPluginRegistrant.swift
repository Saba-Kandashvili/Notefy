//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import audioplayers_darwin
import device_info_plus
import package_info_plus
import record_darwin
import share_plus
import shared_preferences_foundation
import wakelock_plus

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  AudioplayersDarwinPlugin.register(with: registry.registrar(forPlugin: "AudioplayersDarwinPlugin"))
  DeviceInfoPlusMacosPlugin.register(with: registry.registrar(forPlugin: "DeviceInfoPlusMacosPlugin"))
  FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
  RecordPlugin.register(with: registry.registrar(forPlugin: "RecordPlugin"))
  SharePlusMacosPlugin.register(with: registry.registrar(forPlugin: "SharePlusMacosPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
  WakelockPlusMacosPlugin.register(with: registry.registrar(forPlugin: "WakelockPlusMacosPlugin"))
}
