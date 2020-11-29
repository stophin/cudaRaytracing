//ELibrary.h
//now we're using easyx library tool
//you may change this
//once changed, associated files should be changed
//Author: Stophin
//2014.01.08
//Ver: 0.01
//
#ifndef _ELIBRARY_H_
#define _ELIBRARY_H_

#define _CRT_SECURE_NO_DEPRECATE

#include <easyx.h>

#include <conio.h>

struct EPointF {
	FLOAT X;
	FLOAT Y;
};

struct ERectF {
	FLOAT X;
	FLOAT Y;
	FLOAT Width;
	FLOAT Height;
};

#define EP_GetWnd GetHWnd
#define EP_MouseHit MouseHit
#define EP_MouseMsg MOUSEMSG
#define EP_GetMouseMsg GetMouseMsg

#define EP_IsWheel(msg) (msg.uMsg == WM_MOUSEWHEEL)
#define EP_IsRight(msg) (msg.uMsg == WM_RBUTTONDOWN || msg.uMsg == WM_RBUTTONUP)
#define EP_IsLeft(msg) (msg.uMsg == WM_LBUTTONDOWN || msg.uMsg == WM_LBUTTONUP)
#define EP_IsDown(msg) (msg.uMsg == WM_RBUTTONDOWN || msg.uMsg == WM_LBUTTONDOWN)
#define EP_IsUp(msg) (msg.uMsg == WM_RBUTTONUP || msg.uMsg == WM_LBUTTONUP)
#define EP_IsMove(msg) (msg.uMsg == WM_MOUSEMOVE)
#define EP_Wheel(msg) (msg.wheel)
#define EP_X(msg) (msg.x)
#define EP_Y(msg) (msg.y)

#define EP_KBMsg _kbhit
#define EP_MSG char
EP_MSG EP_GetKBMsg();
#define EP_KBIsUp(msg) (true)
#define EP_KBIsDown(msg) (true)
#define EP_GetKey(msg) (msg)
#define EP_Equal(msg, val) (msg == val)

#define EP_FlushKey()
#define EP_FlushMouse FlushMouseMsgBuffer

#define EP_Delay(ms) 
#define EP_ClearDevice cleardevice

#endif	//end of _ELIBRARY_H_
//end of file
