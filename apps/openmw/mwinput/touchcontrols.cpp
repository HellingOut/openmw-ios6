#include "touchcontrols.hpp"

#include "inputmanagerimp.hpp"

#include "../mwbase/environment.hpp"
#include "../mwbase/windowmanager.hpp"

#include <MyGUI_Gui.h>
#include <MyGUI_Button.h>
#include <MyGUI_Widget.h>

#include <SDL_gamecontroller.h>

#include <cmath>
#include <cstring>
#include <string>

namespace MWInput
{
    namespace
    {
        // Maximum joystick deflection, as a fraction of the screen (normalised).
        const float kJoystickMaxRadius = 0.18f;
        // Fraction of the screen (by width) that is reserved for the movement joystick.
        const float kMoveRegion = 0.45f;
    }

    TouchControls::TouchControls(InputManager* input)
        : mInput(input)
        , mEnabled(true)
        , mScreenWidth(0)
        , mScreenHeight(0)
        , mWidgetsCreated(false)
        , mWidgetsVisible(false)
        , mMouseFingerId(-1)
    {
        for (int i = 0; i < 2; ++i)
        {
            mJoysticks[i].role = (JoystickRole)i;
            mJoysticks[i].active = false;
            mJoysticks[i].fingerId = -1;
            mJoysticks[i].centerX = 0.f;
            mJoysticks[i].centerY = 0.f;
            mJoysticks[i].x = 0.f;
            mJoysticks[i].y = 0.f;
            mJoysticks[i].base = nullptr;
            mJoysticks[i].knob = nullptr;
        }

        // Action buttons.  Triggers are bound to axes (jump/attack), the rest to
        // buttons, mirroring InputManager::loadControllerDefaults.
        Button b;
        b.pressed = false;
        b.fingerId = -1;
        b.widget = nullptr;

        b.trigger = true;  b.code = SDL_CONTROLLER_AXIS_TRIGGERRIGHT; b.cx = 0.88f; b.cy = 0.80f; b.radius = 0.085f; b.label = "USE";   mButtons.push_back(b);
        b.trigger = true;  b.code = SDL_CONTROLLER_AXIS_TRIGGERLEFT;  b.cx = 0.72f; b.cy = 0.88f; b.radius = 0.075f; b.label = "JUMP";  mButtons.push_back(b);
        b.trigger = false; b.code = SDL_CONTROLLER_BUTTON_A;          b.cx = 0.93f; b.cy = 0.55f; b.radius = 0.055f; b.label = "ACT";   mButtons.push_back(b);
        b.trigger = false; b.code = SDL_CONTROLLER_BUTTON_B;          b.cx = 0.83f; b.cy = 0.55f; b.radius = 0.055f; b.label = "INV";   mButtons.push_back(b);
        b.trigger = false; b.code = SDL_CONTROLLER_BUTTON_START;      b.cx = 0.95f; b.cy = 0.10f; b.radius = 0.055f; b.label = "MENU";  mButtons.push_back(b);
        b.trigger = false; b.code = SDL_CONTROLLER_BUTTON_LEFTSTICK;  b.cx = 0.70f; b.cy = 0.70f; b.radius = 0.050f; b.label = "SNEAK"; mButtons.push_back(b);
        b.trigger = false; b.code = SDL_CONTROLLER_BUTTON_X;          b.cx = 0.80f; b.cy = 0.40f; b.radius = 0.048f; b.label = "WPN";   mButtons.push_back(b);
        b.trigger = false; b.code = SDL_CONTROLLER_BUTTON_Y;          b.cx = 0.90f; b.cy = 0.40f; b.radius = 0.048f; b.label = "SPELL"; mButtons.push_back(b);
    }

    TouchControls::~TouchControls()
    {
        // Widgets are owned by MyGUI and destroyed with the GUI; only drop our pointers.
    }

    void TouchControls::setScreenSize(int width, int height)
    {
        mScreenWidth = width;
        mScreenHeight = height;
    }

    void TouchControls::setEnabled(bool enabled)
    {
        mEnabled = enabled;
    }

    bool TouchControls::isGuiMode() const
    {
        return MWBase::Environment::get().getWindowManager()->isGuiMode();
    }

