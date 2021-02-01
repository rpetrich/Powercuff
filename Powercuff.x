#import <Foundation/Foundation.h>
#import <notify.h>

extern char ***_NSGetArgv(void);

@interface CommonProduct : NSObject
- (void)putDeviceInThermalSimulationMode:(NSString *)simulationMode;
@end

static CommonProduct *currentProduct;
static int token;
static bool isCharging;

#if 0

@implementation NSObject(Powercuff)
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
	CFPropertyListRef powerMode = CFPreferencesCopyValue(CFSTR("PowerMode"), CFSTR("com.rpetrich.powercuff"), kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
	CFPropertyListRef LPMPowerMode = CFPreferencesCopyValue(CFSTR("LPMPowerMode"), CFSTR("com.rpetrich.powercuff"), kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
	CFPropertyListRef disableWhileCharging = CFPreferencesCopyValue(CFSTR("DisableWhileCharging"), CFSTR("com.rpetrich.powercuff"), kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
	uint64_t thermalMode = 0;
	if (powerMode) {
		if ([(id)powerMode isKindOfClass:[NSNumber class]]) {
			if (!isCharging && [(id)disableWhileCharging isKindOfClass:[NSNumber class]] && [(id)disableWhileCharging boolValue]) {
				thermalMode = (uint64_t)[(NSNumber *)powerMode unsignedLongLongValue];
			} else {
				thermalMode = 0;
			}
		}
		CFRelease(powerMode);
	}
	if (LPMPowerMode) {
		if ([(id)LPMPowerMode isKindOfClass:[NSNumber class]]) {
			if ([[%c(_CDBatterySaver) batterySaver] getPowerMode] != 0) {
				if (!isCharging && [(id)disableWhileCharging isKindOfClass:[NSNumber class]] && [(id)disableWhileCharging boolValue]) {
					thermalMode = (uint64_t)[(NSNumber *)LPMPowerMode unsignedLongLongValue];
				} else {
					thermalMode = 0;
				}
			}
		}
		CFRelease(LPMPowerMode);
	}
	notify_set_state(token, thermalMode);
	notify_post("com.rpetrich.powercuff.thermals");
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

%group SBUIController

%hook SBUIController

- (BOOL)isOnAC
{
	isCharging = %orig();
	LoadSettings();

	return isCharging;
}

%end

%end

%ctor
{
	notify_register_check("com.rpetrich.powercuff.thermals", &token);
	char *argv0 = **_NSGetArgv();
    char *path = strrchr(argv0, '/');
    path = path == NULL ? argv0 : path + 1;
	%init(SBUIController);
    if (strcmp(path, "thermalmonitord") == 0) {
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (void *)ApplyThermals, CFSTR("com.rpetrich.powercuff.thermals"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		%init(thermalmonitord);
    } else {
	    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
		CFNotificationCenterAddObserver(center, NULL, (void *)LoadSettings, CFSTR("com.rpetrich.powercuff.settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		LoadSettings();
		%init(SpringBoard);
    }
}
