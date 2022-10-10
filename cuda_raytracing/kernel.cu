
#define RUN_DEVICE

//#define WIN_DEBUG
#ifdef WIN_DEBUG
#define DEBUG(Arg, ...) printf(Arg, ##__VA_ARGS__)
#else
#define DEBUG(x, ...)
#endif

#define MAX_PRECISE 100000.0

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include "math3d/Manager3D.h"
#include "math3d/Texture3D.h"
#include "math3d/Texture.h"
#include "platform/Device.h"
#include "raytracing/Ray.h"
#include "common/MultiLink.h"

_PLATFORM Manager3D * dev_man;
_PLATFORM TextureManager * dev_tman;
_PLATFORM VertsMan** dev_vman;
_PLATFORM COLORREF * dev_res;
_PLATFORM EFTYPE * dev_resf;
_PLATFORM Device * _device;
_PLATFORM DWORD * tango;
_PLATFORM EFTYPE * depth;
__device__ int *a;
#define THREAD_W		50
#define THREAD_H		50
#define THREAD_W_R		30
#define THREAD_H_R		30
#define MAX_ITERATOR	THREAD_W_R * THREAD_H_R
#define WIN_WIDTH	800
#define WIN_HEIGHT	600
_PLATFORM Obj3D ** objIterator;
_PLATFORM VertsPoolImp * verts_pool;
_PLATFORM OctPoolImp * octPoolImp;
#ifndef RUN_DEVICE
Manager3D man;
VObjPoolImp vobjPoolImp;
ObjPoolImp objPoolImp;
CamPoolImp camPoolImp;
LgtPoolImp lgtPoolImp;
OctPoolImp _octPoolImp;
Group3DPoolImp group3DPoolImp;
#endif
typedef struct Triangles {
	VObj * v;
	VObj * v0;
	VObj * v1;
};
_PLATFORM Triangles * tgIterator;
Device device;

__global__ void renderRayTracing(EFTYPE * res, INT size, Manager3D * _man, VertsMan** _vman, Triangles * tgIterator, INT grid, INT iteratorW, INT iteratorH, Device * device, VertsPoolImp * vertsPool)
{

#ifdef RUN_DEVICE
	int res_index = 0;

	Manager3D& man = *_man;
	Obj3D * obj = NULL;
	Cam3D * cam = NULL;

	INT iteratorIndex = 0;
	int sx = blockIdx.x * iteratorW;
	int sy = blockIdx.y * iteratorH;
	int line = 0; //block lines
	int ex = blockIdx.x * iteratorW + iteratorW - line;
	int ey = blockIdx.y * iteratorH + iteratorH - line;
	//int tid = blockIdx.x  * blockDim.x + blockIdx.y;
	int tid = blockIdx.x + blockIdx.y * gridDim.x;
	//int tid = threadIdx.x + blockIdx.x * blockDim.x;

	cam = man.cams.link;
	res[99] = (DWORD)cam;
	res[98] = 1000 + tid;
	res[97] = (DWORD)man.octTree.link;
	res[96] = man.octTree.linkcount;
	res[0] = sx;
	res[1] = sy;
	res[2] = ex;
	res[3] = ey;

	Verts vertsTemp;

	Lgt3D * lgt;
	EFTYPE f;
	Vert3D n0, n1, n2, n3, p;
	Vert3D _n0, _n1, _n2, _n3;
	EPoint l1, l0, l;
	EFTYPE z;
	Ray ray;
	INT index;
	EFTYPE _i, _j;
	INT _index;
	DWORD * _raytracing;
	EFTYPE trans;
	if (tid >= device->threadImageCount) {
		//return;
	}
	//DWORD *_image = device->threadImage[tid];
	//memset(_image, 0, sizeof(DWORD)* device->width * device->height);

	VertsPoolImp * pool = &vertsPool[tid];
	memset(pool, 0, sizeof(VertsPoolImp));
	_VertsPoolImp(pool);
	VertsMan& raytracing_verts = *_vman[tid * 2 + 0];
	VertsMan& raytracing_verts_accumulated = *_vman[tid * 2 + 1];
	//VertsMan raytracing_verts;
	//VertsMan* praytracing_verts = NULL;
	//cudaMalloc(&praytracing_verts, sizeof(VertsMan));
	//VertsMan& raytracing_verts = *praytracing_verts;
	_VertsMan(&raytracing_verts, 0, pool);
	////VertsMan raytracing_verts_accumulated;
	//VertsMan* praytracing_verts_accumulated = NULL;
	//cudaMalloc(&praytracing_verts_accumulated, sizeof(VertsMan));
	//VertsMan& raytracing_verts_accumulated = *praytracing_verts_accumulated;
	_VertsMan(&raytracing_verts_accumulated, 1, pool);

	VObjMan * link = NULL;
	ObjMan * olink;
	//MultiLinkList<Obj3D> octs(MAX_OBJ3D_LINK + 1 + id);
	//ObjMan octs;
	DWORD * __image;
	//reflection times
	INT count, shadow_count;
	//for each pixel in width * height's screen
	for (int y = sy; y < ey; y++) {
		for (int x = sx; x < ex; x++) {
			index = y * device->width + x;
			if (index > device->width * device->height) {
				continue;
			}
			//_raytracing = &device->raytracing[index];
			//_raytracing = &_image[index];
			//_raytracing = &device->raytracing[index];
			_raytracing = &device->tango[index];
			//*_raytracing = WHITE;
			//Orthographic
			if (cam->type == 1) {
				//get original vert from this pixel
				n0.set((x - cam->offset_w) / cam->scale_w, (y - cam->offset_h) / cam->scale_h, 0, 1);
				//get direction vert
				n1.set(cam->lookat).negative();
				n1.normalize().negative();
				//set ray
				ray.set(n0, n1);
				//set ray type
				ray.type = 0;
			}
			//Oblique
			else if (cam->type == 2) {
				//get original vert from this pixel
				n0.set(0, 0, 0, 1);
				//get direction vert
				n2.set((x - cam->offset_w) / cam->scale_w, (y - cam->offset_h) / cam->scale_h, 0, 1);
				cam->anti_normalize(cam, n2, cam->znear);
				//n0.set(n2);
				n1.set(cam->lookat) * cam->znear;
				n1 + n2;
				n1.w = 1;
				n1.normalize().negative();
				//set ray
				ray.set(n0, n1);
				//set ray type
				ray.type = 0;
			}

			Verts * nearest_vert_shadow = NULL;
			Lgt3D * cur_lgt = man.lgts.link;
			shadow_count = 0;
			//ray tracing depth
			count = 3;
			do {
				// when the ray is reflection or refraction
				// use the objects around instead of all the objects

				if (0 && (1 == ray.type || 2 == ray.type)) {
					if (!ray.obj) {
						ray.obj = ray.obj;
					}
					//olink = &octs;
					//olink = &man.octs;
					olink->clearLink(olink);
					man.octTree.CollisionA(&man.octTree, man.octTree.link, (Obj3D*)ray.obj, olink);
				}
				else {
					olink = &man.objs;
				}

				Obj3D * obj = olink->link;
				if (obj) {
					int render_state = 0;
					VObj * v, *v0, *v1, *vtemp;

					EFTYPE trans_last = 1000;
					// for each triangle
					do {
						//object aabb intersection
						INT intersection = 1;
						if (&man.objs == olink) {
							//intersection = man.octTree.Collision(&man.octTree, man.octTree.link, ray.original, ray.direction, (Camera3D*)cam, obj);
							intersection = Collision(ray.original, ray.direction, obj, trans_last);
							//intersection = 1;
						}
						if (intersection) {

							// when the ray is reflection
							// then use all the verts instead 
							// of the verts after frustrum culling
							if (1 == ray.type) {
								link = &obj->verts;
							}
							else {
								link = &obj->verts_r;
							}
							v = link->link;
							// more than 3 verts
							if (v && link->linkcount >= 3) {
								v0 = NULL; v1 = NULL;
								int traverseCount = 0;
								do {
									traverseCount++;
									//there must be three verts
									if (v0 && v1) {
										// back face culling
										// when the ray is reflection or shadow testing
										// then do not need back face culling
										if ((v->backface > 0 || v->backface <= 0) || 1 == ray.type || (3 == ray.type && obj->backfaceculling == 0))
										{
											//NOTE: ray tracing is in camera coordinate
											//get intersect point
											trans = Vert3D::GetLineIntersectPointWithTriangle(v->v_c, v0->v_c, v1->v_c, ray.original, ray.direction, trans_last, p);
											//trans = 1;
											//trans is greater than zero, and less than last trans
											if (EP_GTZERO(trans)) {
												//RAYTRACING_MUTEX(Verts * verts = new Verts(););
												//Verts vertsTemp;
												Verts* verts = pool->vertsPool.get(&pool->vertsPool);
#ifdef WIN_DEBUG
												if (verts)
													res[95] = 10000000 + (DWORD)verts;
#endif
												//verts = NULL;
												if (!verts) {
													//verts = verts;
													verts = &vertsTemp;
												}
												if (verts) {
													_Verts(verts);
													trans_last = trans;
													verts->v.set(p);
													verts->trans = trans;
													verts->n_r.set(v->n_r);
													verts->obj = obj;
													if (verts != &vertsTemp)
														raytracing_verts.insertLink(&raytracing_verts, verts, NULL, NULL);
													__image = &verts->color;
													//__image = _raytracing;
													//*__image = RED;

													//shadow test set color to black or white
													//then stop ray tracing
													if (3 == ray.type) {
														*__image = Light3D_multi(ray.color, ray.f / 5);
														verts->type = 0;
														break;
													}
													else {
														n0.set(p);
														n1.set(n0)* cam->M_1;
														//get texture and normal vector at the same time
														*__image = obj->getTextureColor(obj, n0, n1, n2, n3, v, &verts->v_n);

														if (1 == obj->normal_type) {
															//get line formula
															//v0-v1
															Vert3D::GetLine(v1->v_s, v0->v_s, l1);
															//v1-v
															Vert3D::GetLine(v->v_s, v1->v_s, l);
															//v-v0
															Vert3D::GetLine(v0->v_s, v->v_s, l0);
															//get range x
															_n1.set(n0);
															cam->normalize(cam, _n1);
															_n2.set(_n1.x * cam->scale_w + cam->offset_w, _n1.y * cam->scale_h + cam->offset_h, _n1.z);
															EFTYPE __y = _n2.y;
															EFTYPE __x = _n2.x;
															INT _line_l1 = (INT)(l1.x * __y + l1.y);
															INT _line_l = (INT)(l.x * __y + l.y);
															INT _line_l0 = (INT)(l0.x * __y + l0.y);
															INT line_l, line_r;
															INT minx, maxx;
															minx = min(min(v->x0, v0->x0), min(v->x0, v1->x0));
															maxx = max(max(v->x0, v0->x0), max(v->x0, v1->x0));
															if (_line_l1 < minx || _line_l1 > maxx) {
																_line_l1 = 0;
																line_l = min(_line_l, _line_l0);
																line_r = max(_line_l, _line_l0);
															}
															else if (_line_l < minx || _line_l > maxx) {
																_line_l = 0;
																line_l = min(_line_l1, _line_l0);
																line_r = max(_line_l1, _line_l0);
															}
															else if (_line_l0 < minx || _line_l0 > maxx) {
																_line_l0 = 0;
																line_l = min(_line_l1, _line_l);
																line_r = max(_line_l1, _line_l);
															}
															else {
																line_l = min(min(_line_l, _line_l0), min(_line_l1, _line_l0));
																line_r = max(max(_line_l, _line_l0), max(_line_l1, _line_l0));
															}
															//get interpolation normal vector from 3 points of a triangle
															Object3D_GetInterpolationNormalVector(v0, v1, v, __x, __y,
																line_r, line_l, _line_l1, _line_l, _line_l0,
																5, _n0, _n1, _n2, _n3);
															verts->v_3.set(_n0);
														}
														else {
															_n0.set(v->n_r);
															verts->v_3.set(verts->v_n);
														}

														//calculate sumption of light factors
														lgt = man.lgts.link;
														f = 0;
														if (lgt) {
															do {
																f += lgt->getFactor(lgt, _n0, n0);

																if (device->render_light < 0) {
																	break;
																}

																lgt = man.lgts.next(&man.lgts, lgt);
															} while (lgt && lgt != man.lgts.link);
														}


														//normal verts
														if (0 == render_state) {
															*__image = Light3D_multi(*__image, f);
															//set type normal
															verts->type = 0;
														}
														//reflection verts
														else if (1 == render_state) {
															*__image = Light3D_add(*__image, EP_BLACK, f / 2);
															//*__image = Light3D::multi(EP_BLACK, f);
															//set type reflection
															verts->type = 1;
														}
														//transparent verts
														else if (2 == render_state) {
															*__image = Light3D_add(*__image, EP_BLACK, f / 2);
															//*__image = Light3D::multi(EP_BLACK, f);
															//set type transparent
															verts->type = 2;
														}
													}
												}
												//when the ray is reflection,
												//there will be one or two hit point
												//in other case, because of using backface cull,
												//there will be only one hit point
												if (!(1 == ray.type)) {
													break;
												}
											}
										}

										if (obj->vertex_type == 1) {
											v0 = NULL;
											v1 = NULL;
										}
										else if (obj->vertex_type == 2) {
											if ((traverseCount + 1) % 2 == 0) {
												v0 = v;
												//this->v1 = this->v1;
											}
											else {
												v0 = v1;
												v1 = v;
											}
										}
										else {
											v0 = v1;
											v1 = v;
										}
									}
									else if (v0 == NULL) {
										v0 = v;
									}
									else if (v1 == NULL) {
										v1 = v;
									}

									v = link->next(link, v);
								} while (v && v != link->link);
							}
						}

						// use the objects around or all the objects?
						if (&man.objs == olink) {
							//first do objects till end
							//then do reflection and then transparent object
							if (render_state == 0) {
								obj = man.objs.next(&man.objs, obj);
								if (!(obj && obj != man.objs.link)) {
									obj = man.refl.link;
									//next render reflection points
									render_state = 1;
									if (!obj) {
										//or render reflection points
										obj = man.tras.link;
										render_state = 2;
									}
								}
							}
							else if (render_state == 1) {
								obj = man.refl.next(&man.refl, obj);
								if (!(obj && obj != man.refl.link)) {
									obj = man.tras.link;
									//next render transparent points
									render_state = 2;
								}

							}
							else {
								obj = man.tras.next(&man.tras, obj);
								if (!(obj && obj != man.tras.link)) {
									break;
								}
							}
						}
						else {
							obj = olink->next(olink, obj);
							if (!(obj && obj != olink->link)) {
								break;
							}
						}
					} while (obj);
				}
				//make sure all temporary links are cleaned
				if (&man.objs == olink) {
				}
				else {
					olink->clearLink(olink);
				}
				//get the nearest verts from all the ray traced verts
				Verts * verts = raytracing_verts.link;
				Verts * nearest_vert = verts;
				if (verts) {
					do {
						if (verts->trans < nearest_vert->trans) {
							nearest_vert = verts;
						}

						verts = raytracing_verts.next(&raytracing_verts, verts);
					} while (verts && verts != raytracing_verts.link);
				}
				if (nearest_vert) {
					raytracing_verts_accumulated.insertLink(&raytracing_verts_accumulated, nearest_vert, NULL, NULL);
					//RAYTRACING_MUTEX(raytracing_verts.~MultiLinkList(););
					raytracing_verts.clearLink(&raytracing_verts);

					//normal verts
					if (0 == nearest_vert->type) {
						//get shadow test ray
						cur_lgt = man.lgts.link;
						if (cur_lgt) {
							do {
								n2.set(0, 0, 0, 1) * cur_lgt->M *cam->M;
								n2 - nearest_vert->v;
								n2.normalize();
								ray.set(nearest_vert->v, n2);
								//set object
								ray.obj = nearest_vert->obj;
								//set ray type
								ray.type = 3;
								//this color
								ray.color = nearest_vert->color;
								//this factor
								ray.f = cur_lgt->getFactor(cur_lgt, nearest_vert->v_3, nearest_vert->v);

								__image = &nearest_vert->color;

								*__image = ray.color;
								Obj3D * obj = olink->link;
								if (obj) {
									int render_state = 0;
									VObj * v, *v0, *v1, *vtemp;

									EFTYPE trans_last = 1000;
									// for each triangle
									do {
										//object aabb intersection
										INT intersection = 1;
										if (&man.objs == olink) {
											//intersection = man.octTree.Collision(&man.octTree, man.octTree.link, ray.original, ray.direction, (Camera3D*)cam, obj);
											intersection = Collision(ray.original, ray.direction, obj, trans_last);
										}
										if (intersection) {

											// when the ray is reflection
											// then use all the verts instead 
											// of the verts after frustrum culling
											if (1 == ray.type) {
												link = &obj->verts;
											}
											else {
												link = &obj->verts_r;
											}
											v = link->link;
											// more than 3 verts
											if (v && link->linkcount >= 3) {
												v0 = NULL; v1 = NULL;
												int traverseCount = 0;
												do {
													traverseCount++;
													//there must be three verts
													if (v0 && v1) {
														// back face culling
														// when the ray is reflection or shadow testing
														// then do not need back face culling
														if (v->backface > 0 || 1 == ray.type || (3 == ray.type && obj->backfaceculling == 0))
														{
															//NOTE: ray tracing is in camera coordinate
															//get intersect point
															trans = Vert3D::GetLineIntersectPointWithTriangle(v->v_c, v0->v_c, v1->v_c, ray.original, ray.direction, trans_last, p);
															//trans is greater than zero, and less than last trans
															if (EP_GTZERO(trans)) {
																trans_last = trans;
																*__image = Light3D_multi(*__image, ray.f / 5);

																//caustic affect on refraction
																if (render_state == 2) {
																	n0.set(p);
																	n1.set(n0)* cam->M_1;
																	//get texture and normal vector at the same time
																	obj->getTextureColor(obj, n0, n1, n2, n3, v, NULL);

																	if (1 == obj->normal_type) {
																		//get line formula
																		//v0-v1
																		Vert3D::GetLine(v1->v_s, v0->v_s, l1);
																		//v1-v
																		Vert3D::GetLine(v->v_s, v1->v_s, l);
																		//v-v0
																		Vert3D::GetLine(v0->v_s, v->v_s, l0);
																		//get range x
																		_n1.set(n0);
																		cam->normalize(cam, _n1);
																		_n2.set(_n1.x * cam->scale_w + cam->offset_w, _n1.y * cam->scale_h + cam->offset_h, _n1.z);
																		EFTYPE __y = _n2.y;
																		EFTYPE __x = _n2.x;
																		INT _line_l1 = (INT)(l1.x * __y + l1.y);
																		INT _line_l = (INT)(l.x * __y + l.y);
																		INT _line_l0 = (INT)(l0.x * __y + l0.y);
																		INT line_l, line_r;
																		INT minx, maxx;
																		minx = min(min(v->x0, v0->x0), min(v->x0, v1->x0));
																		maxx = max(max(v->x0, v0->x0), max(v->x0, v1->x0));
																		if (_line_l1 < minx || _line_l1 > maxx) {
																			_line_l1 = 0;
																			line_l = min(_line_l, _line_l0);
																			line_r = max(_line_l, _line_l0);
																		}
																		else if (_line_l < minx || _line_l > maxx) {
																			_line_l = 0;
																			line_l = min(_line_l1, _line_l0);
																			line_r = max(_line_l1, _line_l0);
																		}
																		else if (_line_l0 < minx || _line_l0 > maxx) {
																			_line_l0 = 0;
																			line_l = min(_line_l1, _line_l);
																			line_r = max(_line_l1, _line_l);
																		}
																		else {
																			line_l = min(min(_line_l, _line_l0), min(_line_l1, _line_l0));
																			line_r = max(max(_line_l, _line_l0), max(_line_l1, _line_l0));
																		}
																		//get interpolation normal vector from 3 points of a triangle
																		Object3D_GetInterpolationNormalVector(v0, v1, v, __x, __y,
																			line_r, line_l, _line_l1, _line_l, _line_l0,
																			5, _n0, _n1, _n2, _n3);
																	}
																	else {
																		_n0.set(v->n_r);
																	}
																	//get refraction ray
																	// refraction vector
																	//T = ((nL / nT) * N * L - SQRT(1 - (nL^2 / nT ^2)*[1 - (N * L)^2])) * N - (nL / nT) * L
																	//get n3 = N
																	//n3.set(nearest_vert->v_n);
																	n3.set(_n0);// .negative();
																				//get n2 = L
																				//this formula used a negative I
																	n2.set(ray.direction);// .negative();
																						  //get n3 = T
																	EFTYPE cross = n2 ^ n3;
																	//sin(oL) <= nT / nL, that is nT > nL
																	EFTYPE nL = 0.1, nT = 0.5;
																	EFTYPE nL_nT = nL / nT;
																	EFTYPE pN = nL_nT * cross - sqrt(1 - nL_nT * nL_nT * (1 - cross * cross));
																	n3 * pN;
																	n2 * nL_nT;
																	n3 - n2;
																	n3.normalize();

																	EFTYPE f = cur_lgt->getFactor(cur_lgt, n3, p);
																	*__image = Light3D_multi(*__image, f * 5);
																}
																break;
															}
														}

														if (obj->vertex_type == 1) {
															v0 = NULL;
															v1 = NULL;
														}
														else if (obj->vertex_type == 2) {
															if ((traverseCount + 1) % 2 == 0) {
																v0 = v;
																//this->v1 = this->v1;
															}
															else {
																v0 = v1;
																v1 = v;
															}
														}
														else {
															v0 = v1;
															v1 = v;
														}
													}
													else if (v0 == NULL) {
														v0 = v;
													}
													else if (v1 == NULL) {
														v1 = v;
													}

													v = link->next(link, v);
												} while (v && v != link->link);
											}
										}

										// use the objects around or all the objects?
										if (&man.objs == olink) {
											//first do objects till end
											//then do reflection and then transparent object
											if (render_state == 0) {
												obj = man.objs.next(&man.objs, obj);
												if (!(obj && obj != man.objs.link)) {
													obj = man.refl.link;
													//next render reflection points
													render_state = 1;
													if (!obj) {
														//or render reflection points
														obj = man.tras.link;
														render_state = 2;
													}
												}
											}
											else if (render_state == 1) {
												obj = man.refl.next(&man.refl, obj);
												if (!(obj && obj != man.refl.link)) {
													obj = man.tras.link;
													//next render transparent points
													render_state = 2;
												}

											}
											else {
												obj = man.tras.next(&man.tras, obj);
												if (!(obj && obj != man.tras.link)) {
													break;
												}
											}
										}
										else {
											obj = olink->next(olink, obj);
											if (!(obj && obj != olink->link)) {
												break;
											}
										}
									} while (obj);
								}
								if (device->render_light < 0) {
									break;
								}

								cur_lgt = man.lgts.next(&man.lgts, cur_lgt);
							} while (cur_lgt && cur_lgt != man.lgts.link);
						}
						break;
						/*
						if (cur_lgt && (shadow_count == 0 || cur_lgt != man.lgts.link)) {
						n2.set(0, 0, 0, 1) * cur_lgt->M *cam->M;
						n2 - nearest_vert->v;
						n2.normalize();
						ray.set(nearest_vert->v, n2);
						//set object
						ray.obj = nearest_vert->obj;
						//set ray type
						ray.type = 3;
						//this color
						ray.color = nearest_vert->color;
						//this factor
						ray.f = cur_lgt->getFactor(nearest_vert->v_3, nearest_vert->v);
						//test same direction
						//EFTYPE cross = n2 & nearest_vert->v_3;
						//if (cross < 0) {
						//	//not same direction, this vertex is in shadow
						//	nearest_vert->color = Light3D_multi(nearest_vert->color, ray.f / 2);
						//}

						//shadow test does not affect ray tracing times
						count++;

						//get next shadow test light
						shadow_count++;
						nearest_vert_shadow = nearest_vert;
						cur_lgt = man.lgts.next(&man.lgts, cur_lgt);
						}
						else {
						//stop ray tracing
						break;
						}
						*/
					}
					//reflection verts
					else if (1 == nearest_vert->type) {
						//get reflection ray
						// reflection vector
						// R = I -  N * ( dot(I , N)* 2 )
						//get n3 = N
						//n3.set(nearest_vert->v_n);
						n3.set(nearest_vert->v_3);
						//get n2 = I
						n2.set(ray.direction);
						//get n2 = R
						EFTYPE cross = n2 ^ n3;
						n3 * (cross * 2);
						n2 - n3;
						n2.normalize();// .negative();
									   //set ray
						ray.set(nearest_vert->v, n2);
						//set object
						ray.obj = nearest_vert->obj;
						//set ray type
						ray.type = 1;
					}
					//transparent verts
					else if (2 == nearest_vert->type) {
						//get refraction ray
						// refraction vector
						//T = ((nL / nT) * N * L - SQRT(1 - (nL^2 / nT ^2)*[1 - (N * L)^2])) * N - (nL / nT) * L
						//get n3 = N
						//n3.set(nearest_vert->v_n);
						n3.set(nearest_vert->v_3);
						//get n2 = L
						//this formula used a negative I
						n2.set(ray.direction).negative();
						//get n3 = T
						EFTYPE cross = n2 ^ n3;
						//sin(oL) <= nT / nL, that is nT > nL
						EFTYPE nL = 0.1, nT = 0.5;
						EFTYPE nL_nT = nL / nT;
						EFTYPE pN = nL_nT * cross - sqrt(1 - nL_nT * nL_nT * (1 - cross * cross));
						n3 * pN;
						n2 * nL_nT;
						n3 - n2;
						n3.normalize();
						//set ray
						ray.set(nearest_vert->v, n3);
						//set object
						ray.obj = nearest_vert->obj;
						//set ray type
						ray.type = 2;
					}
				}
				else {
					break;
				}

			} while (--count > 0);

			//RAYTRACING_MUTEX(raytracing_verts.~MultiLinkList(););
			raytracing_verts.clearLink(&raytracing_verts);

			//accumulate all the ray traced verts' color
			Verts * verts = raytracing_verts_accumulated.link;
			DWORD color = EP_BLACK;
			if (verts) {
				do {
					//if (0 == verts->type) 
					{
						color = Light3D_add(color, verts->color, 0.1);
					}

					verts = raytracing_verts_accumulated.next(&raytracing_verts_accumulated, verts);
				} while (verts && verts != raytracing_verts_accumulated.link);
			}
			//RAYTRACING_MUTEX(raytracing_verts_accumulated.~MultiLinkList(););
			raytracing_verts_accumulated.clearLink(&raytracing_verts_accumulated);

			*_raytracing = color;
		}
	}
#endif
}