    void TouchControls::touchDown(int fingerId, float x, float y)
    {
        if (!mEnabled)
            return;

        // In GUI mode the first finger acts as a mouse (tap = click, drag = move).
        if (isGuiMode())
        {
            if (mMouseFingerId < 0)
            {
                mMouseFingerId = fingerId;
                sendMouseMotion(x, y);
                sendMouseButton(x, y, true);
            }
            return;
        }

        // Hit-test the action buttons first.
        for (size_t i = 0; i < mButtons.size(); ++i)
        {
            Button& b = mButtons[i];
            float dx = x - b.cx;
            float dy = y - b.cy;
            if (dx * dx + dy * dy <= b.radius * b.radius)
            {
                b.pressed = true;
                b.fingerId = fingerId;
                sendButton(b, true);
                updateWidgets();
                return;
            }
        }

        // Otherwise assign the finger to a floating joystick.
        if (x < kMoveRegion)
        {
            if (!mJoysticks[Joystick_Move].active)
                startJoystick(Joystick_Move, fingerId, x, y);
        }
        else if (!mJoysticks[Joystick_Look].active)
        {
            startJoystick(Joystick_Look, fingerId, x, y);
        }
        updateWidgets();
    }

    void TouchControls::touchMotion(int fingerId, float x, float y)
    {
        if (!mEnabled)
            return;

        if (isGuiMode())
        {
            if (fingerId == mMouseFingerId)
                sendMouseMotion(x, y);
            return;
        }

        for (int i = 0; i < 2; ++i)
        {
            Joystick& j = mJoysticks[i];
            if (j.active && j.fingerId == fingerId)
            {
                float dx = x - j.centerX;
                float dy = y - j.centerY;
                float len = std::sqrt(dx * dx + dy * dy);
                if (len > kJoystickMaxRadius && len > 0.f)
                {
                    dx = dx / len * kJoystickMaxRadius;
                    dy = dy / len * kJoystickMaxRadius;
                }
                j.x = dx / kJoystickMaxRadius;
                j.y = dy / kJoystickMaxRadius;
                setJoystickAxis(i, j.x, j.y);
                updateWidgets();
                return;
            }
        }
    }

    void TouchControls::touchUp(int fingerId, float x, float y)
    {
        if (!mEnabled)
            return;

        if (isGuiMode() && fingerId == mMouseFingerId)
        {
            sendMouseButton(x, y, false);
            mMouseFingerId = -1;
            return;
        }

        for (size_t i = 0; i < mButtons.size(); ++i)
        {
            Button& b = mButtons[i];
            if (b.pressed && b.fingerId == fingerId)
            {
                b.pressed = false;
                b.fingerId = -1;
                sendButton(b, false);
                updateWidgets();
                return;
            }
        }

        for (int i = 0; i < 2; ++i)
        {
            Joystick& j = mJoysticks[i];
            if (j.active && j.fingerId == fingerId)
            {
                stopJoystick(i);
                updateWidgets();
                return;
            }
        }
    }

    void TouchControls::startJoystick(int role, int fingerId, float x, float y)
    {
        Joystick& j = mJoysticks[role];
        j.active = true;
        j.fingerId = fingerId;
        j.centerX = x;
        j.centerY = y;
        j.x = 0.f;
        j.y = 0.f;
        setJoystickAxis(role, 0.f, 0.f);
    }

    void TouchControls::stopJoystick(int role)
    {
        Joystick& j = mJoysticks[role];
        j.active = false;
        j.fingerId = -1;
        j.x = 0.f;
        j.y = 0.f;
        setJoystickAxis(role, 0.f, 0.f);
    }

    void TouchControls::setJoystickAxis(int role, float x, float y)
    {
        if (role == Joystick_Move)
        {
            sendAxis(SDL_CONTROLLER_AXIS_LEFTX, x);
            sendAxis(SDL_CONTROLLER_AXIS_LEFTY, y);
        }
        else
        {
            sendAxis(SDL_CONTROLLER_AXIS_RIGHTX, x);
            sendAxis(SDL_CONTROLLER_AXIS_RIGHTY, y);
        }
    }

    void TouchControls::sendButton(const Button& b, bool down)
    {
        if (!mInput)
            return;

        if (b.trigger)
        {
            sendAxis(b.code, down ? 1.0f : 0.0f);
            return;
        }

        SDL_ControllerButtonEvent evt;
        std::memset(&evt, 0, sizeof(evt));
        evt.type = down ? SDL_CONTROLLERBUTTONDOWN : SDL_CONTROLLERBUTTONUP;
        evt.which = 1;
        evt.button = (Uint8)b.code;
        evt.state = down ? SDL_PRESSED : SDL_RELEASED;

        if (down)
            mInput->buttonPressed(1, evt);
        else
            mInput->buttonReleased(1, evt);
    }

