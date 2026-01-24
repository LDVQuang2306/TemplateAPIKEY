#import "HeaderAPI.h"
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <objc/message.h>

typedef void (*VoidImp)(id, SEL, ...);
typedef id (*IdImp)(id, SEL, ...);
typedef void (*MsgSendFunc)(void);
typedef void (*TrampolineFunc)(id, SEL, id);
typedef void (*ImpFuncType)(id, SEL, id); 

static void __attribute__((noinline)) trampoline_jump(void (*func)(id, SEL, id), id t, SEL s, id o) {
    volatile uintptr_t func_addr = (uintptr_t)func;
    volatile uintptr_t mask = 0xDEADBEEF;
    uintptr_t masked = func_addr ^ mask;
    uintptr_t unmasked = masked ^ mask;
    ((void (*)(id, SEL, id))unmasked)(t, s, o);
}

@interface LDVQuang : NSObject
@property (nonatomic, strong) NSString *contactLink;
@property (nonatomic, assign) BOOL isMaintenance;
@property (nonatomic, strong) NSMutableDictionary *memoryGap;
+ (instancetype)sharedInstance;
- (void)startProcess;
@end

@implementation LDVQuang

- (void)vm_exec_selector:(SEL)sel target:(id)target object:(id)obj {
    [self vm_entry_point:sel target:target object:obj];
}

- (void)vm_entry_point:(SEL)s target:(id)t object:(id)o {
    if (!t || !s) return;
    
    volatile uintptr_t imp_addr = (uintptr_t)class_getMethodImplementation([t class], s);
    
    void (*volatile target_func)(id, SEL, id) = (void (*)(id, SEL, id))imp_addr;
    
    trampoline_jump(target_func, t, s, o);
}

- (id)vm_exec_return:(SEL)sel target:(id)target {
    if ([target respondsToSelector:sel]) {
        IMP imp = [target methodForSelector:sel];
        id (*func)(id, SEL) = (id (*)(id, SEL))imp;
        return func(target, sel);
    }
    return nil;
}

+ (instancetype)sharedInstance {
    static LDVQuang *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    void (*dispatch_once_ptr)(dispatch_once_t *, dispatch_block_t) = (void(*)(dispatch_once_t *, dispatch_block_t))dispatch_once;
    
    dispatch_once_ptr(&onceToken, ^{
        sharedInstance = [[LDVQuang alloc] init];
        SEL setC = sel_registerName("setContactLink:");
        ((void(*)(id, SEL, id))objc_msgSend)(sharedInstance, setC, @"");
        
        SEL setM = sel_registerName("setMemoryGap:");
        Class dictCls = objc_getClass("NSMutableDictionary");
        SEL dictSel = sel_registerName("dictionary");
        id dict = ((id(*)(id, SEL))objc_msgSend)(dictCls, dictSel);
        ((void(*)(id, SEL, id))objc_msgSend)(sharedInstance, setM, dict);
    });
    return sharedInstance;
}

+ (void)load {
    unsigned long long delay = 1;
    dispatch_time_t d_time = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC));
    
    dispatch_after(d_time, dispatch_get_main_queue(), ^{
        Class cls = objc_getClass("LDVQuang");
        SEL sharedSel = sel_registerName("sharedInstance");
        id instance = ((id(*)(id, SEL))objc_msgSend)(cls, sharedSel);
        
        SEL startSel = sel_registerName("startProcess");
        ((void(*)(id, SEL))objc_msgSend)(instance, startSel);
    });
}

