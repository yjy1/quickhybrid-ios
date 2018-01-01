//
//  QHBaseWebLoader.m
//  QuickHybirdJSBridgeDemo
//
//  Created by 管浩 on 2017/12/30.
//  Copyright © 2017年 com.gh. All rights reserved.
//

#import "QHBaseWebLoader.h"
#import "WKWebViewJavascriptBridge.h"

static NSString *KVOContext;

@interface QHBaseWebLoader () <WKUIDelegate, WKNavigationDelegate>
/** JSBridge */
@property (nonatomic, strong) WKWebViewJavascriptBridge *bridge;
/** 页面加载进度条 */
@property (nonatomic, weak) UIProgressView *progressView;
/** 加载进度条的高度约束 */
@property (nonatomic, strong) NSLayoutConstraint *progressH;
@end

@implementation QHBaseWebLoader

#pragma mark --- 生命周期
//改变User-Agent
+ (void)initialize {
    
    // Set user agent (the only problem is that we can't modify the User-Agent later in the program)
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        //获取默认UA
        NSString *defaultUA = [[UIWebView new] stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
        
        NSString *version = [[NSBundle mainBundle].infoDictionary objectForKey:@"CFBundleShortVersionString"];
        
        NSString *customerUA = [defaultUA stringByAppendingString:[NSString stringWithFormat:@" QuickHybridJs/%@", version]];
        
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"UserAgent":customerUA}];
        
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
    
    //    NSLog(@"ua=%@", [[UIWebView new] stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"]);
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // 初始化
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self createWKWebView];
    
    // 注册KVO
    [self.wv addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:&KVOContext];
    [self.wv addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:&KVOContext];
    
    // 注册框架API
    [self.bridge registerQHJSFrameAPI];
    
    // 加载H5页面
    [self loadHTML];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([[[self.params valueForKey:@"pageStyle"] stringValue] isEqualToString:@"-1"]) {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
    } else {
        [self.navigationController setNavigationBarHidden:NO animated:YES];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

// KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    // 判断是否是本类注册的KVO
    if (context == &KVOContext) {
        // 设置title
        if ([keyPath isEqualToString:@"title"]) {
            NSString *title = change[@"new"];
            self.navigationItem.title = title;
        }
        // 设置进度
        if ([keyPath isEqualToString:@"estimatedProgress"]) {
            NSNumber *progress = change[@"new"];
            self.progressView.progress = progress.floatValue;
            if (progress.floatValue == 1.0) {
                self.progressH.constant = 0;
                [UIView animateWithDuration:0.5 animations:^{
                    [self.view layoutIfNeeded];
                }];
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

/**
 创建WKWebView
 */
- (void)createWKWebView {
    // 创建进度条
    UIProgressView *progressView = [[UIProgressView alloc] init];
    progressView.progressTintColor = [UIColor lightGrayColor];
    [self.view addSubview:progressView];
    self.progressView = progressView;
    progressView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraints:@[
                                [NSLayoutConstraint constraintWithItem:progressView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1.0 constant:0],
                                [NSLayoutConstraint constraintWithItem:progressView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.view    attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0],
                                [NSLayoutConstraint constraintWithItem:progressView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self.view    attribute:NSLayoutAttributeRight multiplier:1.0 constant:0]
                                ]];
    NSLayoutConstraint *progressH = [NSLayoutConstraint constraintWithItem:progressView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:0 constant:1.5];
    self.progressH = progressH;
    [progressView addConstraint:self.progressH];
    
    // 创建webView容器
    WKWebViewConfiguration *webConfig = [[WKWebViewConfiguration alloc] init];
    WKUserContentController *userContentVC = [[WKUserContentController alloc] init];
    webConfig.userContentController = userContentVC;
    WKWebView *wk = [[WKWebView alloc] initWithFrame:CGRectZero configuration:webConfig];
    [self.view addSubview:wk];
    self.wv = wk;
    self.wv.navigationDelegate = self;
    self.wv.UIDelegate = self;
    self.wv.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 设置约束
    [self.view addConstraints:@[// left
                                [NSLayoutConstraint constraintWithItem:self.wv attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0],
                                // bottom
                                [NSLayoutConstraint constraintWithItem:self.wv attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0],
                                // right
                                [NSLayoutConstraint constraintWithItem:self.wv attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeRight multiplier:1.0 constant:0],
                                // top
                                [NSLayoutConstraint constraintWithItem:self.wv attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:progressView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0],
                                ]];
    
    self.bridge = [WKWebViewJavascriptBridge bridgeForWebView:self.wv];
    [self.bridge setWebViewDelegate:self];
    
    [self.wv.configuration.userContentController addScriptMessageHandler:self.bridge name:@"WKWebViewJavascriptBridge"];
}

/**
 加载地址
 */
- (void)loadHTML {
    NSString *url = [[self.params valueForKey:@"pageUrl"] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet  URLQueryAllowedCharacterSet]];
    if ([url hasPrefix:@"http"]) {
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
        [self.wv loadRequest:request];
    } else {
        // 加载本地页面，iOS 8不支持
        if (DeviceVersion >= 9.0) {
            //本地路径的html页面路径，如果含有参数，不能将?转码掉
//            NSURL *pathUrl = [NSURL fileURLWithPath:url];
            NSURL *pathUrl = [NSURL URLWithString:url];
            NSURL *bundleUrl = [[NSBundle mainBundle] bundleURL];
            [self.wv loadFileURL:pathUrl allowingReadAccessToURL:bundleUrl];
        } else {
            NSLog(@"不支持iOS9之下的设备");
        }
    }
}

#pragma mark - WKNavigationDelegate

//这个代理方法不实现也能正常跳转
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSLog(@"decidePolicyForNavigationAction");
    if ([navigationAction.request.URL.absoluteString isEqualToString:@"about:blank"]) {
        decisionHandler(WKNavigationActionPolicyCancel);
    } else {
        //支持 a 标签 target = ‘_blank’ ;
        if (navigationAction.targetFrame == nil) {
            [self openWindow:navigationAction];
        } else if (navigationAction.navigationType == WKNavigationTypeLinkActivated) {
            
        }
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

/**
 特殊跳转
 */
- (void)openWindow:(WKNavigationAction *)navigationAction {
    self.progressView.progress = 0;
    self.progressH.constant = 1;
    [self.wv loadRequest:navigationAction.request];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    decisionHandler(WKNavigationResponsePolicyAllow);
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    
}

// 重定向
- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    // ErroeCode
    // -1001 请求超时   -1009 似乎已断开与互联网的连接
    if (error.code == -1009) {
        NSLog(@"似乎已断开与互联网的连接");
        return;
    }
    if (error.code == -1001) {
        NSLog(@"请求超时");
        return;
    }
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation {
    
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    
}

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    //页面加载异常
    NSString *url = [self.params objectForKey:@"pageUrl"];
    //反馈页面加载错误
    [self.bridge handleErrorWithCode:0 errorUrl:url errorDescription:error.localizedDescription];
}

// https校验
- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler {
    completionHandler(NSURLSessionAuthChallengeUseCredential, nil);
}

#pragma mark --- WKWebViewUI

//显示一个JavaScript警告面板
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:message?:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:([UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler();
    }])];
    [self presentViewController:alertController animated:YES completion:nil];
}

