// Vert3D.h
// Define 3D vertex
//

#ifndef _VERT3D_H_
#define _VERT3D_H_

#include "Mat3d.h"

#include "../common/MultiLink.h"

typedef struct Vert3D Vert3D;
struct Vert3D {

	EFTYPE x;
	EFTYPE y;
	EFTYPE z;
	EFTYPE w;

	INT anti;

	_PLATFORM void init() {
		this->x = 0;
		this->y = 0;
		this->z = 0;
		this->w = 1;
	}

	_PLATFORM Vert3D& set(const Vert3D& v) {
		this->x = v.x;
		this->y = v.y;
		this->z = v.z;
		this->w = v.w;

		return *this;
	}

	_PLATFORM Vert3D&  set(EFTYPE x, EFTYPE y, EFTYPE z, EFTYPE w) {
		this->x = x;
		this->y = y;
		this->z = z;
		this->w = w;

		return *this;
	}
	_PLATFORM Vert3D&  set(EFTYPE x, EFTYPE y, EFTYPE z) {
		this->x = x;
		this->y = y;
		this->z = z;

		this->w = 1;

		return *this;
	}


	_PLATFORM Vert3D& operator *(const Mat3D& m) {
		EFTYPE x = this->x, y = this->y, z = this->z, w = this->w;
		this->x = x * m.mx.x + y * m.mx.y + z * m.mx.z + w * m.mx.w;
		this->y = x * m.my.x + y * m.my.y + z * m.my.z + w * m.my.w;
		this->z = x * m.mz.x + y * m.mz.y + z * m.mz.z + w * m.mz.w;
		this->w = x * m.mw.x + y * m.mw.y + z * m.mw.z + w * m.mw.w;

		return *this;
	}

	_PLATFORM Vert3D& operator ^(const Mat3D& m) {
		EFTYPE x = this->x, y = this->y, z = this->z;
		this->x = x * m.mx.x + y * m.mx.y + z * m.mx.z;
		this->y = x * m.my.x + y * m.my.y + z * m.my.z;
		this->z = x * m.mz.x + y * m.mz.y + z * m.mz.z;;

		return *this;
	}

	_PLATFORM Vert3D& operator *(const Vert3D& v) {
		EFTYPE x = this->x, y = this->y, z = this->z, w = this->w;
		this->x = y * v.z - z * v.y;
		this->y = z * v.x - x * v.z;
		this->z = x * v.y - y * v.x;

		return *this;
	}

	_PLATFORM Vert3D& normalize() {
		EFTYPE x = this->x, y = this->y, z = this->z, w = this->w;
		//EFTYPE d = sqrt(x * x + y * y + z * z);
		//this->x /= d;
		//this->y /= d;
		//this->z /= d;
		EFTYPE d = EPoint::Q_rsqrt(x * x + y * y + z * z);
		this->x *= d;
		this->y *= d;
		this->z *= d;

		return *this;
	}

	// module of cross product
	_PLATFORM EFTYPE operator &(const Vert3D& v) const {
		EFTYPE x = this->x, y = this->y, z = this->z, w = this->w;
		//EFTYPE ra = sqrt(x * x + y * y + z * z);
		//EFTYPE rb = sqrt(v.x * v.x + v.y * v.y + v.z * v.z);

		//return (x * v.x + y * v.y + z * v.z) / (ra * rb);
		EFTYPE ra = EPoint::Q_rsqrt(x * x + y * y + z * z);
		EFTYPE rb = EPoint::Q_rsqrt(v.x * v.x + v.y * v.y + v.z * v.z);

		return (x * v.x + y * v.y + z * v.z) * (ra * rb);
	}

	// dot product
	_PLATFORM EFTYPE operator ^(const Vert3D& v) const {
		EFTYPE x = this->x, y = this->y, z = this->z, w = this->w;

		return (x * v.x + y * v.y + z * v.z);
	}

	_PLATFORM Vert3D& operator -(const Vert3D& v) {
		this->x -= v.x;
		this->y -= v.y;
		this->z -= v.z;
		this->w -= v.w;

		return *this;
	}

	_PLATFORM Vert3D& operator +(const Vert3D& v) {
		this->x += v.x;
		this->y += v.y;
		this->z += v.z;
		this->w += v.w;

		return *this;
	}

	_PLATFORM Vert3D& operator *(EFTYPE s) {
		this->x *= s;
		this->y *= s;
		this->z *= s;
		this->w *= s;

		return *this;
	}