- (UIViewController *)getTopViewController {
    __block UIViewController *resultVC = nil;
    
    void (^finderBlock)(void) = ^{
        UIWindow *foundWindow = nil;
        Class appCls = objc_getClass("UIApplication");
        SEL sharedAppSel = sel_registerName("sharedApplication");
        id sharedApp = ((id(*)(id, SEL))objc_msgSend)(appCls, sharedAppSel);
        
        void *labels[] = { &&StateInit, &&StateIOS13, &&StateSceneLoop, &&StateWinLoop, &&StateLegacy, &&StateLegacyLoop, &&StateFinal, &&StateEnd };
        volatile int state = 0;
        
    Dispatch:
        goto *labels[state];
        
    StateInit:
        if (@available(iOS 13.0, *)) {
            state = 1;
        } else {
            state = 4;
        }
        goto Dispatch;
        
    StateIOS13: {
        SEL connScenesSel = sel_registerName("connectedScenes");
        NSSet *scenes = ((id(*)(id, SEL))objc_msgSend)(sharedApp, connScenesSel);
        NSArray *allScenes = [scenes allObjects];
        int i = 0;
        
        while (i < allScenes.count) {
            UIScene *scene = allScenes[i];
            Class winSceneCls = objc_getClass("UIWindowScene");
            if ([scene isKindOfClass:winSceneCls]) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    UIWindowScene *ws = (UIWindowScene *)scene;
                    NSArray *wins = ws.windows;
                    for (UIWindow *w in wins) {
                        if (w.isKeyWindow) {
                            foundWindow = w;
                            state = 6;
                            goto Dispatch;
                        }
                    }
                }
            }
            i++;
        }
        state = 4;
        goto Dispatch;
    }
        
    StateSceneLoop:
        state = 4; 
        goto Dispatch;
        
    StateWinLoop:
        state = 6;
        goto Dispatch;
        
    StateLegacy: {
        SEL winsSel = sel_registerName("windows");
        NSArray *appWindows = ((id(*)(id, SEL))objc_msgSend)(sharedApp, winsSel);
        for (UIWindow *window in appWindows) {
            if (window.isKeyWindow) {
                foundWindow = window;
                state = 6;
                goto Dispatch;
            }
        }
        state = 5;
        goto Dispatch;
    }
        
    StateLegacyLoop: {
        SEL winsSel = sel_registerName("windows");
        NSArray *appWindows = ((id(*)(id, SEL))objc_msgSend)(sharedApp, winsSel);
        if (!foundWindow) {
            foundWindow = appWindows.firstObject;
        }
        state = 6;
        goto Dispatch;
    }
        
    StateFinal:
        state = 7;
        goto Dispatch;
        
    StateEnd:
        resultVC = foundWindow.rootViewController;
        while (resultVC.presentedViewController) {
            resultVC = resultVC.presentedViewController;
        }
    };
    
    finderBlock();
    return resultVC;
}

- (void)forceExitApp:(NSString *)reason {
    dispatch_async(dispatch_get_main_queue(), ^{
        SEL getTopSel = sel_registerName("getTopViewController");
        UIViewController *rootVC = ((id(*)(id, SEL))objc_msgSend)(self, getTopSel);
        
        void (^exitBlock)(void) = ^{
            volatile int a = 10;
            volatile int b = 0;
            if (a > 5) exit(0);
            int c = a / b;
            (void)c;
        };
        
        if (rootVC) {
            NSString *t1 = @"Lỗi ";
            NSString *t2 = @"Hệ Thống";
            NSString *fullTitle = [NSString stringWithFormat:@"%@%@", t1, t2];
            
            Class alertCls = objc_getClass("UIAlertController");
            SEL alertSel = sel_registerName("alertControllerWithTitle:message:preferredStyle:");
            id alert = ((id(*)(id, SEL, id, id, NSInteger))objc_msgSend)(alertCls, alertSel, fullTitle, reason, 1);
            
            Class actionCls = objc_getClass("UIAlertAction");
            SEL actionSel = sel_registerName("actionWithTitle:style:handler:");
            id act = ((id(*)(id, SEL, id, NSInteger, void (^)(id)))objc_msgSend)(actionCls, actionSel, @"Thoát", 2, ^(id action) {
                exitBlock();
            });
            
            SEL addActSel = sel_registerName("addAction:");
            ((void(*)(id, SEL, id))objc_msgSend)(alert, addActSel, act);
            
            SEL presentSel = sel_registerName("presentViewController:animated:completion:");
            ((void(*)(id, SEL, id, BOOL, id))objc_msgSend)(rootVC, presentSel, alert, YES, nil);
        } else {
            exitBlock();
        }
    });
}

