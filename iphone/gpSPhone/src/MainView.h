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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "UITransitionView.h"

#import "FileBrowser.h"
#import "EmulationView.h"

extern char * __fileName;
extern int __screenOrientation;

extern void gotoMenu();

@interface MainView : UIView <UIActionSheetDelegate, UIAlertViewDelegate, UITabBarDelegate, UITableViewDelegate, UITableViewDataSource, FileBrowserDelegate>
{
	NSString * m_currentFile;

	CGRect mainRect;
	UINavigationBar * navBar;
	UITransitionView * transitionView;
	FileBrowser * fileBrowser;
	FileBrowser * savedBrowser;
	FileBrowser * recentBrowser;
	FileBrowser * bookmarkBrowser;
	EmulationView * emuView;
	UITableView * prefTable;
	UITabBar * tabBar;
	UINavigationItem * navItem;

	/* Caching for preference table */
	NSString * currentGameTitle;

	int currentView;
	int currentBrowserPage;
	pthread_t emulation_tid;

	BOOL allowDeleteROMs;
	NSString * versionString;
	UIWindow * parentWindow;
}

+ (MainView *)mainView;

- (id)initWithFrame:(CGRect)frame;
- (void)dealloc;
- (void)startEmulator;
- (void)stopEmulator:(BOOL)promptForSave;
- (void)resumeEmulator;
- (void)suspendEmulator;
- (void)setNavBar;
- (BOOL)isBrowsing;
- (UITableView *)createPrefPane;
- (FileBrowser *)createBrowser;
- (EmulationView *)createEmulationView;
- (UINavigationBar *)createNavBar;
- (UITransitionView *)createTransitionView:(int)offset;
- (int)getCurrentView;
- (void)reloadBrowser;
- (UITabBar *)createTabBar;
- (NSArray *)tabBarItems;
- (void)reloadButtonBar;
- (void)load;
- (BOOL)isBookmarked:(NSString *)file;
- (void)addBookmark:(NSString *)file;
- (void)gotoMenu;

#define CUR_BROWSER          0x00
#define CUR_PREFERENCES      0x01
#define CUR_EMULATOR         0x02
#define CUR_EMULATOR_SUSPEND 0x04

#define CB_NORMAL            0x00
#define CB_SAVED             0x01
#define CB_RECENT            0x02
#define CB_BOOKMARKS         0x03

extern NSString * kUIButtonBarButtonAction;
extern NSString * kUIButtonBarButtonInfo;
extern NSString * kUIButtonBarButtonInfoOffset;
extern NSString * kUIButtonBarButtonSelectedInfo;
extern NSString * kUIButtonBarButtonStyle;
extern NSString * kUIButtonBarButtonTag;
extern NSString * kUIButtonBarButtonTarget;
extern NSString * kUIButtonBarButtonTitle;
extern NSString * kUIButtonBarButtonTitleVerticalHeight;
extern NSString * kUIButtonBarButtonTitleWidth;
extern NSString * kUIButtonBarButtonType;

@end
