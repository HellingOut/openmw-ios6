#include "ios_render_scale.hpp"

#include <SDL.h>

#if defined(__IPHONEOS__)

#include <OpenGLES/ES2/gl.h>
#include <QuartzCore/QuartzCore.h>
#include <UIKit/UIKit.h>

#include <SDL_syswm.h>

#include <components/debug/debuglog.hpp>

namespace
{
    // SDL creates a CAEAGLLayer-backed view for its window; touch handling stays in
    // UIKit points, so only the drawable size (and thus the render resolution) changes.
    UIView* findEAGLView(UIView* parent)
    {
        if (parent == nil)
            return nil;

        if ([parent.layer isKindOfClass:[CAEAGLLayer class]])
            return parent;

        for (UIView* subview in parent.subviews)
        {
            UIView* found = findEAGLView(subview);
            if (found != nil)
                return found;
        }

        return nil;
    }
}

float OMW::applyIOSRenderScale(SDL_Window* window, float scale)
{
    if (window == NULL)
        return 0.0f;

    SDL_SysWMinfo wmInfo;
    SDL_VERSION(&wmInfo.version);
    if (!SDL_GetWindowWMInfo(window, &wmInfo) || wmInfo.subsystem != SDL_SYSWM_UIKIT)
        return 0.0f;

    UIWindow* uiWindow = wmInfo.info.uikit.window;
    if (uiWindow == nil)
        return 0.0f;

    UIView* glView = nil;
    if (uiWindow.rootViewController != nil)
        glView = findEAGLView(uiWindow.rootViewController.view);
    if (glView == nil)
        glView = findEAGLView(uiWindow);

    if (glView == nil)
        return 0.0f;

    glView.contentScaleFactor = scale;
    glView.layer.contentsScale = scale;
    [glView setNeedsLayout];

    return static_cast<float>(glView.contentScaleFactor);
}

void OMW::logIOSGLInfo(SDL_Window* window, float appliedScale)
{
    int windowWidth = 0, windowHeight = 0;
    int drawableWidth = 0, drawableHeight = 0;
    if (window != NULL)
    {
        SDL_GetWindowSize(window, &windowWidth, &windowHeight);
        SDL_GL_GetDrawableSize(window, &drawableWidth, &drawableHeight);
    }

    const GLubyte* vendor = glGetString(GL_VENDOR);
    const GLubyte* renderer = glGetString(GL_RENDERER);
    const GLubyte* version = glGetString(GL_VERSION);

    Log(Debug::Info)
        << "[ios] render scale=" << appliedScale
        << " window=" << windowWidth << "x" << windowHeight
        << " drawable=" << drawableWidth << "x" << drawableHeight
        << " vendor=" << (vendor ? reinterpret_cast<const char*>(vendor) : "unknown")
        << " renderer=" << (renderer ? reinterpret_cast<const char*>(renderer) : "unknown")
        << " version=" << (version ? reinterpret_cast<const char*>(version) : "unknown");
}

#else

float OMW::applyIOSRenderScale(SDL_Window*, float)
{
    return 0.0f;
}

void OMW::logIOSGLInfo(SDL_Window*, float)
{
}

#endif
