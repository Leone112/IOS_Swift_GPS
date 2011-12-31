/*
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; version 2
 * of the License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 */

#import "gpSPhoneApp.h"
#import "MainView.h"
#import <sys/types.h>
#import <dirent.h>

#import <AudioToolbox/AudioToolbox.h>

float __audioVolume = 1.0;

MainView * mainView;

static void noteCurrentSystemVolume(void * inUserData, AudioSessionPropertyID inPropertyID, UInt32 inPropertyValueSize, const void * inPropertyValue);

@implementation gpSPhoneApp
- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	struct CGRect rect;
	bool hasROMs = 0;

	[ [ UIApplication sharedApplication ] setStatusBarHidden:YES ];

	gpSPhone_LoadPreferences();

	rect = [ [ UIScreen mainScreen ] applicationFrame ];
	window = [ [ UIWindow alloc ] initWithFrame:rect ];

	rect.origin = CGPointZero;

	mainView = [ [ MainView alloc ] initWithFrame:rect ];

	[ window addSubview:mainView ];
	[ window makeKeyAndVisible ];

	noteCurrentSystemVolume(NULL, 0, 0, NULL);

	AudioSessionInitialize(NULL, NULL, NULL, NULL);
	OSStatus status = AudioSessionAddPropertyListener(kAudioSessionProperty_CurrentHardwareOutputVolume, noteCurrentSystemVolume, self);
	if (!status)
	{
		// failure
	}
	else
	{
		AudioSessionSetActive(true);
	}

	/* Determine if we have any ROMs */
	NSDirectoryEnumerator * dirEnum;
	DIR * testdir;
	testdir = opendir(ROM_PATH2);
	if (testdir != NULL)
	{
		dirEnum = [ [ NSFileManager defaultManager ]
					enumeratorAtPath:@ROM_PATH2 ];
	}
	else
	{
		dirEnum = [ [ NSFileManager defaultManager ]
					enumeratorAtPath:@ROM_PATH1 ];
	}
	NSString * file;
	if ((file = [ dirEnum nextObject ]))
	{
		hasROMs = YES;
	}
	else
	{
		UIActionSheet * noROMSheet = [ [ UIActionSheet alloc ] initWithFrame:
									   CGRectMake(0, 240, 320, 240) ];
		[ noROMSheet setTitle:@"No ROMs Found" ];
		[ noROMSheet addButtonWithTitle:@"OK" ];
		[ noROMSheet setDelegate:self ];
		[ noROMSheet showInView:mainView ];
		[ noROMSheet release ];
	}

	/* Initialize stats bar icons and notification on first good run */
	if (hasROMs == YES)
	{
		bool feedMe = YES;
		FILE * f = fopen_home(INIT_PATH, "r");
		if (f != NULL)
		{
			char version[256];
			if ((fgets(version, sizeof(version), f)) != NULL)
			{
				if (!strcmp(version, VERSION))
					feedMe = NO;
			}
			fclose(f);
		}
		if (feedMe == YES)
		{
			unlink("/var/root/Library/Preferences/gpSPhone.v1");
			unlink("/var/mobile/Library/Preferences/gpSPhone.v1");
			gpSPhone_LoadPreferences();
		}
	}
}

- (void) applicationWillEnterForeground:(UIApplication *)application
{
	if ([ mainView getCurrentView ] == CUR_EMULATOR_SUSPEND)
		[ mainView resumeEmulator ];
}

- (void) applicationWillTerminate:(UIApplication *)application
{

	LOGDEBUG("gpSPhoneApp.applicationDidEnterBackground");

	if ([ mainView getCurrentView ] != CUR_EMULATOR_SUSPEND)
	{
		gpSPhone_CloseSound();
		[ mainView stopEmulator:NO ];
		[ mainView savePreferences ];
	}
}

- (void) applicationDidEnterBackground:(UIApplication *)application
{
	LOGDEBUG("gpSPhoneApp.applicationDidEnterBackground()");

	[ mainView savePreferences ];
	if ([mainView getCurrentView] == CUR_EMULATOR)
		[ mainView suspendEmulator ];
}

static void noteCurrentSystemVolume(void * inUserData, AudioSessionPropertyID inPropertyID, UInt32 inPropertyValueSize, const void * inPropertyValue)
{
	UInt32 propertySize = sizeof(CFStringRef);
	OSStatus status = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareOutputVolume, &propertySize, &__audioVolume);

	if (status)
	{
		// failed
	}

	LOGDEBUG("Noting volume: %f", __audioVolume);
}
@end
