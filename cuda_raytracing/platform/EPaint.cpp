//EPaint.cpp
//Paint functions
//Varies with GDI tools
//Author: Stophin
//2014.01.08
//Ver: 0.01
//


#include "EPaint.h"

EP_MSG EP_GetKBMsg()
{
	char c = _getch();
	if (c >= 'a' && c <= 'z') {
		c += 'A' - 'a';
	}
	return c;
}

void EP_RenderStart()
{
	BeginBatchDraw();
}

void EP_RenderFlush(INT fps)
{
	FlushBatchDraw();
}

void EP_RenderEnd()
{
	EndBatchDraw();
}

void EP_Refresh()
{
	cleardevice();
}

void EP_Refresh(ECOLOR c)
{
	setbkcolor(c);
}

EPoint EP_Init(EPTYPE wd,EPTYPE ht, INT debug)
{
	EPoint gm(wd,ht);
	if (wd<=0||ht<=0)
	{
		//full screen
 		int scrwd=GetSystemMetrics(SM_CXSCREEN);
		int scrht=GetSystemMetrics(SM_CYSCREEN);
		initgraph(scrwd, scrht);
		HWND hWnd= EP_GetWnd();
		SetWindowLong(hWnd,GWL_STYLE,GetWindowLong(hWnd,GWL_STYLE)-WS_CAPTION);
		SetWindowPos(hWnd,HWND_TOP,0,0,scrwd,scrht,SWP_SHOWWINDOW);
		gm.Set(scrwd,scrht);
	}
	else
	{
		initgraph(wd, ht, debug);
	}
	return gm;
}

void EP_Rectangle(const EPoint& p,const EPoint& w)
{
	rectangle(p.x,p.y-w.y,p.x+w.x,p.y);
}

void EP_Rectangle(const ERectF& p)
{
	rectangle(p.X, p.Y, p.X + p.Width, p.Y + p.Height);
}
void EP_Rectangle(EPTYPE sx,EPTYPE sy,EPTYPE ex,EPTYPE ey)
{
	rectangle(sx,sy,ex,ey);
}

void EP_FillRectangle(EPTYPE sx,EPTYPE sy,EPTYPE ex,EPTYPE ey)
{
}

void EP_InverseRect(const EPoint& lt,const EPoint& gm)
{
	DWORD* dst=EP_GetImageBuffer();
	int width=getwidth();
	int height=getheight();
	int i,j;
	COLORREF c;
	int pxl_idx;
	for (i=lt.x+1;i<lt.x+gm.x;i++)
		for (j=lt.y+1;j<lt.y+gm.y;j++)
		{
			if (i==lt.x+1||j==lt.y+1||i==lt.x+gm.x-1||j==lt.y+gm.y-1)
			{
				if (j>height||i>width)
					continue;
				pxl_idx=j*width+i;
				if (pxl_idx<0||pxl_idx>=width*height)
					break;

			//	COLORREF c=getpixel(i,j);
				c=dst[pxl_idx];
			//	putpixel(i,j,~c);
				dst[pxl_idx]=~c;
			}
	}
}

void EP_Line(const EPoint& s,const EPoint& e)
{
	line(s.x,s.y,e.x,e.y);
}

void EP_Line(EPTYPE sx,EPTYPE sy,EPTYPE ex,EPTYPE ey)
{
	line(sx,sy,ex,ey);
}

void EP_Lines(EPointF * points, int count)
{
	for (int i = 0; i < count - 1; i++)
	{
		EP_Line(points[i].X, points[i].Y, points[i + 1].X, points[i + 1].Y);
	}
}

void EP_SetColor(ECOLOR c)
{
	setbkcolor(c);
}

void EP_SetFillColor(ECOLOR c)
{
	//setfillstyle(1,c);
}

void EP_SetBKColor(ECOLOR c)
{
}