//显示一个JavaScript确认面板
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler{
    NSLog(@"msg = %@ frmae = %@", message, frame);
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:message?:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:([UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(NO);
    }])];
    [alertController addAction:([UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(YES);
    }])];
    [self presentViewController:alertController animated:YES completion:nil];
}

//显示一个JavaScript文本输入面板
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable))completionHandler{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:prompt message:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = defaultText;
    }];
    [alertController addAction:([UIAlertAction actionWithTitle:@"完成" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(alertController.textFields[0].text?:@"");
    }])];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)presentNewVC:(UIViewController *)vc animated:(BOOL)animated {
    __weak typeof(self) weakSelf = self;
    [weakSelf presentViewController:vc animated:animated completion:nil];
}

- (void)pushNewVC:(UIViewController *)vc {
    __weak typeof(self) weakSelf = self;
    [weakSelf.navigationController pushViewController:vc animated:YES];
}

- (void)dealloc {
    NSLog(@"<QHBaseWebLoader>dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.wv removeObserver:self forKeyPath:@"title" context:&KVOContext];
    [self.wv removeObserver:self forKeyPath:@"estimatedProgress" context:&KVOContext];
}

- (BOOL)registerHandlersWithClassName:(NSString *)className
                           moduleName:(NSString *)moduleName {
    return [self.bridge registerHandlersWithClassName:className moduleName:moduleName];
}

- (BOOL)registerAccessWithClassName:(NSString *)className methodName:(NSString *)methodName {
    [self.bridge registerHandlersWithAccess:className handlerName:methodName];
    return YES;
}

-(void)backAction{
    __weak typeof(self) weakSelf = self;
    if (weakSelf.superVC) {
        // 如果存在superVC,说明当前容器是“多个EJS容器”类型
        [weakSelf.superVC.navigationController popViewControllerAnimated:YES];
    } else {
        // 如果不存在superVC，说明当前容器是普通容器，直接获取navigationController然后push
        [weakSelf.navigationController popViewControllerAnimated:YES];
    }
    NSLog(@"BaseWebLoader back Action");
}

- (void)reloadWKWebview {
    [self.wv reload];
}

@end