- (void)startProcess {
    char u[] = {'?', 'a', 'c', 't', 'i', 'o', 'n', '=', 'i', 'n', 'i', 't', '&', 't', 'o', 'k', 'e', 'n', '=', 0};
    NSString *params = [NSString stringWithUTF8String:u];
    
    NSString *base = kBaseAPIURL;
    NSString *tk = kPackageToken;
    SEL fmtSel = sel_registerName("stringWithFormat:");
    NSString *fullURL = ((id(*)(id, SEL, id, ...))objc_msgSend)(objc_getClass("NSString"), fmtSel, @"%@%@%@", base, params, tk);
    
    char s_p[] = {'p','r','o','c','e','s','s','W','i','t','h','U','R','L',':', 0};
    SEL selector = sel_registerName(s_p);
    
    if ([self respondsToSelector:selector]) {
        [self vm_exec_selector:selector target:self object:fullURL];
    }
}

- (void)processWithURL:(NSString *)urlString {
    Class urlCls = objc_getClass("NSURL");
    SEL urlSel = sel_registerName("URLWithString:");
    id url = ((id(*)(id, SEL, id))objc_msgSend)(urlCls, urlSel, urlString);
    
    Class sessionCls = objc_getClass("NSURLSession");
    SEL sharedSel = sel_registerName("sharedSession");
    id session = ((id(*)(id, SEL))objc_msgSend)(sessionCls, sharedSel);
    
    SEL dataTaskSel = sel_registerName("dataTaskWithURL:completionHandler:");
    
    id task = ((id(*)(id, SEL, id, void (^)(NSData*, NSURLResponse*, NSError*)))objc_msgSend)(session, dataTaskSel, url, ^(NSData *data, NSURLResponse *response, NSError *error) {
        
        volatile int state = 0;
        NSDictionary *json = nil;
        void *branchTable[] = { &&L_CHECK_ERR, &&L_PARSE_JSON, &&L_CHECK_FORCE, &&L_CHECK_STATUS, &&L_ERR_DATA, &&L_EXIT };
        
    Branching:
        if (state < 0 || state > 5) state = 5;
        goto *branchTable[state];
        
    L_CHECK_ERR:
        if (error) {
            SEL forceSel = sel_registerName("forceExitApp:");
            ((void(*)(id, SEL, id))objc_msgSend)(self, forceSel, @"Không thể kết nối đến server.");
            state = 5;
        } else {
            state = 1;
        }
        goto Branching;
        
    L_PARSE_JSON:
        if (data) {
            Class jsonCls = objc_getClass("NSJSONSerialization");
            SEL jsonSel = sel_registerName("JSONObjectWithData:options:error:");
            json = ((id(*)(id, SEL, id, NSInteger, id))objc_msgSend)(jsonCls, jsonSel, data, 0, nil);
            state = (json) ? 2 : 4;
        } else {
            state = 4;
        }
        goto Branching;
        
    L_CHECK_FORCE: {
        BOOL force = NO;
        if (json[@"force_exit"]) force = [json[@"force_exit"] boolValue];
        
        if (force) {
            SEL forceSel = sel_registerName("forceExitApp:");
            id msg = json[@"message"] ?: @"Token package không tồn tại.";
            ((void(*)(id, SEL, id))objc_msgSend)(self, forceSel, msg);
            state = 5;
        } else {
            state = 3;
        }
        goto Branching;
    }
        
    L_CHECK_STATUS: {
        BOOL st = NO;
        if (json[@"status"]) st = [json[@"status"] boolValue];
        
        if (st) {
            SEL setCSel = sel_registerName("setContactLink:");
            ((void(*)(id, SEL, id))objc_msgSend)(self, setCSel, json[@"contact"]);
            
            SEL setMSel = sel_registerName("setIsMaintenance:");
            BOOL maint = [json[@"maintenance"] boolValue];
            ((void(*)(id, SEL, BOOL))objc_msgSend)(self, setMSel, maint);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                SEL succSel = sel_registerName("handleInitSuccess");
                ((void(*)(id, SEL))objc_msgSend)(self, succSel);
            });
        } else {
            SEL forceSel = sel_registerName("forceExitApp:");
            id msg = json[@"message"] ?: @"Lỗi không xác định.";
            ((void(*)(id, SEL, id))objc_msgSend)(self, forceSel, msg);
        }
        state = 5;
        goto Branching;
    }
        
    L_ERR_DATA:
        {
            SEL forceSel = sel_registerName("forceExitApp:");
            ((void(*)(id, SEL, id))objc_msgSend)(self, forceSel, @"Dữ liệu server không hợp lệ.");
            state = 5;
        }
        goto Branching;
        
    L_EXIT:
        return;
    });
    
    SEL resumeSel = sel_registerName("resume");
    ((void(*)(id, SEL))objc_msgSend)(task, resumeSel);
}

