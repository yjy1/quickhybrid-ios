//
//  QHJSUiApi.m
//  quickhybriddemo
//
//  Created by 戴荔春 on 2017/12/31.
//  Copyright © 2017年 quickhybrid. All rights reserved.
//

#import "QHJSRuntimeApi.h"
#import "QHBaseWebLoader.h"
#import "QHDeviceUtil.h"

@implementation QHJSRuntimeApi

- (void)registerHandlers {
    [self registerHandlerName:@"getAppVersion" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSString *appVersion = [QHDeviceUtil getAppVersion];
        NSDictionary *dic = [self responseDicWithCode:1 Msg:@"" result:@{@"version":appVersion}];
        responseCallback(dic);
    }];
    
    [self registerHandlerName:@"getQuickVersion" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSDictionary *dic = [self responseDicWithCode:1 Msg:@"" result:@{@"version":@"1.0.0"}];
        responseCallback(dic);
    }];
}
@end



