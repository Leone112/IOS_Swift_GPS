/*

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; version 2
 of the License.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

*/

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "FileTable.h"

@class FileBrowser;

@protocol FileBrowserDelegate <NSObject>
@optional
- (void)fileBrowser: (FileBrowser *)browser fileSelected:(NSString *)file;
@end

@interface FileBrowser : UIView 
{
	NSMutableArray *_extensions;
	NSMutableArray *_files;
	FileTable *_table;
	NSString *_path;
	int _rowCount;
	id <FileBrowserDelegate> _delegate;
	BOOL _saved;
	BOOL _recent;
	BOOL _bookmarks;
	BOOL _allowDeleteROMs;
}
@property (nonatomic, copy) NSString *path;
@property (nonatomic, assign) id <FileBrowserDelegate> delegate;

- (id)initWithFrame:(CGRect)rect;
- (void)reloadData;
- (int)numberOfRowsInTable:(UITable *)table;
- (UIDeletableCell *)table:(UITable *)table cellForRow:(int)row column:(UITableColumn *)col;
- (void)tableRowSelected:(NSNotification *)notification;
- (NSString *)selectedFile;
- (void)addExtension: (NSString *)extension;
- (void)setSaved: (BOOL)saved;
- (BOOL)getSaved;
- (void)setAllowDeleteROMs: (BOOL)allow;
- (void)scrollToTop;
- (void)setRecent:(BOOL)recent;
- (void)setBookmarks:(BOOL)bookmarks;

@end
