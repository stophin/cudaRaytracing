// Matrix3D.h
//

#ifndef _MATRIX_3D_H_
#define _MATRIX_3D_H_

#include "Vert3d.h"


typedef class Matrix3D Matrix3D;
class Matrix3D {
public:
	_PLATFORM Matrix3D() : M(&_M), M_1(&_M_1), mode(0) {
	}
	_PLATFORM Matrix3D(Mat3D * M, Mat3D * M_1, int m) : M(M), M_1(M_1), mode(m) {

	}
	_PLATFORM ~Matrix3D() {

	}

	_PLATFORM void Init() {
		Mm.Init();
		Ms.Init();
		Mrx.Init();
		Mry.Init();
		Mrz.Init();
		Mm_1.Init();
		Ms_1.Init();
		Mrx_1.Init();
		Mry_1.Init();
		Mrz_1.Init();
		mm.Init();
		_M.Init();
		_M_1.Init();
		if (M) {
			M->Init();
		}
		if (M_1) {
			M_1->Init();
		}
	}

	// mode: 1, scale
	// mode: 0, no scale
	int mode;

	Mat3D _M;
	Mat3D _M_1;
	Mat3D *M;
	Mat3D *M_1;

	Mat3D Mm;
	Mat3D Ms;
	Mat3D Mrx;
	Mat3D Mry;
	Mat3D Mrz;
	Mat3D Mm_1;
	Mat3D Ms_1;
	Mat3D Mrx_1;
	Mat3D Mry_1;
	Mat3D Mrz_1;
	Mat3D mm;

	_PLATFORM void scale(EFTYPE sx, EFTYPE sy, EFTYPE sz) {
		this->Ms.mx.x *= sx;
		this->Ms.my.y *= sy;
		this->Ms.mz.z *= sz;

		refresh();
		if (M_1) {
			this->Ms_1.mx.x /= sx;
			this->Ms_1.my.y /= sy;
			this->Ms_1.mz.z /= sz;

			refresh_1();
		}
	}

	_PLATFORM void move(EFTYPE dx, EFTYPE dy, EFTYPE dz) {
		this->Mm.mx.w += dx;
		this->Mm.my.w += dy;
		this->Mm.mz.w += dz;

		/*
		this->mm.setI();
		this->mm.mx.w = dx;
		this->mm.my.w = dy;
		this->mm.mz.w = dz;

		this->M * this->mm;
		*/

		refresh();

		if (M_1) {
			/*
			this->Mm_1.mx.w -= dx;
			this->Mm_1.my.w -= dy;
			this->Mm_1.mz.w -= dz;

			this->mm.set(this->M_1);
			this->M_1.mx.w = -dx;
			this->M_1.my.w = -dy;
			this->M_1.mz.w = -dz;

			this->M_1 * this->mm;
			*/

			/*
			this->mm.mx.w = -dx;
			this->mm.my.w = -dy;
			this->mm.mz.w = -dz;

			this->M_1 * this->mm;
			*/
			this->Mm_1.mx.w -= dx;
			this->Mm_1.my.w -= dy;
			this->Mm_1.mz.w -= dz;

			refresh_1();
		}
	}

