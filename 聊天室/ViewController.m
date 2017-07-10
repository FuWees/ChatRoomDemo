//
//  ViewController.m
//  聊天室
//
//  Created by wupeng on 16/3/14.
//  Copyright © 2016年 wupeng. All rights reserved.
//

#import "ViewController.h"

#define InputViewHeight 35

static NSString *cellID = @"cellID";

@interface ViewController ()<UITableViewDataSource,UITableViewDelegate,UITextFieldDelegate,NSStreamDelegate>
{
    NSInputStream *_inputStream;//输入流
    NSOutputStream *_outputStream;//输出流
    
}

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomLayout;//输入框距离底部约束
@property (weak, nonatomic) IBOutlet UITextField *messageText;
@property (nonatomic, strong) NSMutableArray *dataSource;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    //注册cell
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:cellID];
    
    //监听键盘
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kbFreamWillChange:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kbFreamWillChange:) name:UIKeyboardWillHideNotification object:nil];
    
    
}

-(void)kbFreamWillChange:(NSNotification *)notification{
    NSLog(@"%@",notification.userInfo);
    
    //屏高
    CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
    //键盘改变时候的规格
    CGRect kbRect = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    self.bottomLayout.constant = screenH - kbRect.origin.y;
    
    
}

//数据源懒加载
-(NSMutableArray *)dataSource{
    if (!_dataSource) {
        _dataSource = [NSMutableArray array];
        
    }
    return _dataSource;
}

//登录
- (IBAction)login:(id)sender {
    //登录：发送用户名和密码到服务器
    // 如果要登录，发送的数据格式为 "iam:zhangsan";
    
    //登录指令
    NSString *loginStr = @"iam:wupeng";
    
    NSData *loginData = [loginStr dataUsingEncoding:NSUTF8StringEncoding];
    //发送指令
    [_outputStream write:loginData.bytes maxLength:loginData.length];
    
}

//连接到服务器
- (IBAction)connectServer:(id)sender {
    //建立连接
    NSString *host = @"192.168.10.100";
    int port = 8080;
    
    //定义C语言的输入输出流
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    //创建socket到主机
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)(host), port, &readStream, &writeStream);
    
    //把C语音的输入输出流转化成OC对象
    _inputStream = (__bridge NSInputStream *)(readStream);
    _outputStream = (__bridge NSOutputStream *)(writeStream);
    
    //设置代理
    _inputStream.delegate = self;
    _outputStream.delegate = self;
    
    //把输入输出流添加到主运行循环
    //如果不添加到主运行循环，代理有可能不工作
    [_inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [_outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    
    //打开输入输出流
    [_inputStream open];
    [_outputStream open];
    
    
}

//发送消息
- (IBAction)sendMessage:(id)sender {
    
    // 如果要发送聊天消息，数据格式为 "msg:did you have dinner";
    NSString *messageStr = [NSString stringWithFormat:@"msg:%@",self.messageText.text];
    
    NSData *messageData = [messageStr dataUsingEncoding:NSUTF8StringEncoding];
    //刷新表格
    [self reloadTableViewWithText:messageStr];
    
    //发送消息
    [_outputStream write:messageData.bytes maxLength:messageData.length];
    
    //将textField清空
    self.messageText.text = nil;
    
}

-(void)reloadTableViewWithText:(NSString *)text{
    
    //将消息加入到数据源中
    [self.dataSource addObject:text];
    [self.tableView reloadData];
    
    //表格滚动到最底部
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.dataSource.count - 1 inSection:0];
    [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    
    
}


#pragma mark - tableView代理方法
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID forIndexPath:indexPath];
    cell.textLabel.text = self.dataSource[indexPath.row];
    
    return cell;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.dataSource.count;
}

#pragma mark - NSStream代理方法
-(void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode{
//    NSStreamEventNone = 0,
//    NSStreamEventOpenCompleted = 1UL << 0, //流打开完成
//    NSStreamEventHasBytesAvailable = 1UL << 1, //有字节可读
//    NSStreamEventHasSpaceAvailable = 1UL << 2, //可以发送字节
//    NSStreamEventErrorOccurred = 1UL << 3, //有错误
//    NSStreamEventEndEncountered = 1UL << 4 //连接结束
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
        {
            NSLog(@"输入输出流打开完成");
            
        }
            break;
        case NSStreamEventHasBytesAvailable:
        {
            NSLog(@"有字节可读");
            
            [self readData];
        }
            break;
        case NSStreamEventHasSpaceAvailable:
        {
            NSLog(@"可以发送字节");
        }
            break;
        case NSStreamEventErrorOccurred:
        {
            NSLog(@"连接错误");
        }
            break;
        case NSStreamEventEndEncountered:
        {
            NSLog(@"连接结束");
        }
            break;
            
        default:
            break;
    }
}
#pragma mark -  读到了服务器返回的数据
-(void)readData{
    //建立一个缓冲区
    uint8_t buf[1024];
    
    //返回实际装的字节数
    NSInteger len = [_inputStream read:buf maxLength:sizeof(buf)];
    
    //把字节数组转化成二进制数据
    NSData *receiveData = [NSData dataWithBytes:buf length:len];
    
    //把二进制数据转化成字符串
    NSString *receiveStr = [[NSString alloc]initWithData:receiveData encoding:NSUTF8StringEncoding];
    
    NSLog(@"%@",receiveStr);
    //刷新表格
    [self reloadTableViewWithText:receiveStr];
    
    
}

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    [self.messageText resignFirstResponder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
