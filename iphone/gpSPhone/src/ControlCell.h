#import <UIKit/UITableViewCell.h>

typedef void (^ControlBlock)(id control);

@interface ControlCell : UITableViewCell
@property (nonatomic, assign) Class controlClass;

@property (nonatomic, readonly) id control;

@property (nonatomic, retain) ControlBlock controlBlock;

- (void) setEnabled:(BOOL) enabled;
@end