__global__ void initializeKernel(EFTYPE * res, INT size, Manager3D * _man, VObjPoolImp * vobjPoolImp, ObjPoolImp * objPoolImp, CamPoolImp *camPoolImp, LgtPoolImp *lgtPoolImp, TexturePoolImp *textPoolImp, TextureManager *_tman , OctPoolImp * octPoolImp, Group3DPoolImp * group3DPoolImp)
{
#ifdef RUN_DEVICE
	int index = 0;

	TextureManager& tman = *_tman;
	tman.texturePoolImp = textPoolImp;
	tman.Init();
	tman.Reload();

	Manager3D& man = *_man;
	Obj3D * obj = NULL;

	man.vobjPoolImp = vobjPoolImp;
	man.objPoolImp = objPoolImp;
	man.camPoolImp = camPoolImp;
	man.lgtPoolImp = lgtPoolImp;
	man.octPoolImp = octPoolImp;
	man.group3DPoolImp = group3DPoolImp;
	_VObjPoolImp(vobjPoolImp);
	_ObjPoolImp(objPoolImp, vobjPoolImp);
	_CamPoolImp(camPoolImp);
	_LgtPoolImp(lgtPoolImp);
	_VObjPoolImp(vobjPoolImp);
	_OctPoolImp(octPoolImp, objPoolImp, vobjPoolImp);
	_Group3DPoolImp(group3DPoolImp, objPoolImp, vobjPoolImp);
	man.Init();
	Camera3D * cam = &man.addCamera(50, 50, 50, 1000, 70, 70);
	man.setCameraRange(500, 240, 126, 126);
	cam->_move(cam, 0, 0, -200);

	man.addLight(9, 100, 300);

	Object3D *_obj = &man.addObject();
	_obj->addVert(_obj, -10, -10, 10).addVert(_obj, 10, -10, 10).addVert(_obj, -10, 10, 10).addVertA(_obj, 10, 10, 10, -1)._scale(_obj, 5, 5, 5)
		._move(_obj, 0, 100, -200).setColor(_obj, GREEN).setTexture(_obj, tman, 1, 0).setUV(_obj, 0, 0);
	_obj = &man.addObject();
	_obj->addVert(_obj, -10,0,-10).addVert(_obj, 10, 0, -10).addVert(_obj, -10, 0, 10).addVertA(_obj, 10, 0, 10, -1)._rotate(_obj, 0, 0, 180)
		._scale(_obj, 5, 5, 5)._move(_obj, 250, -40, 250).setColor(_obj, LIGHTGRAY);

	_obj = &man.addObject();
	_obj->addVert(_obj, -10, -10, 10).addVert(_obj, 10, -10, 10).addVert(_obj, -10, 10, 10).addVertA(_obj, 10, 10, 10, -1)._scale(_obj, 5, 5, 5)
		._move(_obj, 0, 100, -100).setColor(_obj, GREEN).setTexture(_obj, tman, 1, 0).setUV(_obj, 0, 0);

	_obj = &man.addObject();
	_obj->addVert(_obj, -10, -10, 10).addVert(_obj, 10, -10, 10).addVert(_obj, -10, 10, 10).addVertA(_obj, 10, 10, 10, -1)._scale(_obj, 5, 5, 5)
		._move(_obj, 0, 100, -0).setColor(_obj, GREEN).setTexture(_obj, tman, 1, 0).setUV(_obj, 0, 0);

	_obj = &man.addObject();
	_obj->addVert(_obj, -10, -10, 10).addVert(_obj, 10, -10, 10).addVert(_obj, -10, 10, 10).addVertA(_obj, 10, 10, 10, -1)._scale(_obj, 5, 5, 5)
		._move(_obj, 0, 100, 100).setColor(_obj, GREEN).setTexture(_obj, tman, 1, 0).setUV(_obj, 0, 0);

	man.initialized = 1;


#ifdef WIN_DEBUG
	
	if (cam) {
		//res[index++] = (DWORD)cam;
		//res[index++] = (DWORD)&man.camTemp;

		res[index++] = cam->M.mx.x + cam->M.mx.y + cam->M.mx.z + cam->M.mx.w + cam->M.my.x + cam->M.my.y + cam->M.my.z + cam->M.my.w;
		res[index++] = cam->_M.Ms.mx.x + cam->_M.Ms.mx.y + cam->_M.Ms.mx.z + cam->_M.Ms.mx.w + cam->_M.Ms.my.x + cam->_M.Ms.my.y + cam->_M.Ms.my.z + cam->_M.Ms.my.w;
		res[index++] = cam->_M.M->mx.x + cam->_M.M->mx.y + cam->_M.M->mx.z + cam->_M.M->mx.w + cam->_M.M->my.x + cam->_M.M->my.y + cam->_M.M->my.z + cam->_M.M->my.w;
		res[index++] = cam->_M.Mm.mx.x + cam->_M.Mm.mx.y + cam->_M.Mm.mx.z + cam->_M.Mm.mx.w + cam->_M.Mm.my.x + cam->_M.Mm.my.y + cam->_M.Mm.my.z + cam->_M.Mm.my.w;
		res[index++] = cam->_M.Mrx.mx.x + cam->_M.Mrx.mx.y + cam->_M.Mrx.mx.z + cam->_M.Mrx.mx.w + cam->_M.Mrx.my.x + cam->_M.Mrx.my.y + cam->_M.Mrx.my.z + cam->_M.Mrx.my.w;
	}

	obj = (Obj3D*)_obj;
	if (obj) {
		res[index++] = obj->M.mx.x + obj->M.mx.y + obj->M.mx.z + obj->M.mx.w + obj->M.my.x + obj->M.my.y + obj->M.my.z + obj->M.my.w;
		res[index++] = obj->_M.Ms.mx.x + obj->_M.Ms.mx.y + obj->_M.Ms.mx.z + obj->_M.Ms.mx.w + obj->_M.Ms.my.x + obj->_M.Ms.my.y + obj->_M.Ms.my.z + obj->_M.Ms.my.w;
		res[index++] = obj->_M.M->mx.x + obj->_M.M->mx.y + obj->_M.M->mx.z + obj->_M.M->mx.w + obj->_M.M->my.x + obj->_M.M->my.y + obj->_M.M->my.z + obj->_M.M->my.w;
		res[index++] = obj->_M.Mm.mx.x + obj->_M.Mm.mx.y + obj->_M.Mm.mx.z + obj->_M.Mm.mx.w + obj->_M.Mm.my.x + obj->_M.Mm.my.y + obj->_M.Mm.my.z + obj->_M.Mm.my.w;
		res[index++] = obj->_M.Mrx.mx.x + obj->_M.Mrx.mx.y + obj->_M.Mrx.mx.z + obj->_M.Mrx.mx.w + obj->_M.Mrx.my.x + obj->_M.Mrx.my.y + obj->_M.Mrx.my.z + obj->_M.Mrx.my.w;
	}

	res[index++] = 111111;
	res[index++] = (DWORD)&man;
	res[index++] = man.initialized;
	res[index++] = man.objs.linkcount;
	res[index++] = (DWORD)man.objs.link;
	res[index++] = 111111;

	obj = man.objs.link;
	if (obj) {
		do {

			VObj * v = obj->verts.link;
			res[index++] = (DWORD)obj;
			res[index++] = (DWORD)obj->verts.link;
			if (v) {
				do {

					res[index++] = v->v.x;
					res[index++] = v->v.y;
					res[index++] = v->v.z;
					res[index++] = v->v.w;

					v = obj->verts.next(&obj->verts, v);
				} while (v && v != obj->verts.link);
			}

			obj = man.objs.next(&man.objs, obj);
		} while (obj && obj != man.objs.link);
	}
#endif
#endif
}

