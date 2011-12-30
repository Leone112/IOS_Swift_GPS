LANG = en_US.US-ASCII
PATH = "/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin:/Developer/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin"
CC = /Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/clang
LD = $(CC)
VERSION = 1.8.0
LDFLAGS = -lobjc \
          -framework CoreFoundation \
          -framework Foundation \
          -framework UIKit \
          -framework LayerKit \
          -framework CoreGraphics \
          -framework GraphicsServices \
          -framework CoreSurface \
          -framework CoreAudio \
          -framework Celestial \
          -framework AudioToolbox \
          -framework IOKit \
          -lz

#CFLAGS = -DDEBUG -O2 -Wall -funroll-loops -DVERSION='"$(VERSION)"'
CFLAGS	= -DARM_ARCH -DGP2X_BUILD -x objective-c -arch armv7 -fmessage-length=0 -fdiagnostics-print-source-range-info -fdiagnostics-show-category=id -fdiagnostics-parseable-fixits -std=gnu99 -Wno-trigraphs -fno-pascal-strings -Os -Wreturn-type -Wparentheses -Wswitch -Wno-unused-parameter -Wunused-variable -Wunused-value -Wno-shorten-64-to-32 -isysroot /Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk -gdwarf-2 -Wno-sign-conversion -mthumb "-DIBOutlet=__attribute__((iboutlet))" "-DIBOutletCollection(ClassName)=__attribute__((iboutletcollection(ClassName)))" "-DIBAction=void)__attribute__((ibaction)" -miphoneos-version-min=4.0 -msoft-float -funsigned-char -fno-common -fno-builtin -fomit-frame-pointer -fstrict-aliasing -finline -finline-functions -funroll-loops -DVERSION='"$(VERSION)"' -I/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk/System/Library/PrivateFrameworks -I/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator5.0.sdk/System/Library/Frameworks -F/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator5.0.sdk/System/Library/Frameworks
#-mcpu=arm1176jzf-s -fpeel-loops
#-msoft-float 

all:	gpSPhone

#iphone/video_blend.o 

# /Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk/System/Library/PrivateFrameworks/
# /Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.0.sdk/System/Library/Frameworks/
gpSPhone:	iphone/gpSPhone/src/JoyPad.o iphone/gpSPhone/src/iphone.o iphone/gpSPhone/src/main.o iphone/gpSPhone/src/gpSPhoneApp.o iphone/gpSPhone/src/ControllerView.o iphone/gpSPhone/src/MainView.o iphone/gpSPhone/src/FileTable.o iphone/gpSPhone/src/FileBrowser.o iphone/gpSPhone/src/EmulationView.o iphone/gpSPhone/src/ScreenView.o iphone/gpSPhone/src/gpSPhone_iPhone.o iphone/arm_stub_c.o iphone/font.o iphone/display.o cheats.o zip.o gui.o main.o cpu.o sound.o input.o memory.o video.o iphone/arm_asm_stub.o cpu_threaded.o 
	$(LD) ${CFLAGS} $(LDFLAGS) -o $@ $^

%.o:	%.m
	$(CC) ${CFLAGS} -c $< -o $@

%.o:	%.c
	$(CC) ${CFLAGS} -c $< -o $@

%.o:	%.S
	$(CC) -c $< -o $@

%.z:	%.c
	$(CC) ${CFLAGS} -S $< -o $@

clean:
	rm -f ./*.o iphone/*.o iphone/gpSPhone/*.o iphone/gpSPhone/src/*.o gpSPhone src/*.gch
	rm -rf ./build