- (void)handleInitSuccess {
    int index = 0;
    
    char k_key[] = {'s','a','v','e','d','_','l','i','c','e','n','s','e','_','k','e','y',0};
    NSString *savedKeyName = [NSString stringWithUTF8String:k_key];
    
    if (self.isMaintenance) {
        index = 0;
    } else {
        Class userDefCls = objc_getClass("NSUserDefaults");
        SEL stdSel = sel_registerName("standardUserDefaults");
        id userDef = ((id(*)(id, SEL))objc_msgSend)(userDefCls, stdSel);
        SEL objSel = sel_registerName("objectForKey:");
        NSString *savedKey = ((id(*)(id, SEL, id))objc_msgSend)(userDef, objSel, savedKeyName);
        index = (savedKey) ? 1 : 2;
    }
    
    typedef void (^ProcessBlock)(void);
    ProcessBlock b0 = ^{ [self showMaintenanceAlert]; };
    ProcessBlock b1 = ^{
        Class userDefCls = objc_getClass("NSUserDefaults");
        SEL stdSel = sel_registerName("standardUserDefaults");
        id userDef = ((id(*)(id, SEL))objc_msgSend)(userDefCls, stdSel);
        SEL objSel = sel_registerName("objectForKey:");
        NSString *k = ((id(*)(id, SEL, id))objc_msgSend)(userDef, objSel, savedKeyName);
        
        SEL checkSel = sel_registerName("checkKey:isAuto:");
        ((void(*)(id, SEL, id, BOOL))objc_msgSend)(self, checkSel, k, YES);
    };
    ProcessBlock b2 = ^{ [self showKeyAlert]; };
    
    ProcessBlock blocks[4];
    blocks[0] = b0;
    blocks[1] = b1;
    blocks[2] = b2;
    blocks[3] = b2;
    
    volatile int target_idx = index & 3;
    blocks[target_idx]();
}

