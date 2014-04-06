include theos/makefiles/common.mk

export TARGET = iphone::7.0
export ARCHS = armv7 armv7s arm64
export THEOS_DEVICE_IP = 192.168.0.6

TWEAK_NAME = PocketMode
PocketMode_FILES = Tweak.xm PocketMode.m
PocketMode_FRAMEWORKS = IOKit
PocketMode_PRIVATE_FRAMEWORKS = Celestial
PocketMode_CFLAGS = "-Iiphoneheaders"

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
