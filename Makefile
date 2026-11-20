DEBUG = 0
FINALPACKAGE = 1

ARCHS = arm64 arm64e

# Share the SDK and deployment targets with the PreferenceBundle.
include YuFullScreenTranslateBuild.mk
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YuFullScreenTranslate
YuFullScreenTranslate_FILES = $(wildcard Hooks/*.xm Sources/*.m)
YuFullScreenTranslate_CFLAGS = -fobjc-arc -I./Headers -I./Sources
YuFullScreenTranslate_FRAMEWORKS = UIKit Foundation CoreFoundation
YuFullScreenTranslate_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += YuFullScreenTranslatePrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