	_PLATFORM Vert3D& negative() {
		this->x = -this->x;
		this->y = -this->y;
		this->z = -this->z;
		this->w = -this->w;

		return *this;
	}
	_PLATFORM static bool CrossLine(EFTYPE left, EFTYPE right, EFTYPE y, EFTYPE top, EFTYPE bottom, EFTYPE x)
	{
		//判断一根横线和一根竖线是否交叉
		//横线有三个参数：left, right和y
		//竖线有三个参数：top, bottom和x
		return (top < y) && (bottom > y) && (left < x) && (right > x);
	}
	_PLATFORM static int CrossRect(EFTYPE r1x1, EFTYPE r1x2, EFTYPE r1y1, EFTYPE r1y2,
		EFTYPE r2x1, EFTYPE r2x2, EFTYPE r2y1, EFTYPE r2y2)
	{
		//判断两个矩形是否相交，共8种，横竖交叉
		//从一个矩形中取出一条横线，与另一矩形中的一条竖线判断是否交叉
		return CrossLine(r1x1, r1x2, r1y1, r2y1, r2y2, r2x1)
			|| CrossLine(r1x1, r1x2, r1y1, r2y1, r2y2, r2x2)
			|| CrossLine(r1x1, r1x2, r1y2, r2y1, r2y2, r2x1)
			|| CrossLine(r1x1, r1x2, r1y2, r2y1, r2y2, r2x2)
			|| CrossLine(r2x1, r2x2, r2y1, r1y1, r1y2, r1x1)
			|| CrossLine(r2x1, r2x2, r2y1, r1y1, r1y2, r1x2)
			|| CrossLine(r2x1, r2x2, r2y2, r1y1, r1y2, r1x1)
			|| CrossLine(r2x1, r2x2, r2y2, r1y1, r1y2, r1x2);
	}

	_PLATFORM static INT get_minx(const Vert3D& p1, const Vert3D& p2, const Vert3D& p3) {
		return (INT)(p1.x > p2.x ? (p2.x > p3.x ? p3.x : p2.x) : (p1.x > p3.x ? p3.x : p1.x));
	}
	_PLATFORM static INT get_maxx(const Vert3D& p1, const Vert3D& p2, const Vert3D& p3) {
		return (INT)ceil((p1.x < p2.x ? (p2.x < p3.x ? p3.x : p2.x) : (p1.x < p3.x ? p3.x : p1.x)));
	}
	_PLATFORM static INT get_miny(const Vert3D& p1, const Vert3D& p2, const Vert3D& p3) {
		return (INT)(p1.y > p2.y ? (p2.y > p3.y ? p3.y : p2.y) : (p1.y > p3.y ? p3.y : p1.y));
	}
	_PLATFORM static INT get_maxy(const Vert3D& p1, const Vert3D& p2, const Vert3D& p3) {
		return (INT)ceil((p1.y < p2.y ? (p2.y < p3.y ? p3.y : p2.y) : (p1.y < p3.y ? p3.y : p1.y)));
	}
	_PLATFORM static EFTYPE getZ(const Vert3D& n, EFTYPE x0, EFTYPE y0, EFTYPE z0, EFTYPE x, EFTYPE y) {
		EFTYPE z_1 = 1;
		if (!EP_ISZERO(n.z)) {
			z_1 = 1 / n.z;
		}
		return (-n.x * (x - x0) - n.y * (y - y0)) * z_1 + z0;
	}
	_PLATFORM static EFTYPE getXFromY(const Vert3D& v0, const Vert3D& v1, EFTYPE y) {
		EFTYPE dy_1 = v1.y - v0.y;
		if (!EP_ISZERO(dy_1)) {
			dy_1 = 1 / dy_1;
		}
		else {
			dy_1 = 1;
		}
		return ((y - v0.y) * dy_1) * (v1.x - v0.x) + v0.x;
	}

	_PLATFORM static EFTYPE cross(const Vert3D& a, const Vert3D& b, const Vert3D& p) {
		return (b.x - a.x)*(p.y - a.y) - (b.y - a.y)*(p.x - a.x);
	}

