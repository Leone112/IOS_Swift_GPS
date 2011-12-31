typedef void (^ControlBlock)(UIControl *control);

@interface ControlCell : UITableViewCell
@property (nonatomic, assign) Class controlClass;

@property (nonatomic, readonly) id control;

@property (nonatomic, retain) ControlBlock controlBlock;

- (void) setEnabled:(BOOL) enabled;
@end
