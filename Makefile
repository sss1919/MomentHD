TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = WeChat

ARCHS = arm64
THEOS_PACKAGE_SCHEME = rootless
DISABLE_ROOTLESS_COMPAT_WARNING = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HDMoments

HDMoments_FILES = Tweak.x
HDMoments_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-unused-function
HDMoments_FRAMEWORKS = UIKit Foundation
HDMoments_PRIVATE_FRAMEWORKS = 

include $(THEOS_MAKE_PATH)/tweak.mk
