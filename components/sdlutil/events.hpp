#ifndef _SFO_EVENTS_H
#define _SFO_EVENTS_H

#include <SDL_types.h>
#include <SDL_events.h>

////////////
// Events //
////////////

namespace SDLUtil
{

/** Extended mouse event struct where we treat the wheel like an axis, like everyone expects */
struct MouseMotionEvent : SDL_MouseMotionEvent {

    Sint32 zrel;
    Sint32 z;
};


///////////////
// Listeners //
///////////////

class MouseListener
{
public:
    virtual ~MouseListener() {}
    virtual void mouseMoved( const MouseMotionEvent &arg ) = 0;
    virtual void mousePressed( const SDL_MouseButtonEvent &arg, Uint8 id ) = 0;
    virtual void mouseReleased( const SDL_MouseButtonEvent &arg, Uint8 id ) = 0;
    virtual void mouseWheelMoved( const SDL_MouseWheelEvent &arg) = 0;
};

class SensorListener
{
public:
    virtual ~SensorListener() {}
    virtual void sensorUpdated(const SDL_SensorEvent &arg) = 0;
    virtual void displayOrientationChanged() = 0;
};

class KeyListener
{
public:
    virtual ~KeyListener() {}
    virtual void textInput (const SDL_TextInputEvent& arg) {}
    virtual void keyPressed(const SDL_KeyboardEvent &arg) = 0;
    virtual void keyReleased(const SDL_KeyboardEvent &arg) = 0;
};

class ControllerListener
{
public:
    virtual ~ControllerListener() {}
    /** @remarks Joystick button down event */
    virtual void buttonPressed(int deviceID, const SDL_ControllerButtonEvent &evt) = 0;

    /** @remarks Joystick button up event */
    virtual void buttonReleased(int deviceID, const SDL_ControllerButtonEvent &evt) = 0;

    /** @remarks Joystick axis moved event */
    virtual void axisMoved(int deviceID, const SDL_ControllerAxisEvent &arg) = 0;

    /** @remarks Joystick Added **/
    virtual void controllerAdded(int deviceID, const SDL_ControllerDeviceEvent &arg) = 0;

    /** @remarks Joystick Removed **/
    virtual void controllerRemoved(const SDL_ControllerDeviceEvent &arg) = 0;

};

class WindowListener
{
public:
    virtual ~WindowListener() {}

    /** @remarks The window's visibility changed */
    virtual void windowVisibilityChange( bool visible ) {}

    /** @remarks The window got / lost input focus */
    virtual void windowFocusChange( bool have_focus ) {}

    virtual void windowClosed () {}

    virtual void windowResized (int x, int y) {}
};

class TouchListener
{
public:
    virtual ~TouchListener() {}

    /** @remarks A finger touched the screen.  x/y are normalised (0..1), origin top-left. */
    virtual void touchDown(int fingerId, float x, float y) = 0;

    /** @remarks A finger was lifted from the screen. */
    virtual void touchUp(int fingerId, float x, float y) = 0;

    /** @remarks A finger moved across the screen. */
    virtual void touchMotion(int fingerId, float x, float y) = 0;
};

}

#endif
