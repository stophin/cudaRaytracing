//Device.h
//

#ifndef _DEVICE_H_
#define _DEVICE_H_

#include "../math3d/Manager3D.h"

class Device {
public:
	void Init(INT w, INT h) {
		width = w;
		height = h;
		draw_line = -1;//draw thread split line
		draw_oct = -1;//draw oct tree boundaries
		move_light = -1;//moving light mode
		move_trans = -1;//move object in z axis
		render_linear = 1;//render in wire frame
		render_proj = -1;//render projection
		render_light = -1;//render multiple light
		light_count = 0;//light shader count
		render_mirror = -1;//render mirror in rasteration mode
	}

	INT width;
	INT height;

	//EFTYPE *depth;//Depth test buffer
	//DWORD *image;//Image buffer
	//DWORD *tango;//Target buffer
	//DWORD *trans;//Transparent buffer
	//EFTYPE *deptr;//Reflection depth buffer
	//DWORD *miror;//Reflection bufer
	//DWORD *raytracing;//Ray Tracing buffer

	union {
		EFTYPE* float_a[2];
		struct {
			EFTYPE *depth;//Depth test buffer
			//EFTYPE *deptr;//Reflection depth buffer
			EFTYPE *shade[1];//Shade buffer
		};
	};
	union {
		DWORD* dword_a[3];
		struct {
			DWORD *image;//Image buffer
			DWORD *tango;//Target buffer
			DWORD *trans;//Transparent buffer
			//DWORD *miror;//Reflection bufer
			//DWORD *raytracing;//Ray Tracing buffer
		};
	};
	INT threadImageCount;
	DWORD **threadImage;
	INT threadDepthCount;
	EFTYPE **threadDepth;
	INT threadTangoCount;
	DWORD **threadTango;


	INT draw_line;//draw thread split line
	INT draw_oct;//draw oct tree boundaries
	INT move_light;//moving light mode
	INT move_trans;//move object in z axis
	INT render_linear;//render in wire frame
	INT render_proj;//render projection
	INT render_light;//render multiple light
	INT light_count;//light shader count
	INT render_mirror;//render mirror in rasteration mode

	_PLATFORM static int Draw_Line(DWORD* vb_start, int lpitch, int height,
		int x1, int y1, // 起始点
		int x2, int y2, // 终点
		DWORD color // 颜色像素
		) // video buffer and memory pitch
	{

		// this function draws a line from xo,yo to x1,y1 using differential error
		// terms (based on Bresenahams work)

		int dx, // difference in x's
			dy, // difference in y's
			dx2, // dx,dy * 2
			dy2,
			x_inc, // amount in pixel space to move during drawing
			y_inc, // amount in pixel space to move during drawing
			error, // the discriminant i.e. error i.e. decision variable
			index; // used for looping

		// pre-compute first pixel address in video buffer
		//vb_start = vb_start + x1 + y1 * lpitch;

		// compute horizontal and vertical deltas
		dx = x2 - x1;
		dy = y2 - y1;

		// test which direction the line is going in i.e. slope angle
		if (dx >= 0)
		{
			x_inc = 1;

		} // end if line is moving right
		else
		{
			x_inc = -1;
			dx = -dx; // need absolute value

		} // end else moving left

		// test y component of slope

		if (dy >= 0)
		{
			y_inc = lpitch;
		} // end if line is moving down
		else
		{
			y_inc = -lpitch;
			dy = -dy; // need absolute value

		} // end else moving up

		// compute (dx,dy) * 2
		dx2 = dx << 1;
		dy2 = dy << 1;

		// now based on which delta is greater we can draw the line
		if (dx > dy)     //斜率小于1的情况
		{
			// initialize error term
			error = dy2 - dx;

			int ddy = y1 * lpitch, ddx = x1;
			// draw the line
			for (index = 0; index <= dx; index++)
			{
				// set the pixel
				if (ddx >= lpitch) {
					if (ddy >= height * lpitch) {
					}
					else if (ddy <= 0) {
					}
					else {
						vb_start[lpitch - 1 + ddy] = color;
					}
				}
				else if (ddx <= 0) {
					if (ddy >= height * lpitch) {
					}
					else if (ddy <= 0) {
					}
					else {
						vb_start[ddy] = color;
					}
				}
				else if (ddy >= height * lpitch) {
				}
				else if (ddy <= 0) {
				}
				else {
					//*vb_start = color;
					vb_start[ddx + ddy] = color;
				}

				// test if error has overflowed
				if (error >= 0)
				{
					error -= dx2;
					// move to next line
					//vb_start += y_inc;
					ddy += y_inc;
				}
				// adjust the error term
				error += dy2;
				// move to the next pixel
				//vb_start += x_inc;
				ddx += x_inc;
			}
		}
		else   //斜率大于等于1的情况
		{
			// initialize error term
			error = dx2 - dy;

			int ddy = y1 * lpitch, ddx = x1;
			for (index = 0; index <= dy; index++)
			{
				// set the pixel
				if (ddx >= lpitch) {
					if (ddy >= height * lpitch) {
					}
					else if (ddy <= 0) {
					}
					else {
						vb_start[lpitch - 1 + ddy] = color;
					}
				}
				else if (ddx <= 0) {
					if (ddy >= height * lpitch) {
					}
					else if (ddy <= 0) {
					}
					else {
						vb_start[ddy] = color;
					}
				}
				else if (ddy >= height * lpitch) {
				}
				else if (ddy <= 0) {
				}
				else {
					//*vb_start = color;
					vb_start[ddx + ddy] = color;
				}

				// test if error overflowed
				if (error >= 0)
				{
					error -= dy2;//这里按博主推导这里该为error+=dx2-dy2;

					// move to next line
					//vb_start += x_inc;
					ddx += x_inc;

				} // end if error overflowed

				// adjust the error term
				error += dx2;

				// move to the next pixel
				//vb_start += y_inc;
				ddy += y_inc;
			}
		}
		return(1);

	} // end Draw_Line

};



#endif//_DEVICE_H_