- (void)showMaintenanceAlert {
    SEL getTopSel = sel_registerName("getTopViewController");
    UIViewController *rootVC = ((id(*)(id, SEL))objc_msgSend)(self, getTopSel);
    if (!rootVC) return;
    
    Class alertCls = objc_getClass("UIAlertController");
    SEL alertSel = sel_registerName("alertControllerWithTitle:message:preferredStyle:");
    id alert = ((id(*)(id, SEL, id, id, NSInteger))objc_msgSend)(alertCls, alertSel, @"Bảo Trì", @"Hệ thống đang bảo trì.", 1);
    
    Class actionCls = objc_getClass("UIAlertAction");
    SEL actionSel = sel_registerName("actionWithTitle:style:handler:");
    SEL addActSel = sel_registerName("addAction:");
    
    if (self.contactLink.length > 0) {
        id act = ((id(*)(id, SEL, id, NSInteger, void (^)(id)))objc_msgSend)(actionCls, actionSel, @"Liên hệ", 2, ^(id action) {
            Class appCls = objc_getClass("UIApplication");
            SEL sharedSel = sel_registerName("sharedApplication");
            id app = ((id(*)(id, SEL))objc_msgSend)(appCls, sharedSel);
            SEL openSel = sel_registerName("openURL:options:completionHandler:");
            NSURL *u = [NSURL URLWithString:self.contactLink];
            ((void(*)(id, SEL, id, id, id))objc_msgSend)(app, openSel, u, @{}, nil);
            exit(0);
        });
        ((void(*)(id, SEL, id))objc_msgSend)(alert, addActSel, act);
    } else {
        id act = ((id(*)(id, SEL, id, NSInteger, void (^)(id)))objc_msgSend)(actionCls, actionSel, @"Thoát", 2, ^(id action) { exit(0); });
        ((void(*)(id, SEL, id))objc_msgSend)(alert, addActSel, act);
    }
    
    SEL presentSel = sel_registerName("presentViewController:animated:completion:");
    ((void(*)(id, SEL, id, BOOL, id))objc_msgSend)(rootVC, presentSel, alert, YES, nil);
}

- (void)showKeyAlert {
    SEL getTopSel = sel_registerName("getTopViewController");
    UIViewController *rootVC = ((id(*)(id, SEL))objc_msgSend)(self, getTopSel);
    if (!rootVC) return;
    
    Class alertCls = objc_getClass("UIAlertController");
    SEL alertSel = sel_registerName("alertControllerWithTitle:message:preferredStyle:");
    id alert = ((id(*)(id, SEL, id, id, NSInteger))objc_msgSend)(alertCls, alertSel, @"Nhập Key", @"Vui lòng nhập key để kích hoạt.", 1);
    
    SEL configSel = sel_registerName("configureTextFieldForAlert:");
    ((void(*)(id, SEL, id))objc_msgSend)(self, configSel, alert);
    
    Class actionCls = objc_getClass("UIAlertAction");
    SEL actionSel = sel_registerName("actionWithTitle:style:handler:");
    SEL addActSel = sel_registerName("addAction:");
    
    if (self.contactLink.length > 0) {
        id act = ((id(*)(id, SEL, id, NSInteger, void (^)(id)))objc_msgSend)(actionCls, actionSel, @"Contact", 2, ^(id action) {
            Class appCls = objc_getClass("UIApplication");
            SEL sharedSel = sel_registerName("sharedApplication");
            id app = ((id(*)(id, SEL))objc_msgSend)(appCls, sharedSel);
            SEL openSel = sel_registerName("openURL:options:completionHandler:");
            NSURL *u = [NSURL URLWithString:self.contactLink];
            ((void(*)(id, SEL, id, id, id))objc_msgSend)(app, openSel, u, @{}, nil);
            [self showKeyAlert];
        });
        ((void(*)(id, SEL, id))objc_msgSend)(alert, addActSel, act);
    }
    
    id actLogin = ((id(*)(id, SEL, id, NSInteger, void (^)(id)))objc_msgSend)(actionCls, actionSel, @"Login", 0, ^(id action) {
        UITextField *tf = ((NSArray *)((id(*)(id, SEL))objc_msgSend)(alert, sel_registerName("textFields"))).firstObject;
        if (tf.text.length > 0) {
            SEL checkSel = sel_registerName("checkKey:isAuto:");
            ((void(*)(id, SEL, id, BOOL))objc_msgSend)(self, checkSel, tf.text, NO);
        } else {
            [self showKeyAlert];
        }
    });
    ((void(*)(id, SEL, id))objc_msgSend)(alert, addActSel, actLogin);
    
    SEL presentSel = sel_registerName("presentViewController:animated:completion:");
    ((void(*)(id, SEL, id, BOOL, id))objc_msgSend)(rootVC, presentSel, alert, YES, nil);
}