ECOLOR EP_ColorConvert(const EPCHAR * c) {
	ECOLOR col = BLACK;
	if (!strcmp(c, "CYAN")) {
		col = CYAN;
	}
	else if (!strcmp(c, "MAGENTA")) {
		col = MAGENTA;
	}
	else if (!strcmp(c, "BROWN")) {
		col = BROWN;
	}
	else if (!strcmp(c, "LIGHTGRAY")) {
		col = LIGHTGRAY;
	}
	else if (!strcmp(c, "DARKGRAY")) {
		col = DARKGRAY;
	}
	else if (!strcmp(c, "LIGHTBLUE")) {
		col = LIGHTBLUE;
	}
	else if (!strcmp(c, "LIGHTGREEN")) {
		col = LIGHTGREEN;
	}
	else if (!strcmp(c, "LIGHTCYAN")) {
		col = LIGHTCYAN;
	}
	else if (!strcmp(c, "LIGHTRED")) {
		col = LIGHTRED;
	}
	else if (!strcmp(c, "LIGHTMAGENTA")) {
		col = LIGHTMAGENTA;
	}
	else if (!strcmp(c, "YELLOW")) {
		col = YELLOW;
	}
	else if (!strcmp(c, "WHITE")) {
		col = WHITE;
	}
	else if (!strcmp(c, "GREEN")) {
		col = GREEN;
	}
	else if (!strcmp(c, "RED")) {
		col = RED;
	}
	else if (!strcmp(c, "BLUE")) {
		col = BLUE;
	}
	return col;
}

//Load image width file name, and resize
//image				: the image buffer
//fname				: file name
//pwidth&pheight	: Resize to pwidth*pheight, 
//					if pwidth or pheight is less than or equals to 0
//					image will not be resized, and be kept the same
//					with the origin size when loaded.
//					reference symbol '&' means  that this function
//					can change these parameters, so that it can
//					get image size when loaded.
void EP_LoadImage(EIMAGE& image,LPCTSTR fname,EPTYPE& pwidth,EPTYPE& pheight)
{
	//Delete old image and prepare new image
	if (image)
		delete image;
	image = new IMAGE();

	loadimage(image, fname, pwidth, pheight, true);
}


void EP_ResizeImage(EIMAGE& image,EPTYPE& pwidth,EPTYPE& pheight)
{
}

//Truncate picture by color c in itself
//mode: 1: only when current != c then paint
//		2: only when current == c then paint
//		0: all color will be painted
//	other: no response
void EP_TruncImage(EPTYPE x,EPTYPE y,EIMAGE image,ECOLOR c,int mode)
{
}

void EP_TruncateImage(EPTYPE x, EPTYPE y, EPTYPE w, EPTYPE h, EIMAGE image, EPTYPE tx, EPTYPE ty, EPTYPE tw, EPTYPE th, EIMAGE image_bk, INT bk, ECOLOR c)
{
}

//Truncate image with mask image
//mask image is divided by color c ( default to BLACK )
//image will be painted at (x,y)
//(vx,vy) is the offset of destination point from the start point
//(sx,sy) and (ex,ey) is the start and end point of the image
//bk determines using image color (true) or using mask image color (false) to paint
//if cp is passed, then judge whether cp is in drawing point
EPBOOL EP_TruncImage(EPTYPE x, EPTYPE y, EIMAGE image, EIMAGE image_bk, ECOLOR c, EPBOOL bk, const PEPoint cp, int imgtype, EFTYPE rotation, EPTYPE vx, EPTYPE vy, EPTYPE sx, EPTYPE sy, EPTYPE ex, EPTYPE ey)
{
	return false;
}

void EP_SetPixel(EPTYPE x,EPTYPE y,ECOLOR c)
{
	putpixel(x,y,c);
}

ECOLOR EP_GetPixel(EPTYPE x,EPTYPE y,EIMAGE image)
{
	return getpixel(x,y);
}

void EP_CopyImage(EIMAGE& image,EIMAGE source)
{
}

//get image buffer
DWORD* EP_GetImageBuffer(EIMAGE image)
{
	DWORD *ret=NULL;
	if (image!=NULL)
	{
		ret = (DWORD *)GetImageBuffer(image);
	}
	else
	{
		ret=(DWORD *)GetImageBuffer();
	}
	return ret;
}

void EP_PutImage(EPTYPE x,EPTYPE y,EIMAGE image)
{
	putimage(x,y,image);
}

EIMAGE EP_NewImage()
{
	return NULL;
}

void EP_DeleteImage(EIMAGE& image)
{
}

int EP_GetImageWidth(EIMAGE image)
{
	if (image) {
		return image->getwidth();
	}
	return getwidth();
}

int EP_GetImageHeight(EIMAGE image)
{
	if (image) {
		return image->getheight();
	}
	return getheight();
}


int EP_GetTextWidth(EPCHAR& c)
{
	return textwidth(c);
}

void EP_Text(EPTYPE x,EPTYPE y,EPCHAR * c)
{
	outtextxy(x,y,c);
}

//end of file
