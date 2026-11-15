#ifndef MWINPUT_TOUCHCONTROLS_H
#define MWINPUT_TOUCHCONTROLS_H

#include <components/sdlutil/events.hpp>

#include <SDL_events.h>

#include <vector>

namespace MyGUI
{
    class Button;
}

namespace MWInput
{
    class InputManager;

    /// \brief On-screen touch controls for iOS.
    ///
    /// Implements a virtual gamepad: a floating movement joystick on the left,
    /// a floating look joystick on the right, and a cluster of action buttons.
    /// Touches are translated into synthetic SDL_GameController button/axis
    /// events (deviceID = 1), which the engine's existing controller bindings
    /// (InputManager::loadControllerDefaults) already map to game actions, so
    /// no binding changes are required.
    ///
    /// In GUI mode the first finger is translated into mouse events instead, so
    /// that menus remain usable (tap = click, drag = move).  A dedicated BACK
    /// button stays visible in every mode and sends Escape, so a window can
    /// always be closed without a hardware keyboard.
    class TouchControls : public SDLUtil::TouchListener
    {
    public:
        explicit TouchControls(InputManager* input);
        virtual ~TouchControls();

        // SDLUtil::TouchListener.  Finger coordinates are normalised (0..1),
        // origin at the top-left corner.
        virtual void touchDown(int fingerId, float x, float y);
        virtual void touchUp(int fingerId, float x, float y);
        virtual void touchMotion(int fingerId, float x, float y);

        /// Screen/window size in pixels (used to convert to mouse coordinates).
        void setScreenSize(int width, int height);
        void setEnabled(bool enabled);

        /// Refresh the overlay visuals; call once per frame.
        void update();

    private:
        enum JoystickRole
        {
            Joystick_Move = 0,
            Joystick_Look = 1
        };

        struct Joystick
        {
            JoystickRole role;
            bool active;
            int fingerId;
            float centerX, centerY; // touch-down point (normalised)
            float x, y;             // current deflection (-1..1)
            MyGUI::Button* base;
            MyGUI::Button* knob;
        };

        struct Button
        {
            int code;       // SDL_ControllerButton, or SDL_ControllerAxis for triggers
            bool trigger;   // true => axis (press/release expressed via axis value)
            float cx, cy;   // normalised centre
            float radius;   // normalised hit-test radius
            const char* label;
            bool pressed;
            int fingerId;
            MyGUI::Button* widget;
            bool isBack;    // true => sends Escape instead of a controller event
        };

        InputManager* mInput;
        bool mEnabled;
        int mScreenWidth;
        int mScreenHeight;
        bool mWidgetsCreated;
        bool mWidgetsVisible;

        Joystick mJoysticks[2];
        std::vector<Button> mButtons;

        int mMouseFingerId; // finger currently driving the GUI mouse (-1 if none)

        void createWidgets();
        void updateWidgets();
        void setOverlayVisible(bool visible);

        void startJoystick(int role, int fingerId, float x, float y);
        void stopJoystick(int role);
        void setJoystickAxis(int role, float x, float y);

        void sendButton(const Button& b, bool down);
        void sendEscape();
        void sendAxis(int axis, float value); // value in -1..1, 0 = centre
        void sendMouseMotion(float x, float y);
        void sendMouseButton(float x, float y, bool down);

        bool isGuiMode() const;
    };
}

#endif
