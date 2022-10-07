//EPoint.h
//Point definitions
//
//Author: Stophin
//2014.01.08
//Ver: 0.01
#ifndef _EPOINT_H_
#define _EPOINT_H_

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include "../platform/ELibrary.h"

#ifdef RUN_DEVICE
#define PLATFORM _device__
#define _PLATFORM __device__
#define __PLATFORM	
#else
#define PLATFORM _inline
#define _PLATFORM 
#define __PLATFORM	
#endif

#include <math.h>

#define MINGW_COMPLIER

#ifdef MINGW_COMPLIER
#define EP_ABS(x) ((x)>=0?(x):(-x))
#else
#define EP_ABS(x) abs(x)
#endif

#define EP_MAX			9999999

#define EP_PI			3.141592654
#define EP_PI_DEGREE	180

//Degree and Radian transformation
#define DEGREE2RADIAN(x) (EFTYPE)(x*EP_PI/EP_PI_DEGREE)
#define RADIAN2DEGREE(x) (EFTYPE)(x*EP_PI_DEGREE/EP_PI)

//Macros for delay using, x must be >=0 and not lager than 0xFF
#define SET_INT16_MAX(x) (((x+1)<<16)+(x+1))
#define GET_INT16_MAX(x) ((x>>16)-1)
#define GET_INT16_NOW(x) (x&0xFF)
#define GET_INT16_MIN(x) ((GET_INT16_NOW(x))==0)
#define RST_INT16_MAX(x) SET_INT16_MAX(GET_INT16_MAX(x))

typedef int                 INT;
typedef float               FLOAT;
typedef unsigned long       DWORD;
typedef DWORD				COLORREF;
typedef double		EPTYPE;
typedef double	EFTYPE;
typedef void	EPVOID;
typedef bool	EBTYPE;

#define EP_ZERO			1e-6

#define EP_GT(a, b)  (((a) > (b)) ? (a) : (b))
#define EP_LT(a, b)  (((a) < (b)) ? (a) : (b))
#define EP_LTZERO(x)	(x < -EP_ZERO)
#define EP_GTZERO(x)	(x > EP_ZERO)
#define EP_ISZERO(x)	(x > -EP_ZERO && x < EP_ZERO)
#define EP_ISZERO_INT(x)	(0 == x)
#define EP_RANGE_INT(x, r) (x > -r && x < r)
#define EP_LEZERO(x)	(EP_LTZERO(x) || EP_ISZERO(x))
#define EP_GEZERO(x)	(EP_GTZERO(x) || EP_ISZERO(x))
#define EP_NTZERO(x)	(!EP_ISZERO(x))


//When judging IsIn
//use these to determinate the type of argument
typedef enum E_RectType
{
	E_RectLtRb,
	E_RectLbRt,
	E_RectLtGm,
	E_RectLbGm,
	E_RectPtRd
}E_RectType;