	_PLATFORM static int IsInTriangle(const Vert3D& a, const Vert3D& b, const Vert3D& c, const Vert3D& p) {
		EFTYPE res_ab = cross(a, b, p);
		if (EP_ISZERO(res_ab)) { // in line segment ab
			return 1;
		}
		int res_bc = cross(b, c, p);
		if (EP_ISZERO(res_bc)) { // in line segment bc
			return 2;
		}
		if ((res_ab > 0) != (res_bc > 0)) {
			return 0;
		}
		int res_ca = cross(c, a, p);
		if (EP_ISZERO(res_ca)) { // in line segment ca
			return 3;
		}
		if ((res_ab > 0) != (res_ca > 0)) {
			return 0;
		}
		if (EP_ISZERO(cross(a, b, c))) { // a b c in one line
			return 0;
		}
		return -1;
	}
	_PLATFORM static EFTYPE GetAreaOfTrangle(const Vert3D& va, const Vert3D& vb, const Vert3D& vc, Vert3D* na = NULL, Vert3D* nb = NULL, Vert3D* nc = NULL) {
		EFTYPE area = 0;
		if (NULL == na || NULL == nb || NULL == nc) {
			//S=(1/2)*|(x2-x1)(y3-y1)-(y2-y1)(x3-x1)|
			//=(1/2)*(x1y2+x2y3+x3y1-x1y3-x2y1-x3y2)
			area = (va.x * vb.y + vb.x * vc.y + vc.x * va.y - va.x * vc.y - vb.x * va.y - vc.x * vb.y) * 0.5;
			//area = ((vb.x - va.x) * (vc.y - va.y) - (vb.y - va.y) * (vc.x - va.x)) * 0.5;
		}
		else {
			//n must be normalized and be the pointer of temporary object
			(*na) + va;
			(*nb) + vb;
			(*nc) + vc;
			(*na) * 10;
			(*nb) * 10;
			(*nc) * 10;
			area =  (na->x * nb->y + nb->x * nc->y + nc->x * na->y - na->x * nc->y - nb->x * na->y - nc->x * nb->y) * 0.5;
			//area = ((nb->x - na->x) * (nc->y - na->y) - (nb->y - na->y) * (nc->x - na->x)) * 0.5;
		}
		if (area < 0) {
			area = -area;
		}
		return area;
	}

	_PLATFORM static EFTYPE GetLineIntersectPointWithTriangle(const Vert3D& va, const Vert3D& vb, const Vert3D& vc, const Vert3D& vo, const Vert3D& vd, EFTYPE max, Vert3D& p) {
		EFTYPE beta, rama, tran;
		EFTYPE M, M_1;
		//vo + t * vd = va + beta * (vb - va) + rama * (vc - va)
		//intersect point is in triangle va-vb-vc when beta > 0 and rama > 0 and beta + rama < 1
		//AB = C
		//==>
		//|xa - xb, xa - xc, xd||b|   |xa - xe|
		//|ya - yb, ya - yc, yd||r| = |ya - ye|
		//|za - zb, za - zc, zd||t|   |za - ze|
		//==>
		//|a d g||b|   |j|
		//|b e h||r| = |k|
		//|c f i||t|   |l|
		//Cramer's rule
		//M = |A| = a(ei - hf) + b(gf - di) + c(dh - eg)
		//b =  |xa - xe, xa - xc, xd|
		//     |ya - ye, ya - yc, yd|
		//     |za - ze, za - zc, zd| / |A|
		//==>(j(ei - hf) + k(gf - di) + l(dh - eg)) / M
		//r =  |xa - xb, xa - xe, xd|
		//     |ya - yb, ya - ye, yd|
		//     |za - zb, za - ze, zd| / |A|
		//==>(i(ak - jb) + h(jc - al) + g(bl - kc)) / M
		//t =  |xa - xb, xa - xc, xa - xe|
		//     |ya - yb, ya - yc, ya - ye|
		//     |za - zb, za - zc, za - ze| / |A|
		//==>-(f(ak - jb) + e(jc - al) + d(bl - kc)) / M
		EFTYPE a = va.x - vb.x, b = va.y - vb.y, c = va.z - vb.z;
		//make sure M is not zero
		if (EP_ISZERO(a) && EP_ISZERO(b) && EP_ISZERO(c)) {
			return 0;
		}
		EFTYPE d = va.x - vc.x, e = va.y - vc.y, f = va.z - vc.z;
		EFTYPE g = vd.x, h = vd.y, i = vd.z;
		EFTYPE temp1 = e * i - h * f;
		EFTYPE temp3 = g * f - d * i;
		EFTYPE temp5 = d * h - e * g;
		//make sure M is not zero
		//if (EP_ISZERO(temp1) && EP_ISZERO(temp3) && EP_ISZERO(temp5)) {
		//	return 0;
		//}
		M = a * (temp1)+ b * (temp3)+ c * (temp5);
		if (EP_ISZERO(M)) {
			return 0;
		}
		M_1 = 1.0 / M;

		EFTYPE j = va.x - vo.x, k = va.y - vo.y, l = va.z - vo.z;
		EFTYPE temp2 = a * k - j * b;
		EFTYPE temp4 = j * c - a * l;
		EFTYPE temp6 = b * l - k * c;
		//transport forward
		tran = -(f * (temp2)+ e * (temp4)+ d * (temp6)) * M_1;
		if (tran < 0 || tran > max) {
			return 0;
		}
		//beta > 0 && rama > 0 && beta + rama < 1
		rama = (i * (temp2)+ h * (temp4)+ g * (temp6)) * M_1;
		if (rama <= 0 || rama >= 1) {
			return 0;
		}
		beta = (j * (temp1)+ k * (temp3)+ l * (temp5)) * M_1;
		if (beta <= 0 || beta >= 1 - rama) {
			return 0;
		}
		//set intersected point
		p.set(vd);
		p * tran;
		p + vo;
		p.w = 1;
		return tran;
	}