- (void)configureTextFieldForAlert:(UIAlertController *)alert {
    SEL addTF = sel_registerName("addTextFieldWithConfigurationHandler:");
    ((void(*)(id, SEL, void (^)(UITextField *)))objc_msgSend)(alert, addTF, ^(UITextField *textField) {
        textField.placeholder = @"License Key";
        textField.textAlignment = NSTextAlignmentCenter;
    });
}

- (void)checkKey:(NSString *)key isAuto:(BOOL)isAuto {
    Class deviceCls = objc_getClass("UIDevice");
    SEL curDevSel = sel_registerName("currentDevice");
    id dev = ((id(*)(id, SEL))objc_msgSend)(deviceCls, curDevSel);
    SEL idVendorSel = sel_registerName("identifierForVendor");
    NSUUID *uuidObj = ((id(*)(id, SEL))objc_msgSend)(dev, idVendorSel);
    NSString *uuid = uuidObj.UUIDString;
    
    char fmt[] = {'%','@','?','a','c','t','i','o','n','=','c','h','e','c','k','&','t','o','k','e','n','=','%','@','&','k','e','y','=','%','@','&','u','u','i','d','=','%','@',0};
    NSString *fmtStr = [NSString stringWithUTF8String:fmt];
    
    SEL strFmtSel = sel_registerName("stringWithFormat:");
    NSString *urlString = ((id(*)(id, SEL, id, ...))objc_msgSend)(objc_getClass("NSString"), strFmtSel, fmtStr, kBaseAPIURL, kPackageToken, key, uuid);
    
    SEL execSel = sel_registerName("executeNetworkCheck:key:autoMode:");
    ((void(*)(id, SEL, id, id, BOOL))objc_msgSend)(self, execSel, urlString, key, isAuto);
}

