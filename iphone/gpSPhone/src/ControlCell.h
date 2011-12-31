@interface ControlCell : UITableViewCell
@property (nonatomic, assign) Class controlClass;

@property (nonatomic, readonly) id control;

@property (nonatomic, assign) SEL controlAction;
@end
