@interface ControlCell : UITableViewCell
@property (nonatomic) Class controlClass;

@property (nonatomic, readonly) UIControl *control;

@property (nonatomic) SEL controlAction;
@end
