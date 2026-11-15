#ifndef OMW_IOS_RENDER_SCALE_H
#define OMW_IOS_RENDER_SCALE_H

struct SDL_Window;

namespace OMW
{
    /// Set the content scale factor of the EAGL view backing the SDL window (iOS only).
    /// A scale of 1.0 renders one drawable pixel per UIKit point (1024x768 on an iPad 4
    /// instead of 2048x1536), 2.0 keeps the native retina resolution.
    /// Returns the scale that was actually applied, or 0.0f on failure (always 0.0f off iOS).
    /// Never logs; the caller is expected to report the result with logIOSGLInfo().
    float applyIOSRenderScale(SDL_Window* window, float scale);

    /// Log the applied render scale, the SDL window/drawable sizes and the GL strings once.
    /// Must only be called while the GL context for \a window is current (no-op off iOS).
    void logIOSGLInfo(SDL_Window* window, float appliedScale);
}

#endif
