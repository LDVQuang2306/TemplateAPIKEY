#import "HeaderAPI.h"
#import <UIKit/UIKit.h>

@interface LDVQuang : NSObject
@property (nonatomic, strong) NSString *contactLink;
@property (nonatomic, assign) BOOL isMaintenance;
+ (instancetype)sharedInstance;
- (void)startProcess;
@end

@implementation LDVQuang

+ (instancetype)sharedInstance {
    static LDVQuang *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[LDVQuang alloc] init];
        sharedInstance.contactLink = @"";
    });
    return sharedInstance;
}

+ (void)load {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[LDVQuang sharedInstance] startProcess];
    });
}

- (UIViewController *)getTopViewController {
    UIWindow *foundWindow = nil;
    if (@available(iOS 13.0, *)) {
        NSSet *scenes = [[UIApplication sharedApplication] connectedScenes];
        for (UIScene *scene in scenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) { foundWindow = window; break; }
                }
            }
            if (foundWindow) break;
        }
    }
    if (!foundWindow) {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) { foundWindow = window; break; }
        }
    }
    if (!foundWindow) foundWindow = [UIApplication sharedApplication].windows.firstObject;
    return foundWindow.rootViewController;
}

- (void)forceExitApp:(NSString *)reason {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *rootVC = [self getTopViewController];
        if (rootVC) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Lỗi Hệ Thống" 
                                                                           message:reason 
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Thoát" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
                exit(0);
            }]];
            [rootVC presentViewController:alert animated:YES completion:nil];
        } else {
            exit(0);
        }
    });
}

- (void)startProcess {
    NSString *urlString = [NSString stringWithFormat:@"%@?action=init&token=%@", kBaseAPIURL, kPackageToken];
    NSURL *url = [NSURL URLWithString:urlString];
    
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [self forceExitApp:@"Không thể kết nối đến server."];
            return;
        }
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (!json) {
            [self forceExitApp:@"Dữ liệu server không hợp lệ."];
            return;
        }

        if ([json[@"force_exit"] boolValue]) {
            [self forceExitApp:json[@"message"] ?: @"Token package không tồn tại."];
            return;
        }

        if ([json[@"status"] boolValue]) {
            self.contactLink = json[@"contact"];
            self.isMaintenance = [json[@"maintenance"] boolValue];
        } else {
            [self forceExitApp:json[@"message"] ?: @"Lỗi không xác định."];
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.isMaintenance) {
                [self showMaintenanceAlert];
            } else {
                NSString *savedKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"saved_license_key"];
                if (savedKey) {
                    [self checkKey:savedKey isAuto:YES];
                } else {
                    [self showKeyAlert];
                }
            }
        });
    }] resume];
}

- (void)showMaintenanceAlert {
    UIViewController *rootVC = [self getTopViewController];
    if (!rootVC) return;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Bảo Trì" message:@"Hệ thống đang bảo trì." preferredStyle:UIAlertControllerStyleAlert];
    
    if (self.contactLink.length > 0) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Liên hệ" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:self.contactLink] options:@{} completionHandler:nil];
            exit(0);
        }]];
    } else {
         [alert addAction:[UIAlertAction actionWithTitle:@"Thoát" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) { exit(0); }]];
    }
    
    [rootVC presentViewController:alert animated:YES completion:nil];
}

- (void)showKeyAlert {
    UIViewController *rootVC = [self getTopViewController];
    if (!rootVC) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Nhập Key" message:@"Vui lòng nhập key để kích hoạt." preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"License Key";
        textField.textAlignment = NSTextAlignmentCenter;
    }];

    if (self.contactLink.length > 0) {
        UIAlertAction *contactBtn = [UIAlertAction actionWithTitle:@"Contact" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:self.contactLink] options:@{} completionHandler:nil];
            [self showKeyAlert];
        }];
        [alert addAction:contactBtn];
    }
    
    UIAlertAction *activateBtn = [UIAlertAction actionWithTitle:@"Login" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *tf = alert.textFields.firstObject;
        if (tf.text.length > 0) {
            [self checkKey:tf.text isAuto:NO];
        } else {
            [self showKeyAlert];
        }
    }];
    [alert addAction:activateBtn];
    
    [rootVC presentViewController:alert animated:YES completion:nil];
}

- (void)checkKey:(NSString *)key isAuto:(BOOL)isAuto {
    NSString *uuid = [[UIDevice currentDevice] identifierForVendor].UUIDString;
    NSString *urlString = [NSString stringWithFormat:@"%@?action=check&token=%@&key=%@&uuid=%@", kBaseAPIURL, kPackageToken, key, uuid];
    NSURL *url = [NSURL URLWithString:urlString];
    
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [self showAlert:@"Lỗi kết nối" message:error.localizedDescription exit:NO];
            return;
        }
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (!json) {
            [self showAlert:@"Lỗi Server" message:@"Dữ liệu không hợp lệ" exit:NO];
            return;
        }
        
        if ([json[@"force_exit"] boolValue]) {
            [self forceExitApp:json[@"message"] ?: @"Token package lỗi."];
            return;
        }
        
        BOOL status = [json[@"status"] boolValue];
        NSString *msg = json[@"message"];
        NSInteger daysLeft = [json[@"days_left"] integerValue];
        
        if (json[@"contact"]) {
            self.contactLink = json[@"contact"];
        }

        if (status) {
            if (daysLeft < 0) {
                [self handleInvalidKey:key message:@"Key lỗi thời gian (Time Error)" isAuto:isAuto];
                return;
            }
            
            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            NSDate *expireDate = [df dateFromString:json[@"expiry"]];
            if ([expireDate timeIntervalSinceNow] < 0) {
                 [self handleInvalidKey:key message:@"Key đã hết hạn sử dụng" isAuto:isAuto];
                 return;
            }

            [[NSUserDefaults standardUserDefaults] setObject:key forKey:@"saved_license_key"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            NSString *info = [NSString stringWithFormat:@"Hạn dùng: %@ (%ld ngày)", json[@"expiry"], (long)daysLeft];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showAlert:@"Thành công" message:info exit:NO];
            });
        } else {
            [self handleInvalidKey:key message:msg isAuto:isAuto];
        }
    }] resume];
}

- (void)handleInvalidKey:(NSString *)key message:(NSString *)msg isAuto:(BOOL)isAuto {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"saved_license_key"];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (isAuto) {
            [self showKeyAlert];
        } else {
             [self showAlert:@"Lỗi Key" message:msg exit:YES];
        }
    });
}

- (void)showAlert:(NSString *)title message:(NSString *)message exit:(BOOL)retry {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *rootVC = [self getTopViewController];
        if (!rootVC) return;
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        
        if (self.contactLink.length > 0) {
             [alert addAction:[UIAlertAction actionWithTitle:@"Liên hệ" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:self.contactLink] options:@{} completionHandler:nil];
                if (retry) [self showKeyAlert];
            }]];
        }
        
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            if (retry) [self showKeyAlert];
        }]];
        
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

@end