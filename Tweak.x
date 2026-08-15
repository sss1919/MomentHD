//
//  Tweak.x — MomentHD
//  高清朋友圈图片/视频 — 适配微信 8.0.70 (RootHide/Relaxin Rootless)
//

#import <UIKit/UIKit.h>

// ============================ 前向声明 ============================
@class WCMomentPublishViewController, WCMomentImageUploadHelper, WCMomentVideoCompressHelper;

// ============================ 接口声明 ============================
// 告知编译器继承关系 + %new 方法签名，避免 forward declaration 编译错误

@interface WCMomentPublishViewController : UIViewController
- (void)momentHD_setupHDSwitch;
- (void)momentHD_switchChanged:(UISwitch *)sender;
@end

@interface WCMomentImageUploadHelper : NSObject
- (UIImage *)compressImage:(UIImage *)image quality:(CGFloat)quality;
@end

@interface WCMomentVideoCompressHelper : NSObject
- (id)compressVideo:(id)inputVideo outputPath:(NSString *)outputPath;
@end

// ============================ 持久化存储 ============================

static NSString *const kMomentHDKey = @"MomentHD_HDEnabled";

static BOOL MomentHD_IsEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kMomentHDKey];
}

static void MomentHD_SetEnabled(BOOL enabled) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:enabled forKey:kMomentHDKey];
    [defaults synchronize];
}

// ============================ UI：发布页面底部开关 ============================

%hook WCMomentPublishViewController

- (void)viewDidLoad {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self momentHD_setupHDSwitch];
    });
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    UISwitch *hdSwitch = (UISwitch *)[self.view viewWithTag:19950708];
    if (hdSwitch) {
        [hdSwitch setOn:MomentHD_IsEnabled() animated:YES];
    }
}

%new
- (void)momentHD_setupHDSwitch {
    UIView *rootView = self.view;
    if (!rootView) return;

    // 防止重复添加
    if ([rootView viewWithTag:19950707]) return;

    // ---- 容器视图 ----
    UIView *container = [[UIView alloc] init];
    container.tag = 19950707;
    container.backgroundColor = [UIColor colorWithWhite:0.965 alpha:1.0];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [rootView addSubview:container];

    // ---- 文字标签 ----
    UILabel *label = [[UILabel alloc] init];
    label.text = @"高清朋友圈图片/视频";
    label.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    label.textColor = [UIColor darkTextColor];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:label];

    // ---- 开关 ----
    UISwitch *hdSwitch = [[UISwitch alloc] init];
    hdSwitch.tag = 19950708;
    hdSwitch.on = MomentHD_IsEnabled();
    hdSwitch.onTintColor = [UIColor colorWithRed:0.20 green:0.60 blue:0.97 alpha:1.0];
    hdSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [hdSwitch addTarget:self
                 action:@selector(momentHD_switchChanged:)
       forControlEvents:UIControlEventValueChanged];
    [container addSubview:hdSwitch];

    // ---- 自动布局 ----
    [NSLayoutConstraint activateConstraints:@[
        [container.leadingAnchor  constraintEqualToAnchor:rootView.leadingAnchor],
        [container.trailingAnchor constraintEqualToAnchor:rootView.trailingAnchor],
        [container.bottomAnchor   constraintEqualToAnchor:rootView.safeAreaLayoutGuide.bottomAnchor],
        [container.heightAnchor   constraintEqualToConstant:52],

        [label.leadingAnchor  constraintEqualToAnchor:container.leadingAnchor constant:16],
        [label.centerYAnchor  constraintEqualToAnchor:container.centerYAnchor],
        [label.trailingAnchor constraintEqualToAnchor:hdSwitch.leadingAnchor constant:-12],

        [hdSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-16],
        [hdSwitch.centerYAnchor   constraintEqualToAnchor:container.centerYAnchor],
    ]];

    // 如果有 UITableView，增加底部内边距避免遮挡
    for (UIView *sub in rootView.subviews) {
        if ([sub isKindOfClass:[UITableView class]]) {
            UITableView *tv = (UITableView *)sub;
            UIEdgeInsets inset = tv.contentInset;
            inset.bottom += 52;
            tv.contentInset = inset;
            break;
        }
    }
    if ([rootView isKindOfClass:[UITableView class]]) {
        UITableView *tv = (UITableView *)rootView;
        UIEdgeInsets inset = tv.contentInset;
        inset.bottom += 52;
        tv.contentInset = inset;
    }
}

%new
- (void)momentHD_switchChanged:(UISwitch *)sender {
    MomentHD_SetEnabled(sender.on);
}

%end

// ============================ 图片压缩 Hook ============================

%hook WCMomentImageUploadHelper

// 开关开启 → 返回原图，跳过压缩
// 开关关闭 → 调用原始方法
- (UIImage *)compressImage:(UIImage *)image quality:(CGFloat)quality {
    if (MomentHD_IsEnabled() && image) {
        NSLog(@"[MomentHD] 图片跳过压缩，返回原图");
        return image;
    }
    return %orig;
}

%end

// ============================ 视频压缩 Hook ============================

%hook WCMomentVideoCompressHelper

// 开关开启 → 直接复制原视频文件，跳过转码压缩
// 开关关闭 → 执行原生压缩
- (id)compressVideo:(id)inputVideo outputPath:(NSString *)outputPath {
    if (MomentHD_IsEnabled()) {
        NSString *inputPath = nil;
        if ([inputVideo isKindOfClass:[NSURL class]]) {
            inputPath = [(NSURL *)inputVideo path];
        } else if ([inputVideo isKindOfClass:[NSString class]]) {
            inputPath = (NSString *)inputVideo;
        }

        if (inputPath.length > 0 && outputPath.length > 0) {
            NSFileManager *fm = [NSFileManager defaultManager];
            if ([fm fileExistsAtPath:inputPath]) {
                if ([fm fileExistsAtPath:outputPath]) {
                    [fm removeItemAtPath:outputPath error:nil];
                }
                NSError *copyError = nil;
                if ([fm copyItemAtPath:inputPath toPath:outputPath error:&copyError]) {
                    NSLog(@"[MomentHD] 视频跳过压缩，直接复制: %@", outputPath);
                    return outputPath;
                }
                NSLog(@"[MomentHD] 视频复制失败，回退原生压缩: %@",
                      copyError.localizedDescription);
            }
        }
    }
    return %orig;
}

%end

// ============================ 构造函数 ============================

%ctor {
    NSLog(@"[MomentHD] 已加载 — WeChat 8.0.70 | RootHide/Relaxin Rootless");
}
