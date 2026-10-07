#import "Visibility.h"
#import <dlfcn.h>
#import <objc/message.h>

BOOL IVVisibilityAvailable(void) {
    if (!dlopen("/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore", RTLD_NOW | RTLD_LOCAL)) return NO;
    Class config = NSClassFromString(@"MBAssessmentModeConfiguration");
    Class assertion = NSClassFromString(@"MBAssessmentModeAssertion");
    return config && assertion &&
        [config instancesRespondToSelector:NSSelectorFromString(@"initWithAllowedSystemItems:allowedBundleIdentifiers:")] &&
        [assertion instancesRespondToSelector:NSSelectorFromString(@"activateWithConfiguration:completionHandler:")] &&
        [assertion instancesRespondToSelector:NSSelectorFromString(@"invalidate")];
}

void IVReleaseVisibility(id assertion) {
    if (!assertion) return;
    @try {
        ((void (*)(id, SEL))objc_msgSend)(assertion, NSSelectorFromString(@"invalidate"));
    } @catch (NSException *exception) {
        NSLog(@"IVOLBar: release failed: %@", exception.reason);
    }
}

void IVActivateVisibility(NSArray<NSString *> *allowedIdentifiers, void (^completion)(id, NSString *)) {
    if (!IVVisibilityAvailable()) { completion(nil, @"Механизм скрытия недоступен в этой macOS."); return; }
    @try {
        NSMutableArray *systemItems = [NSMutableArray array];
        for (NSInteger i = 0; i < 64; i++) [systemItems addObject:@(i)];
        id config = ((id (*)(id, SEL, id, id))objc_msgSend)(
            [NSClassFromString(@"MBAssessmentModeConfiguration") alloc],
            NSSelectorFromString(@"initWithAllowedSystemItems:allowedBundleIdentifiers:"), systemItems, allowedIdentifiers);
        id assertion = [[NSClassFromString(@"MBAssessmentModeAssertion") alloc] init];
        if (!config || !assertion) { completion(nil, @"Не удалось создать конфигурацию скрытия."); return; }
        ((void (*)(id, SEL, id, void (^)(NSError *)))objc_msgSend)(
            assertion, NSSelectorFromString(@"activateWithConfiguration:completionHandler:"), config,
            ^(NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error) IVReleaseVisibility(assertion);
                    completion(error ? nil : assertion, error.localizedDescription);
                });
            });
    } @catch (NSException *exception) {
        completion(nil, exception.reason ?: @"Ошибка системного механизма скрытия.");
    }
}