// Helper function for using CUDA
cudaError_t initializeWithCuda(EFTYPE * res, int res_size, Manager3D * man)
{
	cudaError_t cudaStatus;

	DWORD** threadImage = NULL;
	TextureLocalManager tman;
	TextureLocalPoolImp textPool;
	_TextureLocalPoolImp(&textPool);
	tman.texturePoolImp = &textPool;
	tman.Init();
	INT tid = tman.addTexture(64, 64, 8);
	fprintf(stderr, "added texture: %d", tid);
	tid = tman.addTexture("image/1.jpg");
	fprintf(stderr, "added texture: %d", tid);

	// Allocate GPU buffers of objects
	// alloc golbal symbols
	///////////////////////////////////////
	//int *tmp;
	//cudaMalloc((void **)&tmp, sizeof(int)* 10);
	//cudaMemcpyToSymbol(a, &tmp, sizeof(int *), size_t(0), cudaMemcpyHostToDevice);
	//Manager3D * dev_man_temp;

	cudaStatus = cudaMalloc(&octPoolImp, sizeof(OctPoolImp));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc OctPoolImp failed!");
		goto Error;
	}

	Group3DPoolImp * group3DPoolImp;
	cudaStatus = cudaMalloc(&group3DPoolImp, sizeof(Group3DPoolImp));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc Group3DPoolImp failed!");
		goto Error2_1;
	}

	//int verts_pool_count = 0;
	//VertsPoolImp ** _verts_pool = new VertsPoolImp*[THREAD_W * THREAD_H];
	//for (int i = 0; i < THREAD_W * THREAD_H; i++) {
	//	cudaStatus = cudaMalloc((void**)&_verts_pool[i], sizeof(VertsPoolImp));
	//	if (cudaStatus != cudaSuccess) {
	//		fprintf(stderr, "cudaMalloc failed!%s\n", cudaGetErrorString(cudaStatus));
	//		goto Error_1;
	//	}
	//	verts_pool_count ++;
	//}
	//cudaStatus = cudaMalloc((void**)&verts_pool, sizeof(VertsPoolImp*) * THREAD_W * THREAD_H);
	//if (cudaStatus != cudaSuccess) {
	//	fprintf(stderr, "cudaMalloc failed!%s\n", cudaGetErrorString(cudaStatus));
	//	goto Error_1;
	//}
	//cudaStatus = cudaMemcpy(verts_pool, _verts_pool, sizeof(VertsPoolImp*) * THREAD_W * THREAD_H, cudaMemcpyHostToDevice);
	//if (cudaStatus != cudaSuccess) {
	//	fprintf(stderr, "cudaMemcpy failed for verts_pool: %s", cudaGetErrorString(cudaStatus));
	//	goto Error_1;
	//}
	cudaStatus = cudaMalloc((void**)&verts_pool, sizeof(VertsPoolImp) * THREAD_W * THREAD_H);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed for verts_pool: %s", cudaGetErrorString(cudaStatus));
		goto Error_1;
	}

	cudaStatus = cudaMalloc((void**)&dev_man, sizeof(Manager3D));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error;
	}
	//cudaStatus = cudaMemcpyToSymbol(dev_man, &dev_man_temp, sizeof(dev_man_temp), size_t(0), cudaMemcpyHostToDevice);
	//if (cudaStatus != cudaSuccess) {
	//	fprintf(stderr, "cudaMemcpyToSymbol failed!");
	//	goto Error;
	//}

	cudaMemset((void*)&dev_man->initialized, 0, 4);//sizeof(int) = 4 * sizeof(byte)
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error1;
	}
	
	//Texture
	cudaStatus = cudaMalloc((void**)&dev_tman, sizeof(TextureManager));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed for texture!");
		goto Error1;
	}
	TexturePoolImp *textPoolImp;
	cudaStatus = cudaMalloc(&textPoolImp, sizeof(TexturePoolImp));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed for texture poll!");
		goto Error1_1;
	}
	//verts
	cudaStatus = cudaMalloc((void**)&dev_vman, sizeof(VertsMan*) * THREAD_W * THREAD_H * 2);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed for verts!");
		goto Error1_2;
	}
	int vman_count = 0;
	VertsMan** vman = new VertsMan*[THREAD_W * THREAD_H * 2];
	for (int i = 0; i < THREAD_W * THREAD_H * 2; i++) {
		cudaStatus = cudaMalloc((void**)&vman[i], sizeof(VertsMan));
		if (cudaStatus != cudaSuccess) {
			fprintf(stderr, "cudaMalloc failed for verts!");
			goto Error1_3;
		}
		vman_count++;
	}
	cudaStatus = cudaMemcpy(dev_vman, vman, sizeof(VertsMan*) * THREAD_W * THREAD_H * 2, cudaMemcpyHostToDevice);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed for verts (%s)!", cudaGetErrorString(cudaStatus));
		goto Error1_3;
	}

	//make pool copy
	TextureLocalPoolImp textPoolBackup;
	//memcpy(&textPoolBackup, &textPool, sizeof(TextureLocalPoolImp));
	for (int i = 0; i < MAX_TEXTURELOCAL; i++) {
		textPoolBackup.pool[i].texture = NULL;
	}
	//texture copy
	for (int i = 0; i < MAX_TEXTURELOCAL; i++) {
		TextureLocal *textLocal = &textPool.pool[i];
		if (!textLocal) {
			continue;
		}
		if (textLocal->texture != NULL && textLocal->width > 0 && textLocal->height > 0) {
			fprintf(stderr, "copying texture %d: width: %d, height: %d, p: %p", i, textLocal->width, textLocal->height, textLocal->texture);
			DWORD * texture;
			cudaStatus = cudaMalloc(&texture, sizeof(DWORD)* textLocal->width * textLocal->height);
			if (cudaStatus != cudaSuccess) {
				fprintf(stderr, "cudaMalloc failed for texture %d!", i);
				break;
			}
			fprintf(stderr, "got dev p: %p", texture);
			cudaStatus = cudaMemcpy(texture, textLocal->texture,  sizeof(DWORD)* textLocal->width * textLocal->height, cudaMemcpyHostToDevice);
			if (cudaStatus != cudaSuccess) {
				fprintf(stderr, "cudaMemcpy failed for texture p: %p", texture);
				break;
			}
			//change texture pointer
			textPoolBackup.pool[i].texture = texture;
			textPoolBackup.pool[i].width = textLocal->width;
			textPoolBackup.pool[i].height = textLocal->height;
			textPoolBackup.pool[i].uniqueID = textLocal->uniqueID;
		}

	}
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed for texture!");
		goto Error1_5;
	}
	//make suer TexturePoolImp and TextureLocalPoolImp are same size
	if (sizeof(TexturePoolImp) != sizeof(TextureLocalPoolImp)) {
		fprintf(stderr, "TexturePoolImp and TextureLocalPoolImp are not the same size!");
		goto Error1_5;
	}
	//texture pool copy
	cudaStatus = cudaMemcpy(textPoolImp, &textPoolBackup, sizeof(TexturePoolImp), cudaMemcpyHostToDevice);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed for texture pool!");
		goto Error1_5;
	}


	VObjPoolImp *vobjPoolImp;
	cudaStatus = cudaMalloc(&vobjPoolImp, sizeof(VObjPoolImp));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error2;
	}
	ObjPoolImp *objPoolImp;
	cudaStatus = cudaMalloc(&objPoolImp, sizeof(ObjPoolImp));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error3;
	}
	CamPoolImp *camPoolImp;
	cudaStatus = cudaMalloc(&camPoolImp, sizeof(CamPoolImp));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error4;
	}
	LgtPoolImp *lgtPoolImp;
	cudaStatus = cudaMalloc(&lgtPoolImp, sizeof(LgtPoolImp));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error5;
	}
	cudaStatus = cudaMalloc((void**)&dev_res, sizeof(DWORD)* res_size);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error6;
	}
	cudaStatus = cudaMalloc((void**)&dev_resf, sizeof(EFTYPE)* res_size);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error7;
	}
	cudaStatus = cudaMalloc((void**)&objIterator, sizeof(Obj3D*)* MAX_ITERATOR);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error8;
	}
	cudaStatus = cudaMalloc((void**)&tgIterator, sizeof(Triangles)* MAX_ITERATOR);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error9;
	}
	cudaStatus = cudaMalloc((void**)&_device, sizeof(Device));
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error10;
	}
	device.Init(WIN_WIDTH, WIN_HEIGHT);
	for (int i = 0; i < 2; i++) {
		cudaStatus = cudaMalloc((void**)&device.float_a[i], sizeof(EFTYPE)* device.width * device.height);
		if (cudaStatus != cudaSuccess) {
			fprintf(stderr, "cudaMalloc failed!");
			goto Error11;
		}
	}
	for (int i = 0; i < 3; i++) {
		cudaStatus = cudaMalloc((void**)&device.dword_a[i], sizeof(DWORD)* device.width * device.height);
		if (cudaStatus != cudaSuccess) {
			fprintf(stderr, "cudaMalloc failed!");
			goto Error12;
		}
	}
	cudaStatus = cudaMalloc((void**)&device.threadImage, sizeof(DWORD*)* MAX_ITERATOR);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMalloc failed!");
		goto Error13;
	}
	threadImage = new DWORD*[MAX_ITERATOR];
	device.threadImageCount = 0;
	for (int i = 0; i < MAX_ITERATOR; i++) {
		cudaStatus = cudaMalloc((void**)&threadImage[i], sizeof(DWORD)* device.width * device.height);
		if (cudaStatus != cudaSuccess) {
			fprintf(stderr, "cudaMalloc failed!");
			goto Error14;
		}
		device.threadImageCount++;
	}
	cudaStatus = cudaMemcpy(device.threadImage, threadImage, sizeof(DWORD*)* MAX_ITERATOR, cudaMemcpyHostToDevice);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error14;
	}
	cudaStatus = cudaMemcpy(_device, &device, sizeof(Device), cudaMemcpyHostToDevice);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error14;
	}
	tango = device.tango;
	depth = device.depth;

	cudaStatus = cudaMemset(dev_resf, 0, sizeof(EFTYPE)* res_size);
	if (cudaStatus != cudaStatus) {
		fprintf(stderr, "cudaMemset failed!");
		goto Error14;
	}
	///////////////////////////////////////

	//核函数参数：
	//<<<块并行数，线程并行数，每个块使用的共享内存大小，流对象>>>
	// Launch a kernel on the GPU with one thread for each element.
	initializeKernel << <1, 1 >> > (dev_resf, res_size, dev_man, vobjPoolImp, objPoolImp, camPoolImp, lgtPoolImp, textPoolImp, dev_tman, octPoolImp, group3DPoolImp);

	// Check for any errors launching the kernel
	cudaStatus = cudaGetLastError();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "initializeKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
		goto Error14;
	}

	// cudaDeviceSynchronize waits for the kernel to finish, and returns
	// any errors encountered during the launch.
	cudaStatus = cudaDeviceSynchronize();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching initializeKernel!\n", cudaStatus);
		fprintf(stderr, "initializeKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
		goto Error14;
	}

#ifdef WIN_DEBUG
	///////////////////////////////////////
	// Copy output vector from GPU buffer to host memory.
	cudaStatus = cudaMemcpy(res, dev_resf, res_size * sizeof(EFTYPE), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error14;
	}
	///////////////////////////////////////
	DEBUG("初始化:");
	for (int i = 0; i < MAX_ITERATOR; i++) {
		DEBUG("%.2f->", res[i]);
	}
	DEBUG("\n");
#endif

	goto Error;
	///////////////////////////////////////
Error14:
	for (int i = 0; threadImage && i < device.threadImageCount && i < MAX_ITERATOR; i++) {
		if (threadImage[i]) {
			cudaFree(threadImage[i]);
		}
	}
Error13:
	cudaFree(device.threadImage);
Error12 :
	for (int i = 0; i < 3; i++) {
		if (device.dword_a[i]) {
			cudaFree(device.dword_a[i]);
		}
	}
Error11 :
	for (int i = 0; i < 2; i++) {
		if (device.float_a[i]) {
			cudaFree(device.float_a[i]);
		}
	}
	cudaFree(_device);
Error10:
	cudaFree(tgIterator);
Error9:
	cudaFree(objIterator);
Error8:
	cudaFree(dev_resf);
Error7:
	cudaFree(dev_res);
Error6:
	cudaFree(lgtPoolImp);
Error5:
	cudaFree(camPoolImp);
Error4:
	cudaFree(objPoolImp);
Error3:
	cudaFree(vobjPoolImp);
Error2:
	//cudaFree(dev_res);
	cudaFree(textPoolImp);
Error1_5:
	for (int i = 0; i < MAX_TEXTURELOCAL; i++) {
		if (textPoolBackup.pool[i].texture != NULL) {
			cudaFree(textPoolBackup.pool[i].texture);
		}
	}
Error1_3:
	for (int i = 0; i < vman_count && i < THREAD_W * THREAD_H; i++) {
		cudaFree(vman[i]);
	}
Error1_2:
	cudaFree(dev_vman);
Error1_1:
	cudaFree(dev_tman);
Error1:
	cudaFree(dev_man);
Error_1:
	//for (int i = 0; _verts_pool && i < verts_pool_count && i < THREAD_W * THREAD_H; i++) {
	//	if (_verts_pool[i]) {
	//		cudaFree(_verts_pool[i]);
	//	}
	//}
	if (verts_pool) {
		//delete[] verts_pool;
		//verts_pool = NULL;
		cudaFree(verts_pool);
	}
Error2_1:
	//cudaFree(octPoolImp);
	///////////////////////////////////////
Error:
	  if (threadImage) {

		  delete[] threadImage;
		  threadImage = NULL;
	  }
	return cudaStatus;
}

// Helper function for using CUDA
cudaError_t unInitializeWithCuda(EFTYPE * res, int res_size, Manager3D * man)
{
	cudaError_t cudaStatus = cudaSuccess;

	///////////////////////////////////////
Error14:
	//for (int i = 0; threadImage && i < device.threadImageCount && i < THREAD_W * THREAD_H; i++) {
	//	if (threadImage[i]) {
	//		cudaFree(threadImage[i]);
	//	}
	//}
Error13:
	cudaFree(device.threadImage);
Error12:
	for (int i = 0; i < 6; i++) {
		if (device.dword_a[i]) {
			cudaFree(device.dword_a[i]);
		}
	}
Error11:
	for (int i = 0; i < 3; i++) {
		if (device.float_a[i]) {
			cudaFree(device.float_a[i]);
		}
	}
	cudaFree(_device);
Error10:
	cudaFree(tgIterator);
Error9:
	cudaFree(objIterator);
Error8:
	cudaFree(dev_resf);
Error7:
	cudaFree(dev_res);
	//Error6:
	//	cudaFree(lgtPoolImp);
	//Error5:
	//	cudaFree(camPoolImp);
	//Error4:
	//	cudaFree(objPoolImp);
	//Error3:
	//	cudaFree(vobjPoolImp);
	//Error2:
	//	//cudaFree(dev_res);
	//	cudaFree(textPoolImp);
	//Error1_5:
	//	for (int i = 0; i < MAX_TEXTURELOCAL; i++) {
	//		if (textPoolBackup.pool[i].texture != NULL) {
	//			cudaFree(textPoolBackup.pool[i].texture);
	//		}
	//	}
Error1_1:
	cudaFree(dev_tman);
Error1:
	cudaFree(dev_man);
Error_1:
	if (verts_pool) {
		//delete[] verts_pool;
		//verts_pool = NULL;
		cudaFree(verts_pool);
	}
	//Error2_1:
	//	cudaFree(octPoolImp);
		///////////////////////////////////////
Error:
	//if (threadImage) {

	   // delete[] threadImage;
	   // threadImage = NULL;
	//}
	return cudaStatus;
}