	_PLATFORM void rotate(EFTYPE ax, EFTYPE ay, EFTYPE az) {

		/*
		if (!EP_ISZERO(ax)) {
		ax = ax * EP_PI / 180.0;
		EFTYPE sina = sin(ax);
		EFTYPE cosa = cos(ax);

		this->mm.setI();
		this->mm.my.set(0, cosa, -sina);
		this->mm.mz.set(0, sina, cosa);
		this->Mr * this->mm;
		}
		if (!EP_ISZERO(ay)) {
		ay = ay * EP_PI / 180.0;
		EFTYPE sina = sin(ay);
		EFTYPE cosa = cos(ay);

		this->mm.setI();
		this->mm.mx.set(cosa, 0, sina);
		this->mm.mz.set(-sina, 0, cosa);
		this->Mr * this->mm;
		}
		if (!EP_ISZERO(az)) {
		az = az * EP_PI / 180.0;
		EFTYPE sina = sin(az);
		EFTYPE cosa = cos(az);;

		this->mm.setI();
		this->mm.mx.set(cosa, sina, 0);
		this->mm.my.set(sina, cosa, 0);
		this->Mr * this->mm;
		}

		this->M.set(this->Mr) * this->Mm;
		*/
		EFTYPE sinq;
		EFTYPE cosq;
		EFTYPE sina;
		EFTYPE cosa;
		EFTYPE cosqcosa_sinqsina;
		EFTYPE sinqcosa_cosqsina;

		if (!EP_ISZERO(ax)) {
			ax = ax * EP_PI / 180.0;
			sinq = Mrx.mz.y;
			cosq = Mrx.my.y;
			sina = sin(ax);
			cosa = cos(ax);
			cosqcosa_sinqsina = cosq * cosa - sinq * sina;
			sinqcosa_cosqsina = sinq * cosa + cosq * sina;
			Mrx.my.y = cosqcosa_sinqsina;
			Mrx.my.z = -(sinqcosa_cosqsina);
			Mrx.mz.y = sinqcosa_cosqsina;
			Mrx.mz.z = cosqcosa_sinqsina;

			if (M_1) {

				sinq = Mrx_1.mz.y;
				cosq = Mrx_1.my.y;
				cosqcosa_sinqsina = cosq * cosa + sinq * sina;
				sinqcosa_cosqsina = sinq * cosa - cosq * sina;
				Mrx_1.my.y = cosqcosa_sinqsina;
				Mrx_1.my.z = -(sinqcosa_cosqsina);
				Mrx_1.mz.y = sinqcosa_cosqsina;
				Mrx_1.mz.z = cosqcosa_sinqsina;
			}
		}
		if (!EP_ISZERO(ay)) {
			ay = ay * EP_PI / 180.0;
			sinq = Mry.mx.z;
			cosq = Mry.mx.x;
			sina = sin(ay);
			cosa = cos(ay);
			cosqcosa_sinqsina = cosq * cosa - sinq * sina;
			sinqcosa_cosqsina = sinq * cosa + cosq * sina;
			Mry.mx.x = cosqcosa_sinqsina;
			Mry.mx.z = sinqcosa_cosqsina;
			Mry.mz.x = -(sinqcosa_cosqsina);
			Mry.mz.z = cosqcosa_sinqsina;

			if (M_1) {

				sinq = Mry_1.mx.z;
				cosq = Mry_1.mx.x;
				cosqcosa_sinqsina = cosq * cosa + sinq * sina;
				sinqcosa_cosqsina = sinq * cosa - cosq * sina;
				Mry_1.mx.x = cosqcosa_sinqsina;
				Mry_1.mx.z = sinqcosa_cosqsina;
				Mry_1.mz.x = -(sinqcosa_cosqsina);
				Mry_1.mz.z = cosqcosa_sinqsina;
			}
		}
		if (!EP_ISZERO(az)) {
			az = az * EP_PI / 180.0;
			sinq = Mrz.my.x;
			cosq = Mrz.mx.x;
			sina = sin(az);
			cosa = cos(az);
			cosqcosa_sinqsina = cosq * cosa - sinq * sina;
			sinqcosa_cosqsina = sinq * cosa + cosq * sina;
			Mrz.mx.x = cosqcosa_sinqsina;
			Mrz.mx.y = -(sinqcosa_cosqsina);
			Mrz.my.x = sinqcosa_cosqsina;
			Mrz.my.y = cosqcosa_sinqsina;

			if (M_1) {

				sinq = Mrz_1.my.x;
				cosq = Mrz_1.mx.x;
				cosqcosa_sinqsina = cosq * cosa + sinq * sina;
				sinqcosa_cosqsina = sinq * cosa - cosq * sina;
				Mrz_1.mx.x = cosqcosa_sinqsina;
				Mrz_1.mx.y = -(sinqcosa_cosqsina);
				Mrz_1.my.x = sinqcosa_cosqsina;
				Mrz_1.my.y = cosqcosa_sinqsina;
			}
		}


		refresh();
		if (M_1) {
			refresh_1();
		}
	}


	_PLATFORM void refresh() {
		if (mode) {
			(*M).set(Ms) * Mrx * Mry * Mrz * Mm;
		}
		else {
			(*M).set(Mrx) * Mry * Mrz * Mm;
		}
	}
	_PLATFORM void refresh_1() {
		if (mode) {
			(*M_1).set(Mm_1) * Mrz_1 * Mry_1 * Mrx_1 * Ms_1;
		}
		else {
			(*M_1).set(Mm_1) * Mrz_1 * Mry_1 * Mrx_1;
		}
	}
};

#endif