include theos/makefiles/common.mk

export TARGET = iphone::7.0
export ARCHS = armv7 armv7s arm64
export THEOS_DEVICE_IP = 192.168.0.6
ADDITIONAL_OBJCFLAGS = -fobjc-arc

TWEAK_NAME = PocketMode
PocketMode_FILES = Tweak.xm PocketMode.m
PocketMode_FRAMEWORKS = IOKit UIKit
PocketMode_PRIVATE_FRAMEWORKS = BulletinBoard Celestial
#PocketMode_CFLAGS = -DDEBUG

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"

SUBPROJECTS += pocketmodeprefs
SUBPROJECTS += pocketmodeswitch
include $(THEOS_MAKE_PATH)/aggregate.mk