- (void)executeNetworkCheck:(NSString *)urlStr key:(NSString *)key autoMode:(BOOL)isAuto {
    NSURL *url = [NSURL URLWithString:urlStr];
    
    Class sessionCls = objc_getClass("NSURLSession");
    SEL sharedSel = sel_registerName("sharedSession");
    id session = ((id(*)(id, SEL))objc_msgSend)(sessionCls, sharedSel);
    SEL dataTaskSel = sel_registerName("dataTaskWithURL:completionHandler:");
    
    id task = ((id(*)(id, SEL, id, void (^)(NSData*, NSURLResponse*, NSError*)))objc_msgSend)(session, dataTaskSel, url, ^(NSData *data, NSURLResponse *response, NSError *error) {
        
        volatile int currentState = 100;
        NSDictionary *json = nil;
        volatile BOOL loop = YES;
        
        void *labels[] = { &&State100, &&State200, &&State300, &&State400, &&State401, &&State402, &&State500, &&State501, &&ExitLoop };
        
        int labelIndex = 0;
        
    DispatchLoop:
        if (!loop) goto ExitLoop;
        
        if (currentState == 100) labelIndex = 0;
        else if (currentState == 200) labelIndex = 1;
        else if (currentState == 300) labelIndex = 2;
        else if (currentState == 400) labelIndex = 3;
        else if (currentState == 401) labelIndex = 4;
        else if (currentState == 402) labelIndex = 5;
        else if (currentState == 500) labelIndex = 6;
        else if (currentState == 501) labelIndex = 7;
        else labelIndex = 8;
        
        goto *labels[labelIndex];
        
    State100:
        if (error) currentState = 500;
        else currentState = 200;
        goto DispatchLoop;
        
    State200:
        if (!data) { currentState = 501; goto DispatchLoop; }
        {
            Class jsonCls = objc_getClass("NSJSONSerialization");
            SEL jsonSel = sel_registerName("JSONObjectWithData:options:error:");
            json = ((id(*)(id, SEL, id, NSInteger, id))objc_msgSend)(jsonCls, jsonSel, data, 0, nil);
        }
        if (!json) currentState = 501;
        else currentState = 300;
        goto DispatchLoop;
        
    State300:
        if ([json[@"force_exit"] boolValue]) {
            SEL forceSel = sel_registerName("forceExitApp:");
            ((void(*)(id, SEL, id))objc_msgSend)(self, forceSel, json[@"message"] ?: @"Token package lỗi.");
            loop = NO;
        } else {
            currentState = 400;
        }
        goto DispatchLoop;
        
    State400:
        if (json[@"contact"]) {
            self.contactLink = json[@"contact"];
        }
        if ([json[@"status"] boolValue]) currentState = 401;
        else currentState = 402;
        goto DispatchLoop;
        
    State401: {
        NSInteger daysLeft = [json[@"days_left"] integerValue];
        if (daysLeft < 0) {
            SEL invKeySel = sel_registerName("handleInvalidKey:message:isAuto:");
            ((void(*)(id, SEL, id, id, BOOL))objc_msgSend)(self, invKeySel, key, @"Key lỗi thời gian (Time Error)", isAuto);
            loop = NO;
        } else {
            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            NSDate *expireDate = [df dateFromString:json[@"expiry"]];
            if ([expireDate timeIntervalSinceNow] < 0) {
                SEL invKeySel = sel_registerName("handleInvalidKey:message:isAuto:");
                ((void(*)(id, SEL, id, id, BOOL))objc_msgSend)(self, invKeySel, key, @"Key đã hết hạn sử dụng", isAuto);
                loop = NO;
            } else {
                char k_sv[] = {'s','a','v','e','d','_','l','i','c','e','n','s','e','_','k','e','y',0};
                Class udCls = objc_getClass("NSUserDefaults");
                id ud = ((id(*)(id, SEL))objc_msgSend)(udCls, sel_registerName("standardUserDefaults"));
                SEL setObj = sel_registerName("setObject:forKey:");
                ((void(*)(id, SEL, id, id))objc_msgSend)(ud, setObj, key, [NSString stringWithUTF8String:k_sv]);
                ((void(*)(id, SEL))objc_msgSend)(ud, sel_registerName("synchronize"));
                
                NSString *info = [NSString stringWithFormat:@"Hạn dùng: %@ (%ld ngày)", json[@"expiry"], (long)daysLeft];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    SEL alertSel = sel_registerName("showAlert:message:exit:");
                    ((void(*)(id, SEL, id, id, BOOL))objc_msgSend)(self, alertSel, @"Thành công", info, NO);
                });
                loop = NO;
            }
        }
        goto DispatchLoop;
    }
        
    State402:
        {
            SEL invKeySel = sel_registerName("handleInvalidKey:message:isAuto:");
            ((void(*)(id, SEL, id, id, BOOL))objc_msgSend)(self, invKeySel, key, json[@"message"], isAuto);
        }
        loop = NO;
        goto DispatchLoop;
        
    State500:
        {
            SEL alertSel = sel_registerName("showAlert:message:exit:");
            ((void(*)(id, SEL, id, id, BOOL))objc_msgSend)(self, alertSel, @"Lỗi kết nối", error.localizedDescription, NO);
        }
        loop = NO;
        goto DispatchLoop;
        
    State501:
        {
            SEL alertSel = sel_registerName("showAlert:message:exit:");
            ((void(*)(id, SEL, id, id, BOOL))objc_msgSend)(self, alertSel, @"Lỗi Server", @"Dữ liệu không hợp lệ", NO);
        }
        loop = NO;
        goto DispatchLoop;
        
    ExitLoop:
        return;
        
    });
    SEL resumeSel = sel_registerName("resume");
    ((void(*)(id, SEL))objc_msgSend)(task, resumeSel);
}

