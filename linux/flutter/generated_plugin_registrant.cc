//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_bluetooth_classic_serial/flutter_bluetooth_classic_plugin.h>
#include <flutter_libserialport/flutter_libserialport_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) flutter_bluetooth_classic_serial_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FlutterBluetoothClassicPlugin");
  flutter_bluetooth_classic_plugin_register_with_registrar(flutter_bluetooth_classic_serial_registrar);
  g_autoptr(FlPluginRegistrar) flutter_libserialport_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FlutterLibserialportPlugin");
  flutter_libserialport_plugin_register_with_registrar(flutter_libserialport_registrar);
}
