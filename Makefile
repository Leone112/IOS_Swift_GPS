CODESIGN_ALLOCATE = /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/codesign_allocate
ARCHS = $(ARCHS_STANDARD_32_BIT)
LANG = en_US.US-ASCII
IPHONEOS_DEPLOYMENT_TARGET = 5.1
PATH = "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin:/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin"
CC = /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/clang
GCC = /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/gcc
LD = $(CC)
VERSION = 1.8.1
LDFLAGS = -lobjc \
          -framework CoreFoundation \
          -framework Foundation \
          -framework UIKit \
          -framework QuartzCore \
          -framework CoreGraphics \
          -framework CoreSurface \
          -framework CoreAudio \
          -framework AudioToolbox \
          -framework IOKit \
          -lz \
		  -ObjC \
		  -all_load \
		  -dead_strip \
		  -miphoneos-version-min=4.0 \
		  -arch armv7 \
		  -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.1.sdk \
		  -F/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.1.sdk/System/Library/Frameworks \
		  -F/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.1.sdk/System/Library/PrivateFrameworks

CFLAGS	= -DARM_ARCH -DGP2X_BUILD -x objective-c -arch armv7 -miphoneos-version-min=4.0 -fmessage-length=0 -fdiagnostics-print-source-range-info -fdiagnostics-show-category=id -fdiagnostics-parseable-fixits -Wno-pointer-sign -Wno-trigraphs -fno-pascal-strings -Os -Wreturn-type -Wparentheses -Wno-format -Wswitch -Wno-unused-parameter -Wunused-value -Wno-shorten-64-to-32 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.1.sdk -gdwarf-2 -Wno-sign-conversion -mthumb "-DIBOutlet=__attribute__((iboutlet))" "-DIBOutletCollection(ClassName)=__attribute__((iboutletcollection(ClassName)))" "-DIBAction=void)__attribute__((ibaction)" -miphoneos-version-min=4.0 -msoft-float -funsigned-char -fno-common -fno-builtin -fomit-frame-pointer -fstrict-aliasing -finline -finline-functions -funroll-loops -DVERSION='"$(VERSION)"' -I/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.1.sdk/System/Library/PrivateFrameworks -I/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator5.1.sdk/System/Library/Frameworks -F/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator5.1.sdk/System/Library/Frameworks #look in simulator dir as a cheap way to look for IOKit headers


GCC_CFLAGS= -DARM_ARCH -DGP2X_BUILD -x objective-c -arch armv7 -fnested-functions -fmessage-length=0 -Wno-pointer-sign -Wno-trigraphs -fno-pascal-strings -Os -Wreturn-type -Wparentheses -Wno-format -Wswitch -Wno-unused-parameter -Wunused-value -Wno-shorten-64-to-32 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.1.sdk -gdwarf-2 -mthumb -msoft-float -funsigned-char -fno-common -fno-builtin -fomit-frame-pointer -fstrict-aliasing -finline -finline-functions -funroll-loops -DVERSION='"$(VERSION)"' -I/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.1.sdk/System/Library/PrivateFrameworks -I/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator5.1.sdk/System/Library/Frameworks -F/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator5.1.sdk/System/Library/Frameworks #look in simulator dir as a cheap way to look for IOKit headers

all:	gpSPhone bundle

bundle:
	codesign -f -s "iPhone Developer: Z" -vv gpsPhone
	rm -rf gpsPhone.app; mkdir gpsPhone.app; mv gpsPhone gpsPhone.app

gpSPhone:	iphone/gpSPhone/src/ControlCell.o iphone/gpSPhone/src/JoyPad.o iphone/gpSPhone/src/iphone.o iphone/gpSPhone/src/main.o iphone/gpSPhone/src/gpSPhoneApp.o iphone/gpSPhone/src/ControllerView.o iphone/gpSPhone/src/MainView.o iphone/gpSPhone/src/FileBrowser.o iphone/gpSPhone/src/EmulationView.o iphone/gpSPhone/src/ScreenView.o iphone/gpSPhone/src/gpSPhone_iPhone.o iphone/arm_stub_c.o iphone/font.o iphone/display.o cheats.o zip.o gui.o main.o cpu.o sound.o input.o memory.o video.o iphone/arm_asm_stub.o cpu_threaded.o 
	$(LD) $(LDFLAGS)  iphone/gpSPhone/src/ControlCell.o iphone/gpSPhone/src/JoyPad.o iphone/gpSPhone/src/iphone.o iphone/gpSPhone/src/main.o iphone/gpSPhone/src/gpSPhoneApp.o iphone/gpSPhone/src/ControllerView.o iphone/gpSPhone/src/MainView.o iphone/gpSPhone/src/FileBrowser.o iphone/gpSPhone/src/EmulationView.o iphone/gpSPhone/src/ScreenView.o iphone/gpSPhone/src/gpSPhone_iPhone.o iphone/arm_stub_c.o iphone/font.o iphone/display.o cheats.o zip.o gui.o main.o cpu.o sound.o input.o memory.o video.o iphone/arm_asm_stub.o cpu_threaded.o -o gpsPhone

%.o:	%.m
	$(CC) ${CFLAGS} -std=gnu99 -c $< -o $@

%.o:	%.c
	$(GCC) ${GCC_CFLAGS} -std=gnu89 -c $< -o $@

%.o:	%.S
	$(CC) -v -arch armv7 -c $< -o $@

#%.z:	%.c
#	$(CC) ${CFLAGS} -S $< -o $@

clean:
	rm -f ./*.o iphone/*.o iphone/gpSPhone/*.o iphone/gpSPhone/src/*.o gpSPhone src/*.gch
	rm -rf ./build
	rm -rf gpsPhone.app
