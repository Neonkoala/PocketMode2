include theos/makefiles/common.mk

ADDITIONAL_OBJCFLAGS = -fobjc-arc

BUNDLE_NAME = PocketModePrefs
PocketModePrefs_FILES = PocketModePrefs.mm
PocketModePrefs_INSTALL_PATH = /Library/PreferenceBundles
PocketModePrefs_FRAMEWORKS = UIKit
PocketModePrefs_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/PocketModePrefs.plist$(ECHO_END)