    void TouchControls::sendAxis(int axis, float value)
    {
        if (!mInput)
            return;

        SDL_ControllerAxisEvent evt;
        std::memset(&evt, 0, sizeof(evt));
        evt.type = SDL_CONTROLLERAXISMOTION;
        evt.which = 1;
        evt.axis = (Uint8)axis;
        float v = value < -1.f ? -1.f : (value > 1.f ? 1.f : value);
        evt.value = (Sint16)(32767.0f * v);
        mInput->axisMoved(1, evt);
    }

    void TouchControls::sendMouseMotion(float x, float y)
    {
        if (!mInput || mScreenWidth <= 0 || mScreenHeight <= 0)
            return;

        SDLUtil::MouseMotionEvent evt;
        std::memset(&evt, 0, sizeof(evt));
        evt.type = SDL_MOUSEMOTION;
        evt.x = (Sint32)(x * mScreenWidth);
        evt.y = (Sint32)(y * mScreenHeight);
        mInput->mouseMoved(evt);
    }

    void TouchControls::sendMouseButton(float x, float y, bool down)
    {
        if (!mInput || mScreenWidth <= 0 || mScreenHeight <= 0)
            return;

        SDL_MouseButtonEvent evt;
        std::memset(&evt, 0, sizeof(evt));
        evt.type = down ? SDL_MOUSEBUTTONDOWN : SDL_MOUSEBUTTONUP;
        evt.button = SDL_BUTTON_LEFT;
        evt.state = down ? SDL_PRESSED : SDL_RELEASED;
        evt.x = (Sint32)(x * mScreenWidth);
        evt.y = (Sint32)(y * mScreenHeight);

        if (down)
            mInput->mousePressed(evt, SDL_BUTTON_LEFT);
        else
            mInput->mouseReleased(evt, SDL_BUTTON_LEFT);
    }

    void TouchControls::createWidgets()
    {
        if (mWidgetsCreated)
            return;
        mWidgetsCreated = true;

        MyGUI::Gui& gui = MyGUI::Gui::getInstance();

        for (size_t i = 0; i < mButtons.size(); ++i)
        {
            Button& b = mButtons[i];
            b.widget = gui.createWidgetReal<MyGUI::Button>("MW_Button",
                b.cx - b.radius, b.cy - b.radius, b.radius * 2.0f, b.radius * 2.0f,
                MyGUI::Align::Default, "Overlay");
            b.widget->setCaption(std::string(b.label));
            b.widget->setAlpha(0.5f);
            b.widget->setVisible(false);
        }

        for (int i = 0; i < 2; ++i)
        {
            Joystick& j = mJoysticks[i];
            j.base = gui.createWidgetReal<MyGUI::Button>("MW_Button", 0.f, 0.f, 0.13f, 0.13f,
                MyGUI::Align::Default, "Overlay");
            j.base->setCaption(std::string());
            j.base->setAlpha(0.35f);
            j.base->setVisible(false);

            j.knob = gui.createWidgetReal<MyGUI::Button>("MW_Button", 0.f, 0.f, 0.06f, 0.06f,
                MyGUI::Align::Default, "Overlay");
            j.knob->setCaption(std::string());
            j.knob->setAlpha(0.55f);
            j.knob->setVisible(false);
        }
    }

    void TouchControls::updateWidgets()
    {
        if (!mWidgetsCreated)
            return;

        for (size_t i = 0; i < mButtons.size(); ++i)
        {
            Button& b = mButtons[i];
            b.widget->setVisible(mWidgetsVisible);
            b.widget->setAlpha(b.pressed ? 0.85f : 0.5f);
        }

        for (int i = 0; i < 2; ++i)
        {
            Joystick& j = mJoysticks[i];
            bool visible = mWidgetsVisible && j.active;
            j.base->setVisible(visible);
            j.knob->setVisible(visible);
            if (j.active)
            {
                j.base->setRealCoord(j.centerX - 0.065f, j.centerY - 0.065f, 0.13f, 0.13f);
                j.knob->setRealCoord(j.centerX + j.x * kJoystickMaxRadius - 0.03f,
                                    j.centerY + j.y * kJoystickMaxRadius - 0.03f, 0.06f, 0.06f);
            }
        }
    }

    void TouchControls::update()
    {
        if (!mWidgetsCreated)
            createWidgets();

        mWidgetsVisible = mEnabled && !isGuiMode();
        updateWidgets();
    }
}