__global__ void normalizeKernel(EFTYPE * res, INT size, Manager3D * _man, Obj3D ** objIterator, INT width, INT iteratorW, INT iteratorH)
{
#ifdef RUN_DEVICE
	int index = 0;

	Manager3D& man = *_man;
	Obj3D * obj = NULL;
	Cam3D * cam = NULL;

	INT iteratorIndex = 0;
	int iteratorIndexX = blockIdx.x * iteratorW;
	int iteratorIndexY = blockIdx.y * iteratorH;

	cam = man.cams.link;
	res[99] = (DWORD)cam;

	Obj3D * _obj = NULL;
	for (int i = iteratorIndexX; i < iteratorIndexX + iteratorW; i++) {
		for (int j = iteratorIndexY; j < iteratorIndexY + iteratorH; j++) {
			Obj3D * obj = objIterator[j * width + i];

			if (obj) {
				if (!_obj) _obj = obj;
				obj->render_normalize(obj, 2);
				res[50 + j * width + i] = obj->debugger;
			}
		}
	}

#ifdef WIN_DEBUG

	if (cam) {
		res[index++] = cam->M.mx.x + cam->M.mx.y + cam->M.mx.z + cam->M.mx.w + cam->M.my.x + cam->M.my.y + cam->M.my.z + cam->M.my.w;
		res[index++] = cam->_M.Ms.mx.x + cam->_M.Ms.mx.y + cam->_M.Ms.mx.z + cam->_M.Ms.mx.w + cam->_M.Ms.my.x + cam->_M.Ms.my.y + cam->_M.Ms.my.z + cam->_M.Ms.my.w;
		res[index++] = cam->_M.M->mx.x + cam->_M.M->mx.y + cam->_M.M->mx.z + cam->_M.M->mx.w + cam->_M.M->my.x + cam->_M.M->my.y + cam->_M.M->my.z + cam->_M.M->my.w;
		res[index++] = cam->_M.Mm.mx.x + cam->_M.Mm.mx.y + cam->_M.Mm.mx.z + cam->_M.Mm.mx.w + cam->_M.Mm.my.x + cam->_M.Mm.my.y + cam->_M.Mm.my.z + cam->_M.Mm.my.w;
		res[index++] = cam->_M.Mrx.mx.x + cam->_M.Mrx.mx.y + cam->_M.Mrx.mx.z + cam->_M.Mrx.mx.w + cam->_M.Mrx.my.x + cam->_M.Mrx.my.y + cam->_M.Mrx.my.z + cam->_M.Mrx.my.w;
	}

	obj = man.objs.link;
	if (obj) {
		res[index++] = obj->M.mx.x + obj->M.mx.y + obj->M.mx.z + obj->M.mx.w + obj->M.my.x + obj->M.my.y + obj->M.my.z + obj->M.my.w;
		res[index++] = obj->_M.Ms.mx.x + obj->_M.Ms.mx.y + obj->_M.Ms.mx.z + obj->_M.Ms.mx.w + obj->_M.Ms.my.x + obj->_M.Ms.my.y + obj->_M.Ms.my.z + obj->_M.Ms.my.w;
		res[index++] = obj->_M.M->mx.x + obj->_M.M->mx.y + obj->_M.M->mx.z + obj->_M.M->mx.w + obj->_M.M->my.x + obj->_M.M->my.y + obj->_M.M->my.z + obj->_M.M->my.w;
		res[index++] = obj->_M.Mm.mx.x + obj->_M.Mm.mx.y + obj->_M.Mm.mx.z + obj->_M.Mm.mx.w + obj->_M.Mm.my.x + obj->_M.Mm.my.y + obj->_M.Mm.my.z + obj->_M.Mm.my.w;
		res[index++] = obj->_M.Mrx.mx.x + obj->_M.Mrx.mx.y + obj->_M.Mrx.mx.z + obj->_M.Mrx.mx.w + obj->_M.Mrx.my.x + obj->_M.Mrx.my.y + obj->_M.Mrx.my.z + obj->_M.Mrx.my.w;
	}

	res[index++] = 1111111111111;
	res[index++] = blockDim.x;
	res[index++] = iteratorIndexX;
	res[index++] = iteratorIndexY;
	res[index++] = (DWORD)&man;
	res[index++] = man.initialized;
	res[index++] = man.objs.linkcount;
	res[index++] = (DWORD)man.objs.link;
	res[index++] = 1111111111111;

	obj = man.objs.link;
	if (obj) {
		do {

			VObj * v = obj->verts.link;
			if (v) {
				do {

					res[index++] = v->v_c.x;
					res[index++] = v->v_c.y;
					res[index++] = v->v_c.z;
					res[index++] = v->v_c.w;

					v = obj->verts.next(&obj->verts, v);
				} while (v && v != obj->verts.link);
			}

			obj = man.objs.next(&man.objs, obj);
		} while (obj && obj != man.objs.link);
	}
#endif
#endif
}

__global__ void rotateKernel(EFTYPE * res, INT size, Manager3D * _man, Obj3D ** objIterator, INT iteratorSize, EFTYPE ax, EFTYPE ay, EFTYPE az)
{
#ifdef RUN_DEVICE
	int index = 0;

	Manager3D& man = *_man;
	Obj3D * obj = NULL;
	Cam3D * cam = NULL;

	if (man.cams.link) {
		cam = man.cams.link;
		man.cams.link->_rotate(man.cams.link, ax, ay, az);
	}

	INT iteratorIndex = 0;
	obj = man.objs.link;
	if (obj) {
		do {
			if (iteratorIndex >= iteratorSize) {
				break;
			}
			objIterator[iteratorIndex++] = obj;

			obj = man.objs.next(&man.objs, obj);
		} while (obj && obj != man.objs.link);
	}
	iteratorIndex = 0;

#ifdef WIN_DEBUG

	if (cam) {
		res[index++] = cam->M.mx.x + cam->M.mx.y + cam->M.mx.z + cam->M.mx.w + cam->M.my.x + cam->M.my.y + cam->M.my.z + cam->M.my.w;
		res[index++] = cam->_M.Ms.mx.x + cam->_M.Ms.mx.y + cam->_M.Ms.mx.z + cam->_M.Ms.mx.w + cam->_M.Ms.my.x + cam->_M.Ms.my.y + cam->_M.Ms.my.z + cam->_M.Ms.my.w;
		res[index++] = cam->_M.M->mx.x + cam->_M.M->mx.y + cam->_M.M->mx.z + cam->_M.M->mx.w + cam->_M.M->my.x + cam->_M.M->my.y + cam->_M.M->my.z + cam->_M.M->my.w;
		res[index++] = cam->_M.Mm.mx.x + cam->_M.Mm.mx.y + cam->_M.Mm.mx.z + cam->_M.Mm.mx.w + cam->_M.Mm.my.x + cam->_M.Mm.my.y + cam->_M.Mm.my.z + cam->_M.Mm.my.w;
		res[index++] = cam->_M.Mrx.mx.x + cam->_M.Mrx.mx.y + cam->_M.Mrx.mx.z + cam->_M.Mrx.mx.w + cam->_M.Mrx.my.x + cam->_M.Mrx.my.y + cam->_M.Mrx.my.z + cam->_M.Mrx.my.w;
	}

	obj = man.objs.link;
	if (obj) {
		res[index++] = obj->M.mx.x + obj->M.mx.y + obj->M.mx.z + obj->M.mx.w + obj->M.my.x + obj->M.my.y + obj->M.my.z + obj->M.my.w;
		res[index++] = obj->_M.Ms.mx.x + obj->_M.Ms.mx.y + obj->_M.Ms.mx.z + obj->_M.Ms.mx.w + obj->_M.Ms.my.x + obj->_M.Ms.my.y + obj->_M.Ms.my.z + obj->_M.Ms.my.w;
		res[index++] = obj->_M.M->mx.x + obj->_M.M->mx.y + obj->_M.M->mx.z + obj->_M.M->mx.w + obj->_M.M->my.x + obj->_M.M->my.y + obj->_M.M->my.z + obj->_M.M->my.w;
		res[index++] = obj->_M.Mm.mx.x + obj->_M.Mm.mx.y + obj->_M.Mm.mx.z + obj->_M.Mm.mx.w + obj->_M.Mm.my.x + obj->_M.Mm.my.y + obj->_M.Mm.my.z + obj->_M.Mm.my.w;
		res[index++] = obj->_M.Mrx.mx.x + obj->_M.Mrx.mx.y + obj->_M.Mrx.mx.z + obj->_M.Mrx.mx.w + obj->_M.Mrx.my.x + obj->_M.Mrx.my.y + obj->_M.Mrx.my.z + obj->_M.Mrx.my.w;
	}

	res[index++] = 11111111111111;
	res[index++] = (DWORD)man.cams.link;
	res[index++] = iteratorSize;
	res[index++] = (DWORD)&man;
	res[index++] = man.initialized;
	res[index++] = man.objs.linkcount;
	res[index++] = (DWORD)man.objs.link;
	res[index++] = 11111111111111;

	res[index++] = (DWORD)objIterator[iteratorIndex++];
	res[index++] = (DWORD)objIterator[iteratorIndex++];
#endif
#endif

}

// Helper function for using CUDA
cudaError_t rotateWithCuda(EFTYPE * res, int res_size, Manager3D * man, EFTYPE ax, EFTYPE ay, EFTYPE az)
{
	cudaError_t cudaStatus;

	/////////////////////////////////////////
	//
	cudaStatus = cudaMemset(dev_resf, 0, sizeof(EFTYPE)* res_size);
	if (cudaStatus != cudaStatus) {
		fprintf(stderr, "cudaMemset failed!");
		goto Error7;
	}
	//核函数参数：
	//<<<块并行数，线程并行数，每个块使用的共享内存大小，流对象>>>
	// Launch a kernel on the GPU with one thread for each element.
	rotateKernel << <1, 1 >> > (dev_resf, res_size, dev_man, objIterator, MAX_ITERATOR, ax, ay, az);

	// Check for any errors launching the kernel
	cudaStatus = cudaGetLastError();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "rotateKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
		goto Error7;
	}

	// cudaDeviceSynchronize waits for the kernel to finish, and returns
	// any errors encountered during the launch.
	cudaStatus = cudaDeviceSynchronize();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching rotateKernel!\n", cudaStatus);
		goto Error7;
	}

#ifdef WIN_DEBUG
	///////////////////////////////////////
	// Copy output vector from GPU buffer to host memory.
	cudaStatus = cudaMemcpy(res, dev_resf, res_size * sizeof(EFTYPE), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error7;
	}
	///////////////////////////////////////
	DEBUG("旋转:");
	for (int i = 0; i < MAX_ITERATOR; i++) {
		DEBUG("%.2f->", res[i]);
	}
	DEBUG("\n");

	/////////////////////////////////////////
	//
	cudaStatus = cudaMemset(dev_resf, 0, sizeof(EFTYPE)* res_size);
	if (cudaStatus != cudaStatus) {
		fprintf(stderr, "cudaMemset failed!");
		goto Error7;
	}
#endif
	//核函数参数：
	//<<<块并行数，线程并行数，每个块使用的共享内存大小，流对象>>>
	// Launch a kernel on the GPU with one thread for each element.
	dim3    grid(THREAD_W_R, THREAD_H_R);
	normalizeKernel << <grid, 1 >> > (dev_resf, res_size, dev_man, objIterator, THREAD_W_R, 1, 1);
	// Check for any errors launching the kernel
	cudaStatus = cudaGetLastError();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "normalizeKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
		goto Error7;
	}

	// cudaDeviceSynchronize waits for the kernel to finish, and returns
	// any errors encountered during the launch.
	cudaStatus = cudaDeviceSynchronize();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching normalizeKernel!\n", cudaStatus);
		goto Error7;
	}

#ifdef WIN_DEBUG
	///////////////////////////////////////
	// Copy output vector from GPU buffer to host memory.
	cudaStatus = cudaMemcpy(res, dev_resf, res_size * sizeof(EFTYPE), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error7;
	}
	///////////////////////////////////////
	DEBUG("旋转刷新:");
	for (int i = 0; i < MAX_ITERATOR; i++) {
		DEBUG("%.2f->", res[i]);
	}
	DEBUG("\n");
#endif

	goto Error;
	///////////////////////////////////////
Error7:
	///////////////////////////////////////
Error:
	return cudaStatus;
}


__global__ void moveKernel(EFTYPE * res, INT size, Manager3D * _man, Obj3D ** objIterator, INT iteratorSize, EFTYPE ax, EFTYPE ay, EFTYPE az)
{
#ifdef RUN_DEVICE
	int index = 0;

	Manager3D& man = *_man;
	Obj3D * obj = NULL;
	Cam3D * cam = NULL;

	if (man.cams.link) {
		cam = man.cams.link;
		man.cams.link->_move(man.cams.link, ax, ay, az);
	}

	INT iteratorIndex = 0;
	obj = man.objs.link;
	if (obj) {
		do {
			if (iteratorIndex >= iteratorSize) {
				break;
			}
			objIterator[iteratorIndex++] = obj;

			obj = man.objs.next(&man.objs, obj);
		} while (obj && obj != man.objs.link);
	}
	iteratorIndex = 0;
#ifdef WIN_DEBUG

	if (cam) {
		res[index++] = cam->M.mx.x + cam->M.mx.y + cam->M.mx.z + cam->M.mx.w + cam->M.my.x + cam->M.my.y + cam->M.my.z + cam->M.my.w;
		res[index++] = cam->_M.Ms.mx.x + cam->_M.Ms.mx.y + cam->_M.Ms.mx.z + cam->_M.Ms.mx.w + cam->_M.Ms.my.x + cam->_M.Ms.my.y + cam->_M.Ms.my.z + cam->_M.Ms.my.w;
		res[index++] = cam->_M.M->mx.x + cam->_M.M->mx.y + cam->_M.M->mx.z + cam->_M.M->mx.w + cam->_M.M->my.x + cam->_M.M->my.y + cam->_M.M->my.z + cam->_M.M->my.w;
		res[index++] = cam->_M.Mm.mx.x + cam->_M.Mm.mx.y + cam->_M.Mm.mx.z + cam->_M.Mm.mx.w + cam->_M.Mm.my.x + cam->_M.Mm.my.y + cam->_M.Mm.my.z + cam->_M.Mm.my.w;
		res[index++] = cam->_M.Mrx.mx.x + cam->_M.Mrx.mx.y + cam->_M.Mrx.mx.z + cam->_M.Mrx.mx.w + cam->_M.Mrx.my.x + cam->_M.Mrx.my.y + cam->_M.Mrx.my.z + cam->_M.Mrx.my.w;
	}

	obj = man.objs.link;
	if (obj) {
		res[index++] = obj->M.mx.x + obj->M.mx.y + obj->M.mx.z + obj->M.mx.w + obj->M.my.x + obj->M.my.y + obj->M.my.z + obj->M.my.w;
		res[index++] = obj->_M.Ms.mx.x + obj->_M.Ms.mx.y + obj->_M.Ms.mx.z + obj->_M.Ms.mx.w + obj->_M.Ms.my.x + obj->_M.Ms.my.y + obj->_M.Ms.my.z + obj->_M.Ms.my.w;
		res[index++] = obj->_M.M->mx.x + obj->_M.M->mx.y + obj->_M.M->mx.z + obj->_M.M->mx.w + obj->_M.M->my.x + obj->_M.M->my.y + obj->_M.M->my.z + obj->_M.M->my.w;
		res[index++] = obj->_M.Mm.mx.x + obj->_M.Mm.mx.y + obj->_M.Mm.mx.z + obj->_M.Mm.mx.w + obj->_M.Mm.my.x + obj->_M.Mm.my.y + obj->_M.Mm.my.z + obj->_M.Mm.my.w;
		res[index++] = obj->_M.Mrx.mx.x + obj->_M.Mrx.mx.y + obj->_M.Mrx.mx.z + obj->_M.Mrx.mx.w + obj->_M.Mrx.my.x + obj->_M.Mrx.my.y + obj->_M.Mrx.my.z + obj->_M.Mrx.my.w;
	}

	res[index++] = 11111111111111;
	res[index++] = (DWORD)man.cams.link;
	res[index++] = iteratorSize;
	res[index++] = (DWORD)&man;
	res[index++] = man.initialized;
	res[index++] = man.objs.linkcount;
	res[index++] = (DWORD)man.objs.link;
	res[index++] = 11111111111111;

	res[index++] = (DWORD)objIterator[iteratorIndex++];
	res[index++] = (DWORD)objIterator[iteratorIndex++];
#endif
#endif

}

