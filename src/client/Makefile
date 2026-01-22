ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

THEOS_PACKAGE_SCHEME = rootless
THEOS_BUILD_DIR = .theos

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = QuangClient

QuangClient_FILES = \
    QuangServer.mm \
    api/LDVQuang.mm

QuangClient_CFLAGS = -fobjc-arc
QuangClient_CCFLAGS = -std=c++17
QuangClient_INSTALL_PATH = /usr/lib

include $(THEOS_MAKE_PATH)/tweak.mk
