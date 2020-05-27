#import <Foundation/Foundation.h>
#import <notify.h>
#import <os/log.h>

extern char ***_NSGetArgv(void);

@interface CommonProduct : NSObject
- (void)putDeviceInThermalSimulationMode:(NSString *)simulationMode;
@end

static CommonProduct *currentProduct;
static int token;

#if 0

@implementation NSObject(UltraLowPower)
+ (id)sharedProduct
{
	return currentProduct;
}

+ (uint64_t)thermalMode
{
	uint64_t thermalMode = 0;
	notify_get_state(token, &thermalMode);
	return thermalMode;
}
@end

#endif

static NSString *stringForThermalMode(uint64_t thermalMode) {
	switch (thermalMode) {
		case 1:
			return @"nominal";
		case 2:
			return @"light";
		case 3:
			return @"moderate";
		case 4:
			return @"heavy";
		default:
			return @"off";
	}
}

static void ApplyThermals(void)
{
	uint64_t thermalMode = 0;
	notify_get_state(token, &thermalMode);
	[currentProduct putDeviceInThermalSimulationMode:stringForThermalMode(thermalMode)];
}

%group thermalmonitord

%hook CommonProduct

- (id)initProduct:(id)data
{
	if ((self = %orig())) {
		if ([self respondsToSelector:@selector(putDeviceInThermalSimulationMode:)]) {
			currentProduct = self;
			ApplyThermals();
		}
	}
	return self;
}

- (void)dealloc
{
	if (currentProduct == self) {
		currentProduct = nil;
	}
	%orig();
}

%end

%end

@interface _CDBatterySaver : NSObject
+ (_CDBatterySaver *)batterySaver;
- (NSInteger)getPowerMode;
@end

static void LoadSettings(void)
{
	CFPropertyListRef powerMode = CFPreferencesCopyValue(CFSTR("PowerMode"), CFSTR("com.rpetrich.ultralowpower"), kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
	uint64_t thermalMode = 0;
	if (powerMode) {
		if ([(id)powerMode isKindOfClass:[NSNumber class]]) {
			thermalMode = (uint64_t)[(NSNumber *)powerMode unsignedLongLongValue];
		}
		CFRelease(powerMode);
	}
	CFPropertyListRef requireLowPowerMode = CFPreferencesCopyValue(CFSTR("RequireLowPowerMode"), CFSTR("com.rpetrich.ultralowpower"), kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
	if (requireLowPowerMode && [(id)requireLowPowerMode isKindOfClass:[NSNumber class]] && [(id)requireLowPowerMode boolValue]) {
		if ([[%c(_CDBatterySaver) batterySaver] getPowerMode] == 0) {
			thermalMode = 0;
		}
	}
	notify_set_state(token, thermalMode);
	notify_post("com.rpetrich.ultralowpower.thermals");
}

%group SpringBoard

%hook SpringBoard

- (void)_batterySaverModeChanged:(NSInteger)token
{
	%orig();
	LoadSettings();
}

%end

%end

%ctor
{
	notify_register_check("com.rpetrich.ultralowpower.thermals", &token);
	char *argv0 = **_NSGetArgv();
    char *path = strrchr(argv0, '/');
    path = path == NULL ? argv0 : path + 1;
    os_log(OS_LOG_DEFAULT, "Loading in %{public}s", path);
    if (strcmp(path, "thermalmonitord") == 0) {
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (void *)ApplyThermals, CFSTR("com.rpetrich.ultralowpower.thermals"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		%init(thermalmonitord);
    } else {
	    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
		CFNotificationCenterAddObserver(center, NULL, (void *)LoadSettings, CFSTR("com.rpetrich.ultralowpower.settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		LoadSettings();
		%init(SpringBoard);
    }
}