// Helper function for using CUDA
cudaError_t moveWithCuda(EFTYPE * res, int res_size, Manager3D * man, EFTYPE ax, EFTYPE ay, EFTYPE az)
{
	cudaError_t cudaStatus;

	/////////////////////////////////////////
	//
	cudaStatus = cudaMemset(dev_resf, 0, sizeof(EFTYPE)* res_size);
	if (cudaStatus != cudaStatus) {
		fprintf(stderr, "cudaMemset failed!");
		goto Error7;
	}
	//核函数参数：
	//<<<块并行数，线程并行数，每个块使用的共享内存大小，流对象>>>
	// Launch a kernel on the GPU with one thread for each element.
	moveKernel << <1, 1 >> > (dev_resf, res_size, dev_man, objIterator, MAX_ITERATOR, ax, ay, az);

	// Check for any errors launching the kernel
	cudaStatus = cudaGetLastError();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "moveKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
		goto Error7;
	}

	// cudaDeviceSynchronize waits for the kernel to finish, and returns
	// any errors encountered during the launch.
	cudaStatus = cudaDeviceSynchronize();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching moveKernel!\n", cudaStatus);
		goto Error7;
	}
#ifdef WIN_DEBUG
	///////////////////////////////////////
	// Copy output vector from GPU buffer to host memory.
	cudaStatus = cudaMemcpy(res, dev_resf, res_size * sizeof(EFTYPE), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error7;
	}
	///////////////////////////////////////
	DEBUG("移动:");
	for (int i = 0; i < MAX_ITERATOR; i++) {
		DEBUG("%.2f->", res[i]);
	}
	DEBUG("\n");

	/////////////////////////////////////////
	//
	cudaStatus = cudaMemset(dev_resf, 0, sizeof(EFTYPE)* res_size);
	if (cudaStatus != cudaStatus) {
		fprintf(stderr, "cudaMemset failed!");
		goto Error7;
	}
#endif
	//核函数参数：
	//<<<块并行数，线程并行数，每个块使用的共享内存大小，流对象>>>
	// Launch a kernel on the GPU with one thread for each element.
	dim3    grid(THREAD_W_R, THREAD_H_R);
	normalizeKernel << <grid, 1 >> > (dev_resf, res_size, dev_man, objIterator, THREAD_W_R, 1, 1);
	// Check for any errors launching the kernel
	cudaStatus = cudaGetLastError();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "normalizeKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
		goto Error7;
	}

	// cudaDeviceSynchronize waits for the kernel to finish, and returns
	// any errors encountered during the launch.
	cudaStatus = cudaDeviceSynchronize();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching normalizeKernel!\n", cudaStatus);
		goto Error7;
	}

#ifdef WIN_DEBUG
	///////////////////////////////////////
	// Copy output vector from GPU buffer to host memory.
	cudaStatus = cudaMemcpy(res, dev_resf, res_size * sizeof(EFTYPE), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error7;
	}
	///////////////////////////////////////
	DEBUG("移动刷新:");
	for (int i = 0; i < MAX_ITERATOR; i++) {
		DEBUG("%.2f->", res[i]);
	}
	DEBUG("\n");
#endif

	goto Error;
	///////////////////////////////////////
Error7:
	///////////////////////////////////////
Error :
	return cudaStatus;
}

__global__ void renderShaderVertexKernel(EFTYPE* res, INT size, Manager3D* _man, Obj3D** objIterator, INT width, INT iteratorW, INT iteratorH)
{
#ifdef RUN_DEVICE
	int index = 0;

	Manager3D& man = *_man;
	Obj3D* obj = NULL;
	Cam3D* cam = NULL;

	INT iteratorIndex = 0;
	int iteratorIndexX = blockIdx.x * iteratorW;
	int iteratorIndexY = blockIdx.y * iteratorH;

	cam = man.cams.link;
	res[99] = (DWORD)cam;

	Obj3D* _obj = NULL;
	for (int i = iteratorIndexX; i < iteratorIndexX + iteratorW; i++) {
		for (int j = iteratorIndexY; j < iteratorIndexY + iteratorH; j++) {
			Obj3D* obj = objIterator[j * width + i];

			if (obj) {
				if (!_obj) _obj = obj;
				obj->shaderVertex(obj);
				res[50 + j * width + i] = obj->debugger;
			}
		}
	}

#ifdef WIN_DEBUG

	if (cam) {
		res[index++] = cam->M.mx.x + cam->M.mx.y + cam->M.mx.z + cam->M.mx.w + cam->M.my.x + cam->M.my.y + cam->M.my.z + cam->M.my.w;
		res[index++] = cam->_M.Ms.mx.x + cam->_M.Ms.mx.y + cam->_M.Ms.mx.z + cam->_M.Ms.mx.w + cam->_M.Ms.my.x + cam->_M.Ms.my.y + cam->_M.Ms.my.z + cam->_M.Ms.my.w;
		res[index++] = cam->_M.M->mx.x + cam->_M.M->mx.y + cam->_M.M->mx.z + cam->_M.M->mx.w + cam->_M.M->my.x + cam->_M.M->my.y + cam->_M.M->my.z + cam->_M.M->my.w;
		res[index++] = cam->_M.Mm.mx.x + cam->_M.Mm.mx.y + cam->_M.Mm.mx.z + cam->_M.Mm.mx.w + cam->_M.Mm.my.x + cam->_M.Mm.my.y + cam->_M.Mm.my.z + cam->_M.Mm.my.w;
		res[index++] = cam->_M.Mrx.mx.x + cam->_M.Mrx.mx.y + cam->_M.Mrx.mx.z + cam->_M.Mrx.mx.w + cam->_M.Mrx.my.x + cam->_M.Mrx.my.y + cam->_M.Mrx.my.z + cam->_M.Mrx.my.w;
	}

	obj = man.objs.link;
	if (obj) {
		res[index++] = obj->M.mx.x + obj->M.mx.y + obj->M.mx.z + obj->M.mx.w + obj->M.my.x + obj->M.my.y + obj->M.my.z + obj->M.my.w;
		res[index++] = obj->_M.Ms.mx.x + obj->_M.Ms.mx.y + obj->_M.Ms.mx.z + obj->_M.Ms.mx.w + obj->_M.Ms.my.x + obj->_M.Ms.my.y + obj->_M.Ms.my.z + obj->_M.Ms.my.w;
		res[index++] = obj->_M.M->mx.x + obj->_M.M->mx.y + obj->_M.M->mx.z + obj->_M.M->mx.w + obj->_M.M->my.x + obj->_M.M->my.y + obj->_M.M->my.z + obj->_M.M->my.w;
		res[index++] = obj->_M.Mm.mx.x + obj->_M.Mm.mx.y + obj->_M.Mm.mx.z + obj->_M.Mm.mx.w + obj->_M.Mm.my.x + obj->_M.Mm.my.y + obj->_M.Mm.my.z + obj->_M.Mm.my.w;
		res[index++] = obj->_M.Mrx.mx.x + obj->_M.Mrx.mx.y + obj->_M.Mrx.mx.z + obj->_M.Mrx.mx.w + obj->_M.Mrx.my.x + obj->_M.Mrx.my.y + obj->_M.Mrx.my.z + obj->_M.Mrx.my.w;
	}

	res[index++] = 1111111111111;
	res[index++] = blockDim.x;
	res[index++] = iteratorIndexX;
	res[index++] = iteratorIndexY;
	res[index++] = (DWORD)&man;
	res[index++] = man.initialized;
	res[index++] = man.objs.linkcount;
	res[index++] = (DWORD)man.objs.link;
	res[index++] = 1111111111111;

	obj = man.objs.link;
	if (obj) {
		do {

			VObj* v = obj->verts.link;
			if (v) {
				do {

					res[index++] = v->v_c.x;
					res[index++] = v->v_c.y;
					res[index++] = v->v_c.z;
					res[index++] = v->v_c.w;

					v = obj->verts.next(&obj->verts, v);
				} while (v && v != obj->verts.link);
			}

			obj = man.objs.next(&man.objs, obj);
		} while (obj && obj != man.objs.link);
	}
#endif
#endif
}

__global__ void shaderVertexKernel(EFTYPE* res, INT size, Manager3D* _man, Obj3D** objIterator, INT iteratorSize, EFTYPE ax, EFTYPE ay, EFTYPE az)
{
#ifdef RUN_DEVICE
	int index = 0;

	Manager3D& man = *_man;
	Obj3D* obj = NULL;
	Cam3D* cam = NULL;

	INT iteratorIndex = 0;
	obj = man.objs.link;
	if (obj) {
		do {
			if (iteratorIndex >= iteratorSize) {
				break;
			}
			objIterator[iteratorIndex++] = obj;

			obj = man.objs.next(&man.objs, obj);
		} while (obj && obj != man.objs.link);
	}
	iteratorIndex = 0;

#ifdef WIN_DEBUG

	if (cam) {
		res[index++] = cam->M.mx.x + cam->M.mx.y + cam->M.mx.z + cam->M.mx.w + cam->M.my.x + cam->M.my.y + cam->M.my.z + cam->M.my.w;
		res[index++] = cam->_M.Ms.mx.x + cam->_M.Ms.mx.y + cam->_M.Ms.mx.z + cam->_M.Ms.mx.w + cam->_M.Ms.my.x + cam->_M.Ms.my.y + cam->_M.Ms.my.z + cam->_M.Ms.my.w;
		res[index++] = cam->_M.M->mx.x + cam->_M.M->mx.y + cam->_M.M->mx.z + cam->_M.M->mx.w + cam->_M.M->my.x + cam->_M.M->my.y + cam->_M.M->my.z + cam->_M.M->my.w;
		res[index++] = cam->_M.Mm.mx.x + cam->_M.Mm.mx.y + cam->_M.Mm.mx.z + cam->_M.Mm.mx.w + cam->_M.Mm.my.x + cam->_M.Mm.my.y + cam->_M.Mm.my.z + cam->_M.Mm.my.w;
		res[index++] = cam->_M.Mrx.mx.x + cam->_M.Mrx.mx.y + cam->_M.Mrx.mx.z + cam->_M.Mrx.mx.w + cam->_M.Mrx.my.x + cam->_M.Mrx.my.y + cam->_M.Mrx.my.z + cam->_M.Mrx.my.w;
	}

	obj = man.objs.link;
	if (obj) {
		res[index++] = obj->M.mx.x + obj->M.mx.y + obj->M.mx.z + obj->M.mx.w + obj->M.my.x + obj->M.my.y + obj->M.my.z + obj->M.my.w;
		res[index++] = obj->_M.Ms.mx.x + obj->_M.Ms.mx.y + obj->_M.Ms.mx.z + obj->_M.Ms.mx.w + obj->_M.Ms.my.x + obj->_M.Ms.my.y + obj->_M.Ms.my.z + obj->_M.Ms.my.w;
		res[index++] = obj->_M.M->mx.x + obj->_M.M->mx.y + obj->_M.M->mx.z + obj->_M.M->mx.w + obj->_M.M->my.x + obj->_M.M->my.y + obj->_M.M->my.z + obj->_M.M->my.w;
		res[index++] = obj->_M.Mm.mx.x + obj->_M.Mm.mx.y + obj->_M.Mm.mx.z + obj->_M.Mm.mx.w + obj->_M.Mm.my.x + obj->_M.Mm.my.y + obj->_M.Mm.my.z + obj->_M.Mm.my.w;
		res[index++] = obj->_M.Mrx.mx.x + obj->_M.Mrx.mx.y + obj->_M.Mrx.mx.z + obj->_M.Mrx.mx.w + obj->_M.Mrx.my.x + obj->_M.Mrx.my.y + obj->_M.Mrx.my.z + obj->_M.Mrx.my.w;
	}

	res[index++] = 11111111111111;
	res[index++] = (DWORD)man.cams.link;
	res[index++] = iteratorSize;
	res[index++] = (DWORD)&man;
	res[index++] = man.initialized;
	res[index++] = man.objs.linkcount;
	res[index++] = (DWORD)man.objs.link;
	res[index++] = 11111111111111;

	res[index++] = (DWORD)objIterator[iteratorIndex++];
	res[index++] = (DWORD)objIterator[iteratorIndex++];
#endif
#endif

}

// Helper function for using CUDA
cudaError_t shaderVertexWithCuda(EFTYPE* res, int res_size, Manager3D* man, EFTYPE ax, EFTYPE ay, EFTYPE az)
{
	cudaError_t cudaStatus;

	/////////////////////////////////////////
	//
	cudaStatus = cudaMemset(dev_resf, 0, sizeof(EFTYPE) * res_size);
	if (cudaStatus != cudaStatus) {
		fprintf(stderr, "cudaMemset failed!");
		goto Error7;
	}
	//核函数参数：
	//<<<块并行数，线程并行数，每个块使用的共享内存大小，流对象>>>
	// Launch a kernel on the GPU with one thread for each element.
	shaderVertexKernel << <1, 1 >> > (dev_resf, res_size, dev_man, objIterator, MAX_ITERATOR, ax, ay, az);

	// Check for any errors launching the kernel
	cudaStatus = cudaGetLastError();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "shaderVertexKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
		goto Error7;
	}

	// cudaDeviceSynchronize waits for the kernel to finish, and returns
	// any errors encountered during the launch.
	cudaStatus = cudaDeviceSynchronize();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching shaderVertexKernel!\n", cudaStatus);
		goto Error7;
	}

#ifdef WIN_DEBUG
	///////////////////////////////////////
	// Copy output vector from GPU buffer to host memory.
	cudaStatus = cudaMemcpy(res, dev_resf, res_size * sizeof(EFTYPE), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error7;
	}
	///////////////////////////////////////
	DEBUG("旋转:");
	for (int i = 0; i < MAX_ITERATOR; i++) {
		DEBUG("%.2f->", res[i]);
	}
	DEBUG("\n");

	/////////////////////////////////////////
	//
	cudaStatus = cudaMemset(dev_resf, 0, sizeof(EFTYPE) * res_size);
	if (cudaStatus != cudaStatus) {
		fprintf(stderr, "cudaMemset failed!");
		goto Error7;
	}
#endif
	//核函数参数：
	//<<<块并行数，线程并行数，每个块使用的共享内存大小，流对象>>>
	// Launch a kernel on the GPU with one thread for each element.
	dim3    grid(THREAD_W_R, THREAD_H_R);
	renderShaderVertexKernel << <grid, 1 >> > (dev_resf, res_size, dev_man, objIterator, THREAD_W_R, 1, 1);
	// Check for any errors launching the kernel
	cudaStatus = cudaGetLastError();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "renderShaderVertexKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
		goto Error7;
	}

	// cudaDeviceSynchronize waits for the kernel to finish, and returns
	// any errors encountered during the launch.
	cudaStatus = cudaDeviceSynchronize();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching renderShaderVertexKernel!\n", cudaStatus);
		goto Error7;
	}

#ifdef WIN_DEBUG
	///////////////////////////////////////
	// Copy output vector from GPU buffer to host memory.
	cudaStatus = cudaMemcpy(res, dev_resf, res_size * sizeof(EFTYPE), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error7;
	}
	///////////////////////////////////////
	DEBUG("顶点着色器:");
	for (int i = 0; i < MAX_ITERATOR; i++) {
		DEBUG("%.2f->", res[i]);
	}
	DEBUG("\n");
#endif

	goto Error;
	///////////////////////////////////////
Error7:
	///////////////////////////////////////
Error:
	return cudaStatus;
}