	_PLATFORM static void GetLine(const Vert3D& v0, const Vert3D& v1, EPoint& p) {
		if (EP_ISZERO(v0.y - v1.y)) {
			p.Set(0, 0);
			//p.Set(0, v1.x);
			return;
		}
		EFTYPE k = (v0.x - v1.x) / (v0.y - v1.y);
		p.Set(k, -k * v1.y + v1.x);
	}
};


#define MAX_VOBJ_LINK	4
typedef struct VObj VObj;
struct VObj {
	__SUPER(MultiLinkElement, VObj, NULL);
	VObj * _prev[MAX_VOBJ_LINK];
	VObj * _next[MAX_VOBJ_LINK];

	/////////////////////////////////////
	Vert3D v;
	Vert3D v_c;
	union {
		Vert3D v_r;
		struct {
			EFTYPE x;
			EFTYPE y;
			EFTYPE z;
			EFTYPE w;
		};
	};
	union {
		Vert3D v_s;
		struct {
			EFTYPE x0;
			EFTYPE y0;
			EFTYPE z0;
			EFTYPE w0;
		};
	};
	Vert3D v_w;
	Vert3D n;
	Vert3D n_w;
	Vert3D n_r;
	Vert3D n_d;
	Vert3D n_z;
	Vert3D n_1_z;

	EFTYPE zz;

	INT ys;
	INT ye;
	INT xs;
	INT xe;

	Mat3D R;
	Mat3D R_r;

	EFTYPE backface;
	INT cut;

	void * obj;

	Vert3D aabb[2];
	/////////////////////////////////////
};
_PLATFORM VObj * _VObj(VObj * that, EFTYPE x, EFTYPE y, EFTYPE z){
	that->prev = that->_prev;
	that->next = that->_next;
	_MultiLinkElement(&that->super, MAX_VOBJ_LINK);

	/////////////////////////////////////
	that->v.set(x, y, z, 1);
	
	that->v_c.init();
	that->v_r.init();
	that->n.init();
	that->n_r.init();
	that->n_d.init();
	that->n_z.init();
	that->n_1_z.init();
	that->v_w.init();
	that->n_w.init();

	that->aabb[0].set(-EP_MAX, -EP_MAX, -EP_MAX, 1);
	that->aabb[1].set(EP_MAX, EP_MAX, EP_MAX, 1);
	/////////////////////////////////////

	return that;
}

/////////////////////////////////////
typedef struct VObjPool VObjPool;
struct VObjPool {
	__SUPER(ElementPool, VObjPool, VObj);
};
_PLATFORM VObj * VObjPool_at(VObjPool * that, int index) {
	return &that->pool[index];
}
_PLATFORM void _VObjPool(VObjPool * that, VObj * pool, UMAP * map, int size){
	_ElementPool(&that->super, (MultiLinkElement*)pool, map, size);

	that->at = VObjPool_at;
}

#define MAX_VOBJ	10000
#define MAP_VOBJ	GET_MAP_SIZE(MAX_VOBJ)
typedef struct VObjPoolImp VObjPoolImp;
struct VObjPoolImp {
	VObj pool[MAX_VOBJ];
	UMAP map[MAP_VOBJ];

	VObjPool vobjPool;
};
_PLATFORM VObjPoolImp * _VObjPoolImp(VObjPoolImp *that) {

	for (int i = 0; i < MAX_VOBJ; i++) {
		_VObj(&that->pool[i], 0, 0, 0);
	}
	_VObjPool(&that->vobjPool, that->pool, that->map, MAX_VOBJ);

	return that;
}
typedef struct VObjMan VObjMan;
struct VObjMan{
	__SUPER(MultiLinkBase, VObjMan, VObj);

	VObjPool * vobjPool;
	
	////////////////////////////
	void (*clearLink)(VObjMan * that);
	////////////////////////////
};
_PLATFORM void VObjMan_clearlink(VObjMan * that){
	if (that->link) {
		VObj * temp = that->link;
		do {
			if (that->removeLink(that, temp) == NULL) {
				break;
			}
			if (!temp->free(temp)) {
				that->vobjPool->back(that->vobjPool, temp);
			}

			temp = that->link;
		} while (temp);
	}
}
_PLATFORM VObjMan * _VObjMan(VObjMan * that, int index, VObjPoolImp * poolImp){
	_MultiLinkBase(&that->super, index);

	that->vobjPool = &poolImp->vobjPool;

	///////////////////////////////////////
	that->clearLink = VObjMan_clearlink;
	///////////////////////////////////////

	return that;
}
/////////////////////////////////////


#endif