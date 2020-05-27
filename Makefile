TWEAK_NAME = UltraLowPower
UltraLowPower_FILES = UltraLowPower.x
UltraLowPower_FRAMEWORKS = Foundation
UltraLowPower_USE_MODULES = false

IPHONE_ARCHS = arm64 arm64e

TARGET_IPHONEOS_DEPLOYMENT_VERSION = 7.0
TARGET_IPHONEOS_DEPLOYMENT_VERSION_arm64 = 7.0
TARGET_IPHONEOS_DEPLOYMENT_VERSION_arm64e = 8.4

ADDITIONAL_CFLAGS = -std=c99

INSTALL_TARGET_PROCESSES = thermalmonitord SpringBoard

include framework/makefiles/common.mk
include framework/makefiles/tweak.mk