__global__ void renderReadyKernel(EFTYPE * res, INT size, Manager3D * _man, Triangles * tgIterator, INT iteratorSize, Device * device)
{
#ifdef RUN_DEVICE
	int res_index = 0;

	Manager3D& man = *_man;
	Obj3D * obj = NULL;
	Cam3D * cam = NULL;

#ifdef WIN_DEBUG
	res[res_index++] = device->width * device->height;
	res[res_index++] = 1111111111111;
	res[res_index++] = (DWORD)&man;
	res[res_index++] = man.initialized;
	res[res_index++] = man.objs.linkcount;
	res[res_index++] = (DWORD)man.objs.link;
	res[res_index++] = 1111111111111;
#endif

	VObj * _range = NULL;
	VObj * range = NULL;

	INT iteratorIndex = 0;
	obj = man.objs.link;
	if (obj) {
		int render_state = 0;//render state: 0: normal, 1: reflection, 2: refraction

		int trans_w0 = EP_MAX, trans_h0 = EP_MAX;
		int trans_w1 = -EP_MAX, trans_h1 = -EP_MAX;
		VObj * v, *v0, *v1, *vtemp;
		EPoint l1, l0, l;

		EFTYPE z;
		INT index = 0, _index = 0;
		INT xs, xe, ys, ye;
		int i, j;
		Cam3D* cam = NULL;
		Lgt3D * lgt;
		EFTYPE zz;
		EFTYPE f, t, transparent, _i, _j;
		INT line_state = 0;
		INT line_l = 0, line_r = 0;
		int inrange;
		//DWORD *_image = device->_image;
		EFTYPE* _depth = device->depth;
		DWORD* _tango = device->tango;
		DWORD* _trans = device->trans;
		EFTYPE** ___shade = device->shade;
		DWORD  ___image;
		EFTYPE depth;
		EFTYPE* __depth;
		EFTYPE* __shade;
		DWORD* __image;
		DWORD* __tango, * __trans;
		Vert3D n0, n1, n2, n3, r;
		Vert3D _n0, _n1, _n2, _n3;
		Vert3D p;


		DWORD* _image = device->threadImage[0];
		memset(_image, 0, sizeof(DWORD) * device->width * device->height);
		do {
#ifdef WIN_DEBUG
			res[res_index++] = obj->verts.linkcount;
			res[res_index++] = obj->verts_r.linkcount;
#endif

			if (iteratorIndex >= iteratorSize) {
				break;
			}

			v = obj->verts_r.link;
			// more than 3 verts
			if (v && obj->verts_r.linkcount >= 3) {
				v0 = NULL; v1 = NULL;
				int traverseCount = 0;
				do {
					traverseCount++;
					//there must be three verts
					if (v0 && v1) {
						// back face culling
						//TODO stophin 测试先不用
						//if (v->backface > 0)
						{

							_range = NULL;
							if (range) {
								_range = range;
							}
							else {
								_range = v;
							}
							// in range
							inrange = true;
							if (_range != v) {
								inrange = EPoint::RectIsIntersect(v->xs, v->ys, v->xe, v->ye, _range->xs, _range->ys, _range->xe, _range->ye);
								//inrange = Vert3D::CrossRect(v->xs, v->ys, v->xe, v->ye, _range->xs, _range->ys, _range->xe, _range->ye);
							}
							if (_range && inrange) {
								if (iteratorIndex >= iteratorSize) {
									break;
								}
								tgIterator[iteratorIndex].v0 = v0;
								tgIterator[iteratorIndex].v1 = v1;
								tgIterator[iteratorIndex].v = v;
								iteratorIndex++;
								v->obj = (void*)obj;


								//step1: render the triangle
								index = 0;
								xs = v->xs; xe = v->xe; ys = v->ys; ye = v->ye;
								//xs = _range == v ? v->xs : max(_range->xs, v->xs); ys = _range == v ? v->ys : max(_range->ys, v->ys);
								//xe = _range == v ? v->xe : min(_range->xe, v->xe); ye = _range == v ? v->ye : min(_range->ye, v->ye);
								//draw triangle contour
								Device::Draw_Line(_image, device->width, device->height, v0->x0, v0->y0, v1->x0, v1->y0, WHITE);
								Device::Draw_Line(_image, device->width, device->height, v1->x0, v1->y0, v->x0, v->y0, WHITE);
								Device::Draw_Line(_image, device->width, device->height, v->x0, v->y0, v0->x0, v0->y0, WHITE);


#ifdef WIN_DEBUG
								if (res_index < size) {
									res[res_index++] = ys;
									res[res_index++] = ye;
									res[res_index++] = xs;
									res[res_index++] = xe;
								}
#endif

								EFTYPE zz_f = (v->n_r.x * v->v_c.x + v->n_r.y * v->v_c.y + v->n_r.z * v->v_c.z);
								for (i = ys; i <= ye && i < device->height; i += 1) {
									cam = (Cam3D*)obj->cam;
									if (cam == NULL) {
										break;
									}

									//little trick^_^
									line_state = 0;
									line_l = 0, line_r = 0;
									if (false && device->render_linear < 0) {
										line_l = xs;
										line_r = xe;
									}
									else {
										//trick: pre-judge
										for (j = xs; j <= xe && j < device->width; j += 1) {
											__image = &_image[i * device->width + j];
											//up pulse
											if (*__image != EP_BLACK) {
												line_state++;
												if (line_state == 1) {
													line_l = j;
												}
												else {//if (line_state == 2) {
													line_r = j;
												}
												*__image = EP_BLACK;
											}
										}
									}
									EFTYPE view_h = (i - cam->offset_h) / cam->scale_h;
									for (j = line_l; j <= line_r && j < device->width; j += 1) {

										index = i * device->width + j;
										__image = &_image[index];
										if (device->render_linear < 0) {
											if (j == line_l || j == line_r) {
												*__image = obj->color;
											}
										}
										else {
											if (j >= line_l && j <= line_r) {
												*__image = obj->color;
											}
										}
										//step2: depth test
										if (*__image != EP_BLACK) {
											// get depth
											//(-n.x * ((FLOAT)j - v.x) - n.y * ((FLOAT)i - v.y)) / n.z + v->z
											n0.set((j - cam->offset_w) / cam->scale_w, view_h, 0, 1);
											//z = Vert3D::getZ(v->n_d, v->x0, v->y0, v->z, (EFTYPE)j, (EFTYPE)i);
											z = Vert3D::getZ(v->n_1_z, v->x, v->y, v->z, n0.x, n0.y);
											z *= MAX_PRECISE;
											__depth = &_depth[index];
											if (EP_ISZERO(*__depth)) {
												*__depth = z;
											}
											if (*__depth <= z) {
												*__depth = z;
											}

											if (device->render_linear < 0) {
												_image[index] = EP_BLACK;
											}
											else {
												_image[index] = EP_BLACK;
											}
										}
									}
								}
							}
						}

						if (obj->vertex_type == 1) {
							v0 = NULL;
							v1 = NULL;
						}
						else if (obj->vertex_type == 2) {
							if ((traverseCount + 1) % 2 == 0) {
								v0 = v;
								//this->v1 = this->v1;
							}
							else {
								v0 = v1;
								v1 = v;
							}
						}
						else {
							v0 = v1;
							v1 = v;
						}
					}
					else if (v0 == NULL) {
						v0 = v;
					}
					else if (v1 == NULL) {
						v1 = v;
					}

					v = obj->verts_r.next(&obj->verts_r, v);
				} while (v && v != obj->verts_r.link);
			}


			//first do objects till end
			//then do reflection and then transparent object
			if (render_state == 0) {
				obj = man.objs.next(&man.objs, obj);
				if (!(obj && obj != man.objs.link)) {
					//obj = man.tras.link;
					////do not render reflection points
					//render_state = 2;
					obj = man.refl.link;
					render_state = 1;
					if (!obj) {
						obj = man.tras.link;
						render_state = 2;
					}
				}
			}
			else if (render_state == 1) {
				obj = man.refl.next(&man.refl, obj);
				if (!(obj && obj != man.refl.link)) {
					obj = man.tras.link;
					render_state = 2;
				}

			}
			else {
				obj = man.tras.next(&man.tras, obj);
				if (!(obj && obj != man.tras.link)) {
					//render transparent after all transparent objects were done
					break;
				}
			}
		}while (obj);
	}
#ifdef WIN_DEBUG
	res[res_index++] = 99999999;
	res[res_index++] = iteratorIndex;
#endif
	res[0] = iteratorIndex;
#endif

}

#define THREAD_MUTEX_GET()
#define THREAD_MUTEX_RELEASE()

__global__ void renderKernel(EFTYPE * res, INT size, Manager3D * _man, Triangles * tgIterator, INT iteratorSize, INT grid, INT iteratorW, INT iteratorH, Device * device)
{
#ifdef RUN_DEVICE
	int res_index = 0;

	Manager3D& man = *_man;
	Obj3D * obj = NULL;
	Cam3D * cam = NULL;

	INT iteratorIndex = 0;
	int sx = blockIdx.x * iteratorW;
	int sy = blockIdx.y * iteratorH;
	int ex = blockIdx.x * iteratorW + iteratorW;
	int ey = blockIdx.y * iteratorH + iteratorH;
	int threadIdx = blockIdx.y  * blockDim.x + blockIdx.x;

	cam = man.cams.link;
	res[99] = (DWORD)cam;
	res[98] = 1000 + threadIdx;

	VObj * _range = NULL;
	VObj * range = NULL;

	INT renderIndexX = 0;
	INT renderIndexY = 0;
	int render_state = 0;
	int trans_w0 = EP_MAX, trans_h0 = EP_MAX;
	int trans_w1 = -EP_MAX, trans_h1 = -EP_MAX;
	VObj * v = NULL, *v0 = NULL, *v1 = NULL, *vtemp;
	EPoint l1, l0, l;

	EFTYPE z;
	INT index = 0, _index = 0;
	INT xs, xe, ys, ye;
	int i, j;
	Lgt3D * lgt;
	EFTYPE zz;
	EFTYPE f, t, transparent, _i, _j;
	INT line_state = 0;
	INT line_l = 0, line_r = 0;
	int inrange;

	//DWORD *_image = device->_image;
	EFTYPE *_depth = device->depth;
	DWORD *_tango = device->tango;
	DWORD *_trans = device->trans;
	EFTYPE **___shade = device->shade;
	DWORD  ___image;
	EFTYPE depth;
	EFTYPE * __depth;
	EFTYPE *__shade;
	DWORD * __image;
	DWORD * __tango, *__trans;
	Vert3D n0, n1, n2, n3, r;
	Vert3D _n0, _n1, _n2, _n3;
	Vert3D p;


	if (threadIdx >= device->threadImageCount) {
		return;
	}
	DWORD *_image = device->threadImage[threadIdx];
	memset(_image, 0, sizeof(DWORD)* device->width * device->height);

	INT width = device->width;
	INT height = device->height;
	INT render_linear = device->render_linear;
	INT render_proj = device->render_proj;
	INT render_light = device->render_light;
	INT light_count = device->light_count;


#ifdef WIN_DEBUG
	res[res_index++] = (DWORD)device->threadImage;
	res[res_index++] = (DWORD)device->threadImage[threadIdx];
	res[res_index++] = device->width * device->height;
	res[res_index++] = device->threadImageCount;
	res[res_index++] = grid;

	res[res_index++] = sx;
	res[res_index++] = sy;
	res[res_index++] = ex;
	res[res_index++] = ey;
	res[res_index++] = 99999999;
#endif

	for (renderIndexY = sy; renderIndexY < ey; renderIndexY++) {
		if (iteratorIndex >= iteratorSize) {
			break;
		}
		for (renderIndexX = sx; renderIndexX < ex; renderIndexX++) {
			iteratorIndex = renderIndexY * grid + renderIndexX;
			if (iteratorIndex >= iteratorSize) {
				break;
			}
			v0 = tgIterator[iteratorIndex].v0;
			v1 = tgIterator[iteratorIndex].v1;
			v = tgIterator[iteratorIndex].v;

			if (!v || !v0 || !v1) {
				continue;
			}
			obj = (Obj3D*)v->obj;
			if (!obj) {
				continue;
			}

			//step1: render the triangle
			index = 0;
			xs = v->xs; xe = v->xe; ys = v->ys; ye = v->ye;
			//xs = _range == v ? v->xs : max(_range->xs, v->xs); ys = _range == v ? v->ys : max(_range->ys, v->ys);
			//xe = _range == v ? v->xe : min(_range->xe, v->xe); ye = _range == v ? v->ye : min(_range->ye, v->ye);
			//draw triangle contour
			//memset(_image, 0, sizeof(DWORD) * device->width * device->height);
			//for (i = ys <= 0 ? ys : ys - 1; i <= ye + 1 && i < device->height; i += 1) {
			//	for (j = xs <= 0 ? xs : xs - 1; j <= xe + 1 && j < device->width; j += 1) {
			//		_image[i * device->width + j] = 0;
			//	}
			//}
			//Device::Draw_Line(device->tango, device->width, device->height, v0->x0, v0->y0, v1->x0, v1->y0, RED);
			//Device::Draw_Line(device->tango, device->width, device->height, v1->x0, v1->y0, v->x0, v->y0, RED);
			//Device::Draw_Line(device->tango, device->width, device->height, v->x0, v->y0, v0->x0, v0->y0, RED);
			Device::Draw_Line(_image, device->width, device->height, v0->x0, v0->y0, v1->x0, v1->y0, WHITE);
			Device::Draw_Line(_image, device->width, device->height, v1->x0, v1->y0, v->x0, v->y0, WHITE);
			Device::Draw_Line(_image, device->width, device->height, v->x0, v->y0, v0->x0, v0->y0, WHITE);

#ifdef WIN_DEBUG
			if (res_index < size) {
				res[res_index++] = ys;
				res[res_index++] = ye;
				res[res_index++] = xs;
				res[res_index++] = xe;
			}
#endif

			//get line formula
			//v0-v1
			Vert3D::GetLine(v1->v_s, v0->v_s, l1);
			//v1-v
			Vert3D::GetLine(v->v_s, v1->v_s, l);
			//v-v0
			Vert3D::GetLine(v0->v_s, v->v_s, l0);

			EFTYPE zz_f = (v->n_r.x * v->v_c.x + v->n_r.y * v->v_c.y + v->n_r.z * v->v_c.z);
			for (i = ys; i <= ye && i < device->height; i += 1) {
				cam = (Cam3D*)obj->cam;
				if (cam == NULL) {
					break;
				}

				//little trick^_^
				line_state = 0;
				line_l = xs, line_r = xe;
				if (false && device->render_linear < 0) {
					line_l = xs;
					line_r = xe;
				}
				else {
					//trick: pre-judge
					for (j = xs; j <= xe && j < device->width; j += 1) {
						__image = &_image[i * device->width + j];
						//up pulse
						if (*__image != EP_BLACK) {
							line_state++;
							if (line_state == 1) {
								line_l = j;
							}
							else { //if (line_state == 2) {
								line_r = j;
							}
							*__image = EP_BLACK;
						}
					}
				}
				//get range x
				EFTYPE __y = i;
				EFTYPE __x;
				INT _line_l1 = (INT)(l1.x * __y + l1.y);
				INT _line_l = (INT)(l.x * __y + l.y);
				INT _line_l0 = (INT)(l0.x * __y + l0.y);
				EFTYPE view_h = (i - cam->offset_h) / cam->scale_h;
				for (j = line_l; j <= line_r && j < device->width; j += 1) {

					index = i * device->width + j;
					__image = &_image[index];
					if (device->render_linear < 0) {
						if (j == line_l || j == line_r) {
							*__image = obj->color;
						}
					}
					else {
						if (j >= line_l && j <= line_r) {
							*__image = obj->color;
						}
					}
					//step2: depth test
					if (*__image != EP_BLACK) {
						// get depth
						//(-n.x * ((FLOAT)j - v.x) - n.y * ((FLOAT)i - v.y)) / n.z + v->z
						n0.set((j - cam->offset_w) / cam->scale_w, view_h, 0, 1);
						//z = Vert3D::getZ(v->n_d, v->x0, v->y0, v->z, (EFTYPE)j, (EFTYPE)i);
						z = Vert3D::getZ(v->n_1_z, v->x, v->y, v->z, n0.x, n0.y);
						zz = z * MAX_PRECISE;
						__depth = &_depth[index];
						if (EP_ISZERO(*__depth)) {
							//*__depth = z;
						}
						if ((int)*__depth == (int)zz) {
							//*__depth = z;

							__tango = &device->tango[index];
							__trans = &device->trans[index];


							//step3: render light
							//n0.set((j - cam->offset_w) / cam->scale_w, (i - cam->offset_h) / cam->scale_h, z, 1);
							n0.z = z;
							// get position
							n0 * cam->proj_1;
							zz = zz_f / (v->n_r.x * n0.x + v->n_r.y * n0.y + v->n_r.z);
							n0.x *= zz;
							n0.y *= zz;
							n0.z = zz;
							n0.w = 1;
							n1.set(n0)* cam->M_1;

							*__image = obj->getTextureColor(obj, n0, n1, n2, n3, v, NULL);

#ifdef WIN_DEBUG
							if (res_index < size) {
								res[res_index++] = (EFTYPE)*__image;
							}
#endif

							//get interpolation normal vector from 3 point of a triangle
							__x = j;
							if (1 == obj->normal_type) {
								Object3D_GetInterpolationNormalVector(v0, v1, v, __x, __y,
									line_r, line_l, _line_l1, _line_l, _line_l0,
									5, _n0, _n1, _n2, _n3);
							}
							else {
								_n0.set(v->n_r);
							}

							//calculate sumption of light factors
							lgt = man.lgts.link;
							f = 0;
							if (lgt) {
								do {
									f += lgt->getFactor(lgt, _n0, n0);

									if (device->render_light < 0) {
										break;
									}

									lgt = man.lgts.next(&man.lgts, lgt);
								} while (lgt && lgt != man.lgts.link);
							}


							//step4: render transparent
							if (!EP_ISZERO(obj->transparent)) {
								r.set(n0);
								//t = r.negative() & v->n_r;
								t = r.negative() & _n0;

								if (t < 0) t = -t;
								transparent = 1.0 / obj->transparent;
								if (transparent < 0) transparent = -transparent;

								_i = (i - obj->center_r.y) * (transparent / t) + obj->center_r.y;
								_j = (j - obj->center_r.x) * (transparent / t) + obj->center_r.x;

								if (obj->transparent < 0) {
									_i = 2 * obj->center_r.y - _i;
									_j = 2 * obj->center_r.x - _j;
								}
								if (!(_i < 0 || _i > device->height - 1 || _j < 0 || _j > device->width - 1)) {
									_index = (INT)_i * device->width + (INT)_j;
									//if (depth[_index] < z) 

									//*__trans = Light3D::multi(*__image, f);
									*__trans = Light3D_add(*__image, device->tango[_index], f);

									if (*__trans == EP_BLACK) {
										//*__trans++;
										*__trans = *__image;
									}
									//get transparent range
									if (trans_w1 < j) trans_w1 = j;
									if (trans_h1 < i) trans_h1 = i;
									if (trans_w0 > j) trans_w0 = j;
									if (trans_h0 > i) trans_h0 = i;
								}
							}
							else {
								*__image = Light3D_multi(*__image, f);
							}
							*__tango = *__image;

							//step5: render shadow map
							lgt = man.lgts.link;
							int shadeIndex = 0;
							EFTYPE * _shade = NULL;

							if (lgt) {
								do {
									if (shadeIndex >= device->light_count) {
										break;
									}
									_shade = device->shade[shadeIndex++];

									n2.set(n1) * lgt->M_1;
									cam->project(cam, n2);
									_j = (int)(n2.x * cam->scale_w + cam->offset_w), _i = (int)(n2.y * cam->scale_h + cam->offset_h);

									if (!(_i < 0 || _i > device->height - 1 || _j < 0 || _j > device->width - 1)) {
										_index = _i * device->width + _j;

										__shade = &_shade[_index];
										if (device->render_proj > 0) {
											device->tango[_index] = RED;// obj->color;
										}

										//shadow
										if (EP_GTZERO(*__shade - n2.z - 1e-1)) {
											*__tango = Light3D_multi(*__tango, f / 5);
										}
									}

									lgt = man.lgts.next(&man.lgts, lgt);
								} while (lgt && lgt != man.lgts.link);
							}

							if (device->render_proj > 0) {
								n2.set(n0)*cam->M_1 *obj->M_1* obj->M* cam->M;
								//n2.set(n1) * cam->M;
								cam->project(cam, n2);

								INT __j = (int)(n2.x * cam->scale_w + cam->offset_w), __i = (int)(n2.y * cam->scale_h + cam->offset_h);
								//Draw_Line(_tango, width, height, __j, __i, _j, _i, RED);
								_j = __j, _i = __i;

								if (!(_i < 0 || _i > device->height - 1 || _j < 0 || _j > device->width - 1)) {
									_index = _i * device->width + _j;
									device->tango[_index] = BLUE;// obj->color
								}
							}
						}

						if (device->render_linear < 0) {
							_image[index] = EP_BLACK;
						}
						else {
							_image[index] = EP_BLACK;
						}
					}
				}
			}
		}
		//render transparent after all transparent objects were done
		index = 0;
		for (i = trans_h0; i <= trans_h1 && i < device->height; i++) {
			for (j = trans_w0; j <= trans_w1 && j < device->width; j++) {
				index = i * device->width + j;
				__trans = &device->trans[index];
				if (*__trans != EP_BLACK) {
					__tango = &device->tango[index];
					*__tango = *__trans;
					*__trans = EP_BLACK;
				}
			}
		}
	}

#endif
}


