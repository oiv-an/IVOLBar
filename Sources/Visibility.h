#import <Foundation/Foundation.h>

BOOL IVVisibilityAvailable(void);
void IVActivateVisibility(NSArray<NSString *> *allowedIdentifiers,
                          void (^completion)(id assertion, NSString *error));
void IVReleaseVisibility(id assertion);
