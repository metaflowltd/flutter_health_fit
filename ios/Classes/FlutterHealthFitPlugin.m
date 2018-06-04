#import "FlutterHealthFitPlugin.h"
#import <flutter_health_fit/flutter_health_fit-Swift.h>

@implementation FlutterHealthFitPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterHealthFitPlugin registerWithRegistrar:registrar];
}
@end