// Helper function for using CUDA
cudaError_t renderWithCuda(EFTYPE * res, int res_size, Manager3D * man, DWORD * image, int img_size)
{
	cudaError_t cudaStatus;

	/////////////////////////////////////////
	//
	cudaStatus = cudaMemset(dev_resf, 0, sizeof(EFTYPE)* res_size);
	if (cudaStatus != cudaStatus) {
		fprintf(stderr, "cudaMemset failed!");
		goto Error7;
	}

	//raytracing
	if (0) {
		cudaStatus = cudaMemset(tango, 0, img_size * sizeof(DWORD));
		if (cudaStatus != cudaStatus) {
			fprintf(stderr, "cudaMemset failed!");
			goto Error7;
		}

		//核函数参数：
		//<<<块并行数，线程并行数，每个块使用的共享内存大小，流对象>>>
		// Launch a kernel on the GPU with one thread for each element.
		dim3    grid(THREAD_W, THREAD_H);
		renderRayTracing << <grid, 1>> > (dev_resf, res_size, dev_man, dev_vman, tgIterator, THREAD_W, WIN_WIDTH / THREAD_W, WIN_HEIGHT / THREAD_H, _device, verts_pool);
		//多线程由于互斥内存太多，不便于并行
		//dim3    grid(THREAD_W, THREAD_H);
		//renderKernel << <grid, 1 >> > (dev_resf, res_size, dev_man, tgIterator, THREAD_W, 1, 1, _device);
	}
	else {
		cudaStatus = cudaMemset(tango, 0, img_size * sizeof(DWORD));
		if (cudaStatus != cudaStatus) {
			fprintf(stderr, "cudaMemset failed!");
			goto Error7;
		}
		cudaStatus = cudaMemset(depth, 0, img_size * sizeof(EFTYPE));
		if (cudaStatus != cudaStatus) {
			fprintf(stderr, "cudaMemset failed!");
			goto Error7;
		}

		//核函数参数：
		//<<<块并行数，线程并行数，每个块使用的共享内存大小，流对象>>>
		// Launch a kernel on the GPU with one thread for each element.
		renderReadyKernel << <1, 1 >> > (dev_resf, res_size, dev_man, tgIterator, MAX_ITERATOR, _device);

		// Check for any errors launching the kernel
		cudaStatus = cudaGetLastError();
		if (cudaStatus != cudaSuccess) {
			fprintf(stderr, "renderReadyKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
			goto Error7;
		}

		// cudaDeviceSynchronize waits for the kernel to finish, and returns
		// any errors encountered during the launch.
		cudaStatus = cudaDeviceSynchronize();
		if (cudaStatus != cudaSuccess) {
			fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching renderReadyKernel!\n", cudaStatus);
			goto Error7;
		}
	#ifdef WIN_DEBUG
		///////////////////////////////////////
		// Copy output vector from GPU buffer to host memory.
		cudaStatus = cudaMemcpy(res, dev_resf, res_size * sizeof(EFTYPE), cudaMemcpyDeviceToHost);
		if (cudaStatus != cudaSuccess) {
			fprintf(stderr, "cudaMemcpy failed!");
			goto Error7;
		}
		///////////////////////////////////////
		DEBUG("渲染:");
		for (int i = 0; i < MAX_ITERATOR; i++) {
			DEBUG("%.2f->", res[i]);
		}
		DEBUG("\n");


		/////////////////////////////////////////
		//
		cudaStatus = cudaMemset(dev_resf, 0, sizeof(EFTYPE)* res_size);
		if (cudaStatus != cudaStatus) {
			fprintf(stderr, "cudaMemset failed!");
			goto Error7;
		}
	#endif
		///////////////////////////////////////
		// Copy output vector from GPU buffer to host memory.
		cudaStatus = cudaMemcpy(res, dev_resf, 1 * sizeof(EFTYPE), cudaMemcpyDeviceToHost);
		if (cudaStatus != cudaSuccess) {
			fprintf(stderr, "cudaMemcpy failed!");
			goto Error7;
		}
		INT iteratorSize = res[0];

		//核函数参数：
		//<<<块并行数，线程并行数，每个块使用的共享内存大小，流对象>>>
		// Launch a kernel on the GPU with one thread for each element.
		dim3    grid(THREAD_W_R, THREAD_H_R);
		renderKernel << <grid, 1 >> > (dev_resf, res_size, dev_man, tgIterator, iteratorSize, THREAD_W_R, 1, 1, _device);
		//多线程由于互斥内存太多，不便于并行
		//dim3    grid(THREAD_W, THREAD_H);
		//renderKernel << <grid, 1 >> > (dev_resf, res_size, dev_man, tgIterator, THREAD_W, 1, 1, _device);
	}

	// Check for any errors launching the kernel
	cudaStatus = cudaGetLastError();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "renderKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
		goto Error7;
	}

	// cudaDeviceSynchronize waits for the kernel to finish, and returns
	// any errors encountered during the launch.
	cudaStatus = cudaDeviceSynchronize();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching renderKernel!%s\n", cudaStatus, cudaGetErrorString(cudaStatus));
		goto Error7;
	}
//#ifdef WIN_DEBUG
	///////////////////////////////////////
	// Copy output vector from GPU buffer to host memory.
	cudaStatus = cudaMemcpy(res, dev_resf, res_size * sizeof(EFTYPE), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy failed!");
		goto Error7;
	}
	///////////////////////////////////////
	DEBUG("渲染完成:");
	for (int i = 0; i < MAX_ITERATOR; i++) {
		DEBUG("%.2f->", res[i]);
	}
	DEBUG("\n");
//#endif

	// Copy output vector from GPU buffer to host memory.
	cudaStatus = cudaMemcpy(image, tango, img_size * sizeof(DWORD), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaMemcpy image failed!");
		goto Error7;
	}
	///////////////////////////////////////
	//for (int i = 0; i < img_size; i++) {
	//	DEBUG("%d->", image[i]);
	//}
	//DEBUG("\n");

	goto Error;
	///////////////////////////////////////
Error7:
	///////////////////////////////////////
Error :
	return cudaStatus;
}


DWORD res[WIN_WIDTH * WIN_HEIGHT] = { 0 };
EFTYPE resf[MAX_ITERATOR] = { 0 };

VOID onClose() {
}

INT isInputBlocked() {
	return 0;
}

INT isresize = -1;
INT isrefresh = -1;
INT width;
INT height;
INT enter_once = 1;
VOID onPaint(HWND hWnd)
{
	if (isresize)
	{
		if (isresize != -1)
		{
			onClose();
		}
		isresize = 0;

		//
		//width = getwidth();
		//height = getheight();

		//device.Resize(width, height);

		//org.Set(width, height);
		//org /= 2;
		//scalex = org.x / 4, scaley = org.x / 4;

		//man.setCameraRange(org.x, org.y, scalex, scaley);
	}
	if (isrefresh < 1) {
		return;
	}
	isrefresh = -1;
	// Place draw code here
	EP_SetColor(EP_BLACK);
	EP_ClearDevice();
	//Render in device buffer
	//if (device.render_raytracing > 0) {
	//	if (enter_once < 0) {
	//		isrefresh = 1;
	//		//Blt buffer to window buffer
	//		DWORD * _tango = EP_GetImageBuffer();
	//		int i, j, index;
	//		for (i = 0; i < device.width; i++) {
	//			for (j = 0; j < device.height; j++){
	//				index = j *  device.width + i;
	//				if (device.raytracing[index] != EP_BLACK)
	//				{
	//					//::SetPixel(memHDC, i, j, device.tango[index]);
	//					_tango[index] = device.raytracing[index];
	//				}
	//			}
	//		}
	//		if (device.draw_line > 0) {
	//			device.drawThreadSplit();
	//		}
	//		return;
	//	}
	//	enter_once = -1;
	//	isrefresh = 1;
	//	device.ClearBeforeRayTracing();
	//	if (device.thread_count > 0) {
	//		device.RenderRayTracing(man);
	//	}
	//	else {
	//		device.RenderRayTracing_SingleThread(man);
	//	}
	//	//Blt buffer to window buffer
	//	DWORD * _tango = EP_GetImageBuffer();
	//	int i, j, index;
	//	for (i = 0; i < device.width; i++) {
	//		for (j = 0; j < device.height; j++){
	//			index = j *  device.width + i;
	//			if (device.raytracing[index] != EP_BLACK)
	//			{
	//				//::SetPixel(memHDC, i, j, device.tango[index]);
	//				_tango[index] = device.raytracing[index];
	//			}
	//		}
	//	}
	//}
	//else  {
		//if (device.draw_oct > 0) {
		//	device.drawAABB(man, &man.octTree);
		//}
		//enter_once = 1;
		//if (device.move_light > 0) {
		//	device.RenderShade(man);
		//}
		//device.ClearBeforeRender();
		//if (device.render_thread > 0) {
		//	device.RenderThread(man);
		//	if (man.changed > 0) {
		//		man.changed--;
		//		device.RenderThreadReady(man, NULL, NULL, NULL);
		//	}
		//	while (!device.IsThreadDone());
		//}
		//else {
		//	device.Render(man, NULL, NULL, NULL);
		//}
		//if (device.render_mirror > 0) {
		//	device.RenderMirror(man);
		//}
		////Blt buffer to window buffer
		//DWORD * _tango = EP_GetImageBuffer();
		//int i, j, index;
		//for (i = 0; i < device.width; i++) {
		//	for (j = 0; j < device.height; j++){
		//		index = j *  device.width + i;
		//		if (device.tango[index] != EP_BLACK)
		//		{
		//			//::SetPixel(memHDC, i, j, device.tango[index]);
		//			_tango[index] = device.tango[index];
		//		}
		//	}
		//}
	//}
	shaderVertexWithCuda(resf, MAX_ITERATOR, NULL, 0, 0, -1);
	renderWithCuda(resf, MAX_ITERATOR, NULL, res, WIN_WIDTH * WIN_HEIGHT);
	//Blt buffer to window buffer
	DWORD * _tango = EP_GetImageBuffer();
	int i, j, index;
	for (i = 0; i < device.width; i++) {
		for (j = 0; j < device.height; j++){
			index = j *  device.width + i;
			if (index >= WIN_WIDTH * WIN_HEIGHT) {
				break;
			}
			if (res[index] != EP_BLACK)
			{
				//::SetPixel(memHDC, i, j, device.tango[index]);
				_tango[index] = res[index];
			}
		}
	}

	//BitBlt(hdc, 0, 0, nWidth, nHeight, memHdc, 0, 0, SRCCOPY);
}

EFTYPE scale = 10.0;
INT is_control = 0;
VOID onScroll(FLOAT delta) {
	if (is_control) {
		if (delta > 0) {
			scale += 1.0;
		}
		else {
			scale -= 1.0;
		}
		if (scale <= 0) {
			scale = 1.0;
		}
	}
	else {
		if (device.move_light > 0) {
			if (delta > 0) {
				//man.moveLight(0, 0, scale);
			}
			else {
				//man.moveLight(0, 0, -scale);
			}
		}
		else if (device.move_trans > 0) {

			//if (delta > 0) {
			//	Obj3D * obj = man.objs.link;
			//	if (obj) {
			//		do {

			//			obj->move(0, 0, scale);


			//			obj = man.objs.next(obj);
			//		} while (obj && obj != man.objs.link);
			//	}
			//}
			//else {
			//	Obj3D * obj = man.objs.link;
			//	if (obj) {
			//		do {

			//			obj->move(0, 0, -scale);


			//			obj = man.objs.next(obj);
			//		} while (obj && obj != man.objs.link);
			//	}
			//}
		}
		else {
			if (delta > 0) {
				//man.moveCamera(0, 0, scale);
				moveWithCuda(resf, MAX_ITERATOR, NULL, 0, 0, scale);
			}
			else {
				//man.moveCamera(0, 0, -scale);
				moveWithCuda(resf, MAX_ITERATOR, NULL, 0, 0, -scale);
			}
		}

		isrefresh = 1;
	}
}

EPointF menu;
VOID onMenu(FLOAT x, FLOAT y, INT mode)
{
	if (mode == 1) // mouse down
	{
		menu.X = x;
		menu.Y = y;
	}
	else if (mode == 2) // mouse move
	{
		if (EP_NTZERO(menu.X) && EP_NTZERO(menu.Y))
		{
			if (device.move_light > 0) {
				//man.moveLight(-(x - menu.X) / scale, -(y - menu.Y) / scale, 0);
			}
			else {
				//man.moveCamera(-(x - menu.X) / scale, -(y - menu.Y) / scale, 0);
				moveWithCuda(resf, MAX_ITERATOR, NULL, -(x - menu.X) / scale, -(y - menu.Y) / scale, 0);
			}
			menu.X = x;
			menu.Y = y;

			isrefresh = 1;
		}
	}
	else	// mouse up
	{
		menu.X = 0;
		menu.Y = 0;
	}
}

