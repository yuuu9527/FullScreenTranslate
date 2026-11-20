include ../YuFullScreenTranslateBuild.mk
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = YuFullScreenTranslatePrefs
YuFullScreenTranslatePrefs_FILES = $(wildcard *.m)
YuFullScreenTranslatePrefs_CFLAGS = -fobjc-arc -I../Sources
YuFullScreenTranslatePrefs_FRAMEWORKS = UIKit Foundation CoreFoundation
YuFullScreenTranslatePrefs_PRIVATE_FRAMEWORKS = Preferences
YuFullScreenTranslatePrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
