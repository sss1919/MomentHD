//
//  Tweak.x
//  高清朋友圈(独立精简版)
//
//  参照 wchook(悬浮按钮分屏)逆向得出的"高清朋友圈"功能点独立重写,
//  只保留这一项功能,不依赖原插件的任何 UI/配置框架。
//
//  核心思路(逆向自原 dylib 的符号):
//    1) hook 微信 `adjustSizeToStandardForMoments` —— 朋友圈图片"标准化/压缩"入口,
//       跳过它即保留原图。
//    2) hook `shouldCompressLongImage` —— 长图是否压缩,强制否。
//    3) hook `setSkipVideoCompress:` —— 视频跳过压缩,强制是。
//    4) hook `isVideoShouldExportWithoutCompressByAsset:scene:` —— 视频导出不压缩,强制是。
//
//  为了不硬编码类名(跨版本微信兼容),采用"运行时遍历所有类,
//  对自身实现了目标 selector 的类逐个 hook",并为每个被 hook 的类
//  独立保存 orig IMP,避免多类共享 orig 导致崩溃。
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>

// ---- 开关(默认开启) ----
// 用 NSUserDefaults 控制是否启用。键名沿用习惯。
static NSString *const kHDKey = @"com.ylr.hdmoments.enabled";

static BOOL HDOn(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (![d objectForKey:kHDKey]) return YES; // 默认开启
    return [d boolForKey:kHDKey];
}

// ---- per-class orig IMP 存储(多类安全) ----
// 每个 selector 一份字典: className -> NSValue(IMP)
static NSMutableDictionary *gOrigAdj;   // adjustSizeToStandardForMoments
static NSMutableDictionary *gOrigSCL;    // shouldCompressLongImage
static NSMutableDictionary *gOrigSVC;    // setSkipVideoCompress:
static NSMutableDictionary *gOrigIVC;   // isVideoShouldExportWithoutCompressByAsset:scene:

static IMP HDOrig(NSDictionary *dict, id self) {
    NSValue *v = dict[NSStringFromClass(object_getClass(self))];
    return v ? [v pointerValue] : NULL;
}

// 遍历所有类,对"自身定义了该 selector"的类逐个 hook。
// 跳过本 tweak 自己的类,避免自引用。
static void HDHookSelector(SEL sel, IMP newImp, NSMutableDictionary *origDict) {
    unsigned int n = 0;
    Class *classes = objc_copyClassList(&n);
    for (unsigned int i = 0; i < n; i++) {
        Class c = classes[i];
        const char *cn = class_getName(c);
        // 跳过本 tweak 与系统 UI 框架无关类,避免噪音
        if (strstr(cn, "HDMoments")) continue;

        if (!class_respondsToSelector(c, sel)) continue;

        // 只 hook 自己定义了该方法的类(继承的让父类处理),
        // 防止对大量仅继承的子类重复 hook 造成的开销。
        Class sc = class_getSuperclass(c);
        if (sc && class_respondsToSelector(sc, sel)) continue;

        IMP orig = NULL;
        MSHookMessageEx(c, sel, newImp, (void **)&orig);
        if (orig) {
            [origDict setObject:[NSValue valueWithPointer:orig]
                         forKey:NSStringFromClass(c)];
            NSLog(@"[HDMoments] hooked %@ on %s", NSStringFromSelector(sel), cn);
        }
    }
    free(classes);
}

// =====================================================================
// 1) 图片:跳过"标准化尺寸"压缩,保留原图
//    注意:微信该方法的精确签名需 class-dump 确认。
//    这里按"无参、返回处理结果(对象)"的常见形态实现;
//    若你的微信版本签名不同(例如带入参 UIImage*),请按真实签名调整
//    hook 函数的参数与返回类型,否则可能不生效或崩溃。
// =====================================================================
static id HD_adjustSizeToStandardForMoments(id self, SEL _cmd) {
    if (HDOn()) {
        // 跳过标准化 = 保留原图
        return self;
    }
    IMP o = HDOrig(gOrigAdj, self);
    if (o) return ((id (*)(id, SEL))o)(self, _cmd);
    return self;
}

// =====================================================================
// 2) 长图:不压缩
// =====================================================================
static BOOL HD_shouldCompressLongImage(id self, SEL _cmd) {
    if (HDOn()) return NO;
    IMP o = HDOrig(gOrigSCL, self);
    if (o) return ((BOOL (*)(id, SEL))o)(self, _cmd);
    return NO;
}

// =====================================================================
// 3) 视频:跳过压缩
// =====================================================================
static void HD_setSkipVideoCompress(id self, SEL _cmd, BOOL skip) {
    if (HDOn()) skip = YES;
    IMP o = HDOrig(gOrigSVC, self);
    if (o) ((void (*)(id, SEL, BOOL))o)(self, _cmd, skip);
}

// =====================================================================
// 4) 视频导出不压缩
//    微信存在两个变体:…:scene: 与 …:scene:encodeJson:,这里 hook 两参版本。
//    若需要覆盖 encodeJson 变体,可再加一个 hook(签名末尾多一个 BOOL/NSDictionary)。
// =====================================================================
static BOOL HD_isVideoShouldExportWithoutCompress(id self, SEL _cmd, id asset, long scene) {
    if (HDOn()) return YES;
    IMP o = HDOrig(gOrigIVC, self);
    if (o) return ((BOOL (*)(id, SEL, id, long))o)(self, _cmd, asset, scene);
    return YES;
}

// ---- 入口 ----
%ctor {
    @autoreleasepool {
        gOrigAdj = [NSMutableDictionary dictionary];
        gOrigSCL = [NSMutableDictionary dictionary];
        gOrigSVC = [NSMutableDictionary dictionary];
        gOrigIVC = [NSMutableDictionary dictionary];

        // 用 sel_registerName 避免编译器报"未声明的 selector"
        HDHookSelector(sel_registerName("adjustSizeToStandardForMoments"),
                       (IMP)HD_adjustSizeToStandardForMoments, gOrigAdj);
        HDHookSelector(sel_registerName("shouldCompressLongImage"),
                       (IMP)HD_shouldCompressLongImage, gOrigSCL);
        HDHookSelector(sel_registerName("setSkipVideoCompress:"),
                       (IMP)HD_setSkipVideoCompress, gOrigSVC);
        HDHookSelector(sel_registerName("isVideoShouldExportWithoutCompressByAsset:scene:"),
                       (IMP)HD_isVideoShouldExportWithoutCompress, gOrigIVC);

        NSLog(@"[HDMoments] loaded, enabled=%d", HDOn());
    }
}