EPointF drag;
VOID onDrag(FLOAT x, FLOAT y, INT mode)
{
	if (mode == 1) // mouse down
	{
		drag.X = x;
		drag.Y = y;
	}
	else if (mode == 2) // mouse move
	{
		if (EP_NTZERO(drag.X) && EP_NTZERO(drag.Y))
		{
			if (device.move_light > 0) {
				//man.rotateLight(-(y - drag.Y) / scale, (x - drag.X) / scale, 0);
			}
			else {
				//man.rotateCamera(-(y - drag.Y) / scale, (x - drag.X) / scale, 0);
				rotateWithCuda(resf, MAX_ITERATOR, NULL, -(y - drag.Y) / scale, (x - drag.X) / scale, 0);
			}
			drag.X = x;
			drag.Y = y;

			isrefresh = 1;
		}
	}
	else	// mouse up
	{
		drag.X = 0;
		drag.Y = 0;
	}
}

INT lean = 0;
VOID onTimer()
{
	//return;
	//int count = 0;
	//Obj3D * obj = man.objs.link;
	//if (obj) {
	//	//obj->rotate(0, 10, 0);
	//}
	//obj = man.objs.prev(man.objs.link);
	//if (obj) {
	//	obj->rotate(0, 10, 0);
	//	//obj->scale(1.05, 1.05, 1.05);
	//}

	//obj = man.tras.link;
	//if (obj) {
	//	do {

	//		obj->rotate(0, 10, 0);
	//		/*
	//		obj->move(0, -5, 0);

	//		if (obj->center_w.y + 30 < 0) {
	//		obj->move(0, 50, 0);
	//		}
	//		*/

	//		obj = man.tras.next(obj);
	//	} while (obj && obj != man.tras.link);
	//}
}
VOID onKeyUp(WPARAM wParam) {
	switch (wParam) {
	case VK_CONTROL:
		is_control = 0;
		break;
	case 'Q':
		if (lean) {
			//man.rotateCamera(0, 0, -lean);
			lean = 0;
		}
		break;
	case 'E':
		if (lean) {
			//man.rotateCamera(0, 0, -lean);
			lean = 0;
		}
		break;
	}

	isrefresh = 1;
}
VOID onKeyDown(WPARAM wParam)
{
	if (1)
	{
		switch (wParam)
		{
		case VK_LEFT:
			wParam = 'J';
			break;
		case VK_RIGHT:
			wParam = 'L';
			break;
		case VK_UP:
			wParam = 'I';
			break;
		case VK_DOWN:
			wParam = 'K';
			break;
		case 'A':
			wParam = VK_LEFT;
			break;
		case 'D':
			wParam = VK_RIGHT;
			break;
			//case 'W':
			//	wParam = 'Y';
			//	break;
			//case 'S':
			//	wParam = 'N';
		case 'W':
			wParam = VK_UP;
			break;
		case 'S':
			wParam = VK_DOWN;
			break;
			//case 'Q':
			//	if (lean == 0) {
			//		lean = -scale * 4;
			//		man.rotateCamera(0, 0, lean);
			//	}
			//	break;
			//case 'E':
			//	if (lean == 0) {
			//		lean = scale * 4;
			//		man.rotateCamera(0, 0, lean);
			//	}
			//	break;
		}
	}
	//Object3D * obj = (Object3D *)man.objs.link;
	//obj = cur_op;
	//if (obj == NULL) {
	//	return;
	//}
	switch (wParam)
	{
	case VK_CONTROL:
		is_control = 1;
		break;
		//case VK_LEFT:
		//	man.moveCamera(-1, 0, 0);
		//	break;
		//case VK_RIGHT:
		//	man.moveCamera(1, 0, 0);
		//	break;
		//case VK_UP:
		//	man.moveCamera(0, 1, 0);
		//	break;
		//case VK_DOWN:
		//	man.moveCamera(0, -1, 0);
		//	break;
	case VK_LEFT:
		//if (cur_op) {
		//	//cur_op->setUV(cur_op->u + 1, cur_op->v);
		//	//cur_op->move(1, 0, 0);
		//}
		break;
	case VK_RIGHT:
		//if (cur_op) {
		//	//cur_op->setUV(cur_op->u - 1, cur_op->v);
		//	//cur_op->move(-1, 0, 0);
		//}
		break;
	case VK_UP:
		//if (cur_op) {
		//	//cur_op->setUV(cur_op->u, cur_op->v + 1);
		//	//cur_op->move(0, 1, 0);
		//}
		break;
	case VK_DOWN:
		//if (cur_op) {
		//	//cur_op->setUV(cur_op->u, cur_op->v - 1);
		//	//cur_op->move(0, -1, 0);
		//}
		break;
	case 'Y':
		//man.moveCamera(0, 0, 1);
		moveWithCuda(resf, MAX_ITERATOR, NULL, 0, 0, 1);
		break;
	case 'N':
		//man.moveCamera(0, 0, -1);
		moveWithCuda(resf, MAX_ITERATOR, NULL, 0, 0, -1);
		break;
	case 'U':
		//man.rotateCamera(0, 0, -1);
		rotateWithCuda(resf, MAX_ITERATOR, NULL, 0, 0, -1);
		break;
	case 'O':
		//man.rotateCamera(0, 0, 1);
		rotateWithCuda(resf, MAX_ITERATOR, NULL, 0, 0, 1);
		break;
	case 'M':
		//man.rotateCamera(1, 0, 0);
		rotateWithCuda(resf, MAX_ITERATOR, NULL, 1, 0, 0);
		break;
	case '/':
		//man.rotateCamera(-1, 0, 0);
		rotateWithCuda(resf, MAX_ITERATOR, NULL, -1, 0, 0);
		break;
	case 'P':
		//man.nextCamera();
		//man.setCameraRange(org.x, org.y, scalex, scaley);
		break;
	case 'X':
		//device.draw_line = -device.draw_line;
		break;
	case 'T':
		//device.move_light = -device.move_light;
		break;
	case 'R':
		//device.move_trans = -device.move_trans;
		break;
	case 'L':
		//man.nextLight();
		break;
	case 'H':
		//man.lgts.link->mode = -man.lgts.link->mode;
		break;
	case 'J':
		//device.render_linear = -device.render_linear;
		break;
	case 'I':
		//device.render_proj = -device.render_proj;
		break;
	case 'K':
		//device.render_light = -device.render_light;
		break;
	case 'V':
		//device.render_raytracing = -device.render_raytracing;
		break;
	case 'A':
		//obj->move(1, 0, 0);
		break;
	case 'D':
		//obj->move(-1, 0, 0);
		break;
	case 'S':
		//obj->move(0, -1, 0);
		break;
	case 'W':
		//obj->move(0, 1, 0);
		break;
	case 'G':
		//obj->move(0, 0, -1);
		break;
	case 'F':
		//obj->move(0, 0, 1);
		break;
	case 'Q':
		//if (cur_op) {
		//	Obj3D * vobj = (Obj3D*)cur_op;
		//	do {

		//		vobj->rotate(1, 0, 0);

		//		vobj = vobj->next[1];
		//	} while (vobj && vobj != cur_op);
		//}
		break;
	case 'E':
		//if (cur_op) {
		//	Obj3D * vobj = (Obj3D*)cur_op;
		//	do {

		//		vobj->rotate(-1, 0, 0);

		//		vobj = vobj->next[1];
		//	} while (vobj && vobj != cur_op);
		//}
		break;
	case 'Z':
		//if (cur_op) {
		//	Obj3D * vobj = (Obj3D*)cur_op;
		//	do {

		//		vobj->rotate(0, 1, 0);

		//		vobj = vobj->next[1];
		//	} while (vobj && vobj != cur_op);
		//}
		break;
	case 'C':
		//if (cur_op) {
		//	Obj3D * vobj = (Obj3D*)cur_op;
		//	do {

		//		vobj->rotate(0, -1, 0);

		//		vobj = vobj->next[1];
		//	} while (vobj && vobj != cur_op);
		//}
		break;
	//case '0':
	//	cur_op->texture_type = 0;
	//	break;
	//case '1':
	//	cur_op->texture_type = 1;
	//	break;
	//case '2':
	//	cur_op->texture_type = 2;
	//	break;
	//case '3':
	//	cur_op->texture_type = 3;
	//	break;
	//case '4':
	//	cur_op->texture_type = 4;
	//	break;
	//case '5':
	//	device.draw_oct = -device.draw_oct;
	//	break;
	//case '6':
	//	device.render_thread = -device.render_thread;
	//	break;
	//case 'B':
	//	DEBUG_MODE = DEBUG_MODE >> 1;
	//	if (DEBUG_MODE == 0)
	//	{
	//		DEBUG_MODE = 0x0B;
	//	}
	//	break;
	}

	isrefresh = 1;
}

int MainLoop() {

	cudaError_t cudaStatus;
	cudaStatus = initializeWithCuda(resf, MAX_ITERATOR, NULL);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "initializeWithCuda failed!");
		getch();
		return 1;
	}

	cudaStatus = rotateWithCuda(resf, MAX_ITERATOR, NULL, 0.5, 0.5, 0.5);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "rotateWithCuda failed!");
		getch();
		return 1;
	}
	cudaStatus = moveWithCuda(resf, MAX_ITERATOR, NULL, 100, 100, 100);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "moveWithCuda failed!");
		getch();
		return 1;
	}

	cudaStatus = renderWithCuda(resf, MAX_ITERATOR, NULL, res, WIN_WIDTH * WIN_HEIGHT);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "renderWithCuda failed!");
		getch();
		return 1;
	}

	//取消最小化按钮，使用最小化会造成窗口假死
	SetWindowLong(EP_GetWnd(), GWL_STYLE, GetWindowLong(EP_GetWnd(), GWL_STYLE) & ~WS_MINIMIZEBOX);

	INT count = 0;
	char str[100];
	EP_RenderStart();
	do
	{
		onPaint(EP_GetWnd());

		if (!isInputBlocked()) {
			while (EP_MouseHit())
			{
				EP_MouseMsg msg = EP_GetMouseMsg();
				if (EP_IsWheel(msg)) {
					onScroll(msg.wheel);
				}
				if (EP_IsRight(msg)) {
					if (EP_IsDown(msg))
					{
						onMenu(msg.x, msg.y, 1);
					}
					else if (EP_IsUp(msg))
					{
						onMenu(msg.x, msg.y, 0);
					}
				}
				else if (EP_IsLeft(msg)) {
					if (EP_IsDown(msg))
					{
						onDrag(msg.x, msg.y, 1);
					}
					else if (EP_IsUp(msg))
					{
						onDrag(msg.x, msg.y, 0);
					}
				}
				if (EP_IsMove(msg))
				{
					onMenu(msg.x, msg.y, 2);
					onDrag(msg.x, msg.y, 2);
				}
			}
			if (EP_KBMsg()) {
				EP_MSG msg = EP_GetKBMsg();
				if (EP_KBIsUp(msg)) {
					onKeyUp(EP_GetKey(msg));
				}
				if (EP_KBIsDown(msg)) {
					onKeyDown(EP_GetKey(msg));
				}
				if (EP_Equal(msg, VK_ESCAPE)) {
					break;
				}
			}
		}
		else {
			EP_Delay(1000);
		}
		EP_FlushKey();
		EP_FlushMouse();

		if (count++ > 2) {
			count = 0;
			onTimer();
		}
		//delay_ms(100);
		EP_RenderFlush(10000);
		sprintf_s(str, "%s", "Engine3D");
		::SetWindowText(EP_GetWnd(), str);
	} while (1);
	onClose();
	closegraph();

	cudaStatus = unInitializeWithCuda(resf, MAX_ITERATOR, NULL);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "unInitializeWithCuda failed!");
		getch();
		return 1;
	}
}


int main()
{
	///////////////////////////


#ifdef WIN_DEBUG
	EP_Init(WIN_WIDTH, WIN_HEIGHT, 1);
#else
	EP_Init(WIN_WIDTH, WIN_HEIGHT, 0);
#endif
	//EP_Init(-1, -1);
	// Host test
#ifndef RUN_DEVICE
	_VObjPoolImp(&vobjPoolImp);
	_ObjPoolImp(&objPoolImp, &vobjPoolImp);
	_CamPoolImp(&camPoolImp);
	_LgtPoolImp(&lgtPoolImp);
	_VObjPoolImp(&vobjPoolImp);
	_OctPoolImp(&_octPoolImp, &objPoolImp, &vobjPoolImp);
	_Group3DPoolImp(&group3DPoolImp, &objPoolImp, &vobjPoolImp);
	man.vobjPoolImp = &vobjPoolImp;
	man.objPoolImp = &objPoolImp;
	man.camPoolImp = &camPoolImp;
	man.lgtPoolImp = &lgtPoolImp;
	man.octPoolImp = &_octPoolImp;
	man.group3DPoolImp = &group3DPoolImp;
	man.Init();
	Camera3D * cam = &man.addCamera(50, 50, 50, 1000, 90, 90);
	cam->_move(cam, 0, 0, -200);
	man.setCameraRange(500, 240, 126, 126);

	Object3D *_obj = &man.addObject();
	_obj->addVert(_obj, -10, -10, 10).addVert(_obj, 10, -10, 10).addVert(_obj, -10, 10, 10).addVertA(_obj, 10, 10, 10, -1)
		._move(_obj, 0, -30, -300);
	_obj = &man.addObject();
	_obj->addVert(_obj, 100, 200, 300).addVert(_obj, 400, 500, 900);

	Obj3D * obj = man.objs.link;
	if (obj) {
		do {

			VObj * v = obj->verts.link;
			if (v) {
				do {

					DEBUG("(%.2f, %.2f, %.2f, %.2f)", v->v.x, v->v.y, v->v.z, v->v.w);

					v = obj->verts.next(&obj->verts, v);
				} while (v && v != obj->verts.link);
			}

			obj = man.objs.next(&man.objs, obj);
		} while (obj && obj != man.objs.link);
	}
	DEBUG("\n");


	if (man.cams.link) {
		man.cams.link->_rotate(man.cams.link, 0.5, 0.5, 0.5);
	}
	obj = man.objs.link;
	if (obj) {
		do {

			obj->render_normalize(obj, 0);

			obj = man.objs.next(&man.objs, obj);
		} while (obj && obj != man.objs.link);
	}

	obj = man.objs.link;
	if (obj) {
		do {

			VObj * v = obj->verts.link;
			if (v) {
				do {

					DEBUG("(%.2f, %.2f, %.2f, %.2f)", v->v_c.x, v->v_c.y, v->v_c.z, v->v_c.w);

					v = obj->verts.next(&obj->verts, v);
				} while (v && v != obj->verts.link);
			}

			obj = man.objs.next(&man.objs, obj);
		} while (obj && obj != man.objs.link);
	}
	DEBUG("\n");

	if (man.cams.link) {
		man.cams.link->_move(man.cams.link, 1, 1, 1);
	}
	obj = man.objs.link;
	if (obj) {
		do {

			obj->render_normalize(obj, 0);

			obj = man.objs.next(&man.objs, obj);
		} while (obj && obj != man.objs.link);
	}

	obj = man.objs.link;
	if (obj) {
		do {

			VObj * v = obj->verts.link;
			if (v) {
				do {

					DEBUG("(%.2f, %.2f, %.2f, %.2f)", v->v_c.x, v->v_c.y, v->v_c.z, v->v_c.w);

					v = obj->verts.next(&obj->verts, v);
				} while (v && v != obj->verts.link);
			}

			obj = man.objs.next(&man.objs, obj);
		} while (obj && obj != man.objs.link);
	}
	DEBUG("\n");
	getch();
#endif
	///////////////////////////

	// Get device enum
	cudaError_t cudaStatus;
	int num = 0;
	cudaDeviceProp prop;
	cudaStatus = cudaGetDeviceCount(&num);
	for (int i = 0; i < num; i++) {
		cudaGetDeviceProperties(&prop, i);
	}

	// Choose which GPU to run on, change this on a multi-GPU system.
	cudaStatus = cudaSetDevice(0);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
		getch();
		return 1;
	}
		
	// Run Main Loop
	MainLoop();

    // cudaDeviceReset must be called before exiting in order for profiling and
    // tracing tools such as Nsight and Visual Profiler to show complete traces.
    cudaStatus = cudaDeviceReset();
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaDeviceReset failed!");
		getch();
        return 1;
    }

	getch();
    return 0;
}