typedef class EPoint
{
public:
	_PLATFORM EPoint() :
		x(0),
		y(0)
	{
	}

	_PLATFORM EPoint(EPTYPE x, EPTYPE y) :
		x(x),
		y(y)
	{
	}

	_PLATFORM EPoint(const EPoint& p) :
		x(p.x),
		y(p.y)
	{
	}

	_PLATFORM ~EPoint()
	{
	}

	_PLATFORM void Init() {
		x = 0;
		y = 0;
	}

	_PLATFORM const EPoint operator- (const EPoint& pt) const
	{
		return EPoint(x - pt.x, y - pt.y);
	}

	_PLATFORM const EPoint operator+ (const EPoint& pt) const
	{
		return EPoint(x + pt.x, y + pt.y);
	}

	_PLATFORM const EPoint operator* (EPTYPE pa) const
	{
		return EPoint(x*pa, y*pa);
	}

	_PLATFORM EPTYPE operator* (const EPoint& pt) const
	{
		return (x*pt.x + y*pt.y);
	}

	_PLATFORM EPoint& operator= (const EPoint& pt)
	{
		x = pt.x;
		y = pt.y;
		return *this;
	}

	_PLATFORM EPoint& operator+= (const EPoint& pt)
	{
		x += pt.x;
		y += pt.y;
		return *this;
	}

	_PLATFORM EPoint& operator-= (const EPoint& pt)
	{
		x -= pt.x;
		y -= pt.y;
		return *this;
	}

	_PLATFORM EPoint& operator*= (EPTYPE pa)
	{
		x *= pa;
		y *= pa;
		return *this;
	}


	_PLATFORM EPoint& operator/= (EPTYPE pa)
	{
		if (pa == 0)
			pa = 1;
		x /= pa;
		y /= pa;
		return *this;
	}

	_PLATFORM EPoint& operator/= (const EPoint& pt)
	{
		if (pt.x != 0)
			x /= pt.x;
		if (pt.y != 0)
			y /= pt.y;
		return *this;
	}

	_PLATFORM EPoint operator/ (EPTYPE pa)
	{
		if (pa == 0)
			pa = 1;
		return EPoint(x /= pa, y /= pa);
	}

	_PLATFORM bool operator ==(const EPoint& pt) const
	{
		return (x == pt.x) && (y == pt.y);
	}

	_PLATFORM void Set(EPTYPE x, EPTYPE y)
	{
		this->x = x;
		this->y = y;
	}

	void Set(const EPoint& p)
	{
		this->x = p.x;
		this->y = p.y;
	}

	_PLATFORM void Normalize(EPTYPE resize)
	{
		//EFTYPE n=(EFTYPE)sqrt(EFTYPE(x*x+y*y));
		//x=(EPTYPE)((EFTYPE)(x*resize)/n);
		//y=(EPTYPE)((EFTYPE)(y*resize)/n);
		EFTYPE n = (EFTYPE)Q_rsqrt(EFTYPE(x*x + y*y));
		x = (EPTYPE)((EFTYPE)(x*resize)*n);
		y = (EPTYPE)((EFTYPE)(y*resize)*n);
	}

	_PLATFORM bool IsIn(const EPoint& lp, const EPoint& rbgm, E_RectType mode) const
	{
		switch (mode)
		{
		case E_RectLtGm:
		{
						   return x >= lp.x&&y >= lp.y&&x <= lp.x + rbgm.x&&y <= lp.y + rbgm.y;
						   break;
		}
		case E_RectPtRd:	//Judge if a point is in an ellipse
		{
								if (rbgm.x == 0 || rbgm.y == 0)
									return false;
								EPoint vp(x - lp.x, y - lp.y);
								return (vp.x*vp.x) / (rbgm.x*rbgm.x) + (vp.y*vp.y) / (rbgm.y*rbgm.y) <= 1;
		}
			break;
		default:
			return false;
		}
	}

	_PLATFORM bool RectIsIntersect(const EPoint& gm, const EPoint& lp, const EPoint& rbgm, E_RectType mode) const
	{
		EPoint c1p, c2p;
		switch (mode)
		{
		case E_RectLtGm:
			c1p.Set(x + gm.x / 2, y + gm.y / 2);
			c2p.Set(lp.x + rbgm.x / 2, lp.y + rbgm.y / 2);
			break;
		default:
			return false;
		}
		return ((EP_ABS(c1p.x - c2p.x) <= (gm.x / 2 + rbgm.x / 2)) && (EP_ABS(c1p.y - c2p.y) <= (rbgm.y / 2 + gm.y / 2)));
	}

	_PLATFORM static  bool RectIsIntersect(EFTYPE xs, EFTYPE ys, EFTYPE xe, EFTYPE ye, EFTYPE oxs, EFTYPE oys, EFTYPE oxe, EFTYPE oye) {
		EFTYPE gmx = xe - xs, gmy = ye - ys;
		EFTYPE ogmx = oxe - oxs, ogmy = oye - oys;
		EFTYPE cpx = xs + gmx / 2, cpy = ys + gmy / 2;
		EFTYPE ocpx = oxs + ogmx / 2, ocpy = oys + ogmy / 2;
		return ((EP_ABS(cpx - ocpx) <= (gmx / 2 + ogmx / 2)) && (EP_ABS(cpy - ocpy) <= (ogmy / 2 + gmy / 2)));
	}

	_PLATFORM bool RectIsIn(const EPoint& gm, const EPoint& lp, const EPoint& rbgm, E_RectType mode) const
	{
		EPoint c1p, c2p;
		switch (mode)
		{
		case E_RectLtGm:
			return	(x>lp.x&&x<lp.x + rbgm.x) && (y>lp.y&&y<lp.y + rbgm.y) && \
				(x + gm.x>lp.x&&x + gm.x<lp.x + rbgm.x) && (y + gm.y>lp.y&&y + gm.y<lp.y + rbgm.y);
			break;
		default:
			return false;
		}
	}

	_PLATFORM void GeometryCut(const EPoint& geom, const EPoint& objgeom)
	{
		if (x>geom.x - objgeom.x)
			x = geom.x - objgeom.x;
		if (y<objgeom.y)
			y = objgeom.y;
		if (x<0)
			x = 0;
		if (y>geom.y)
			y = geom.y;
	}

	_PLATFORM void GeometryLimit(const EPoint& lp, const EPoint& rbgm, const EPoint& objgm, E_RectType mode)
	{
		switch (mode)
		{
		case E_RectLtGm:
			if (x>lp.x + rbgm.x - objgm.x) x = lp.x + rbgm.x - objgm.x;
			else if (x<lp.x) x = lp.x;
			if (y>lp.y + rbgm.y - objgm.y) y = lp.y + rbgm.y - objgm.y;
			else if (y<lp.y) y = lp.y;
			break;
		default:
			break;
		}
	}

	_PLATFORM EFTYPE GetAngle(const EPoint& p) const
	{
		EPTYPE dx = p.x - x;
		EPTYPE dy = p.y - y;

		if (dx == 0 || dy == 0)
		{
			if (dx == 0)
			{
				if (dy == 0)
					return 0;
				else if (dy>0)
					return DEGREE2RADIAN(90);
				else
					return DEGREE2RADIAN(270);
			}
			if (dy == 0)
			{
				if (dx == 0)
					return 0;
				else if (dx>0)
					return 0;
				else if (dx<0)
					return DEGREE2RADIAN(180);
			}
		}
		EFTYPE arcang = atan((EFTYPE)dy / (EFTYPE)dx);
		if (dx>0)
		{
			if (dy>0)
				return arcang;
			else
				return 2 * EP_PI + arcang;
		}
		else
		{
			return EP_PI + arcang;
		}
	}

	_PLATFORM void Rotate(const EPoint& o, EFTYPE angle)
	{
		*this -= o;
		Rotate(angle);
		*this += o;
	}

	_PLATFORM void Rotate(EFTYPE angle)
	{
		EPTYPE tx, ty;
		tx = x;
		ty = y;

		x = EPTYPE(tx*cos(angle) - ty*sin(angle));
		y = EPTYPE(ty*cos(angle) + tx*sin(angle));
	}

	static _PLATFORM float Q_rsqrt(float number)
	{
		long i;
		float x2, y;
		const float threehalfs = 1.5F;

		x2 = number * 0.5F;
		y = number;
		i = *(long *)&y;              // evil floating point bit level hacking
		i = 0x5f3759df - (i >> 1);               // what the fuck? 
		y = *(float *)&i;
		y = y * (threehalfs - (x2 * y * y));   // 1st iteration
		//	y  = y * ( threehalfs - ( x2 * y * y ) );   // 2nd iteration, this can be removed

		return y;
	}

	EPTYPE x;
	EPTYPE y;


	_PLATFORM int InTriangle(const EPoint& a, const EPoint& b, const EPoint& c) {
		EPoint p(*this);

		float signOfTrig = (b.x - a.x)*(c.y - a.y) - (b.y - a.y)*(c.x - a.x);
		float signOfAB = (b.x - a.x)*(p.y - a.y) - (b.y - a.y)*(p.x - a.x);
		float signOfCA = (a.x - c.x)*(p.y - c.y) - (a.y - c.y)*(p.x - c.x);
		float signOfBC = (c.x - b.x)*(p.y - c.y) - (c.y - b.y)*(p.x - c.x);

		int d1 = (signOfAB * signOfTrig > 0);
		int d2 = (signOfCA * signOfTrig > 0);
		int d3 = (signOfBC * signOfTrig > 0);

		return d1 && d2 && d3;
	}
}EPoint, *PEPoint;

#endif //end of _EPOINT_H_
//end of file
