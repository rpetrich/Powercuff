TWEAK_NAME = Powercuff
Powercuff_FILES = Powercuff.x
Powercuff_FRAMEWORKS = Foundation
Powercuff_USE_MODULES = false

IPHONE_ARCHS = arm64 arm64e

TARGET_IPHONEOS_DEPLOYMENT_VERSION = 7.0
TARGET_IPHONEOS_DEPLOYMENT_VERSION_arm64 = 7.0
TARGET_IPHONEOS_DEPLOYMENT_VERSION_arm64e = 8.4

ADDITIONAL_CFLAGS = -std=c99

INSTALL_TARGET_PROCESSES = thermalmonitord SpringBoard

include framework/makefiles/common.mk
include framework/makefiles/tweak.mk