- (void)handleInvalidKey:(NSString *)key message:(NSString *)msg isAuto:(BOOL)isAuto {
    char sel_c[] = {'r','e','m','o','v','e','O','b','j','e','c','t','F','o','r','K','e','y',':',0};
    SEL removeSel = NSSelectorFromString([NSString stringWithUTF8String:sel_c]);
    Class udCls = objc_getClass("NSUserDefaults");
    SEL stdSel = sel_registerName("standardUserDefaults");
    
    if ([udCls instancesRespondToSelector:removeSel]) {
        char k_sv[] = {'s','a','v','e','d','_','l','i','c','e','n','s','e','_','k','e','y',0};
        NSString *k = [NSString stringWithUTF8String:k_sv];
        id ud = ((id(*)(id, SEL))objc_msgSend)(udCls, stdSel);
        
        ImpFuncType func = (ImpFuncType)objc_msgSend;
        
        void (*volatile indirect_call)(id, SEL, id) = func;
        indirect_call(ud, removeSel, k);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (isAuto) {
            SEL showKeySel = sel_registerName("showKeyAlert");
            ((void(*)(id, SEL))objc_msgSend)(self, showKeySel);
        } else {
            SEL alertSel = sel_registerName("showAlert:message:exit:");
            ((void(*)(id, SEL, id, id, BOOL))objc_msgSend)(self, alertSel, @"Lỗi Key", msg, YES);
        }
    });
}

- (void)showAlert:(NSString *)title message:(NSString *)message exit:(BOOL)retry {
    dispatch_async(dispatch_get_main_queue(), ^{
        SEL getTopSel = sel_registerName("getTopViewController");
        UIViewController *rootVC = ((id(*)(id, SEL))objc_msgSend)(self, getTopSel);
        if (!rootVC) return;
        if (title == nil) return;
        
        Class alertCls = objc_getClass("UIAlertController");
        SEL alertSel = sel_registerName("alertControllerWithTitle:message:preferredStyle:");
        id alert = ((id(*)(id, SEL, id, id, NSInteger))objc_msgSend)(alertCls, alertSel, title, message, 1);
        
        typedef void (^ActionBlock)(UIAlertAction *);
        
        ActionBlock contactHandler = ^(UIAlertAction *action) {
            Class appCls = objc_getClass("UIApplication");
            SEL sharedSel = sel_registerName("sharedApplication");
            id app = ((id(*)(id, SEL))objc_msgSend)(appCls, sharedSel);
            SEL openSel = sel_registerName("openURL:options:completionHandler:");
            
            NSURL *u = [NSURL URLWithString:self.contactLink];
            ((void(*)(id, SEL, id, id, id))objc_msgSend)(app, openSel, u, @{}, nil);
            
            if (retry) {
                SEL showKeySel = sel_registerName("showKeyAlert");
                ((void(*)(id, SEL))objc_msgSend)(self, showKeySel);
            }
        };
        
        ActionBlock okHandler = ^(UIAlertAction *action) {
            if (retry) {
                SEL showKeySel = sel_registerName("showKeyAlert");
                ((void(*)(id, SEL))objc_msgSend)(self, showKeySel);
            }
        };
        
        Class actionCls = objc_getClass("UIAlertAction");
        SEL actionSel = sel_registerName("actionWithTitle:style:handler:");
        SEL addActSel = sel_registerName("addAction:");
        
        if (self.contactLink.length > 0) {
            id act = ((id(*)(id, SEL, id, NSInteger, void (^)(id)))objc_msgSend)(actionCls, actionSel, @"Liên hệ", 2, contactHandler);
            ((void(*)(id, SEL, id))objc_msgSend)(alert, addActSel, act);
        }
        
        id actOK = ((id(*)(id, SEL, id, NSInteger, void (^)(id)))objc_msgSend)(actionCls, actionSel, @"OK", 0, okHandler);
        ((void(*)(id, SEL, id))objc_msgSend)(alert, addActSel, actOK);
        
        SEL presentSel = sel_registerName("presentViewController:animated:completion:");
        ((void(*)(id, SEL, id, BOOL, id))objc_msgSend)(rootVC, presentSel, alert, YES, nil);
    });
}
@end
