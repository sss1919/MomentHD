# ==========================================
#  MomentHD — 高清朋友圈 (RootHide/Relaxin Rootless)
#  适配 WeChat 8.0.70
# ==========================================

TARGET := iphone:clang:17.0:15.0
THEOS_PACKAGE_SCHEME = rootless

ARCHS = arm64e

# 只注入微信进程，禁止全局注入
INSTALL_TARGET_PROCESSES = WeChat

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MomentHD

MomentHD_FILES = Tweak.x
MomentHD_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function
MomentHD_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
