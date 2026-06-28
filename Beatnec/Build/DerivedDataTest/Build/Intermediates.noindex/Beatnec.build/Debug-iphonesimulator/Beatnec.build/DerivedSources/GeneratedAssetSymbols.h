#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "music_thumb" asset catalog image resource.
static NSString * const ACImageNameMusicThumb AC_SWIFT_PRIVATE = @"music_thumb";

#undef AC_SWIFT_PRIVATE
