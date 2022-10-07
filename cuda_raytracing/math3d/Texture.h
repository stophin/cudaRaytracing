// Texture.h
// Object for 3D (local)
//

#ifndef _Texture_H_
#define _Texture_H_

#include "../common/MultiLinkLocal.h"

#include <string>
using namespace std;

#include "../platform/EPaint.h"

#define MAX_TEXTURELOCAL_LINK	3
typedef struct TextureLocal TextureLocal;
struct TextureLocal {
	__SUPERLOCAL(MultiLinkLocalElement, TextureLocal, NULL);
	TextureLocal * _prev[MAX_TEXTURELOCAL_LINK];
	TextureLocal * _next[MAX_TEXTURELOCAL_LINK];

	/////////////////////////////////////
	INT width;
	INT height;
	DWORD *texture;
	EIMAGE image;
	void (*LoadTexture)(TextureLocal * that, INT w, INT h, INT n);
	void (*LoadTextureEx)(TextureLocal * that, char *filename);
	void (*destory)(TextureLocal * that);
	/////////////////////////////////////
};
__PLATFORM void TextureLocal_destory(TextureLocal * that) {
	if (that->texture) {
		delete[] that->texture;
		that->texture = NULL;
	}
}
__PLATFORM void TextureLocal_LoadTextureEx(TextureLocal* that, char *filename) {
	if (that->texture) {
		return;
	}
	EFTYPE w = 0, h = 0;
	EP_LoadImage(that->image, filename, w, h);
	that->height = EP_GetImageHeight(that->image);
	that->width = EP_GetImageWidth(that->image);

	that->texture = new DWORD[sizeof(DWORD)* that->height * that->width];
	DWORD * buffer = EP_GetImageBuffer(that->image);
	INT index, index_r, index_t = that->width * that->height - 1;
	for (int y = 0; y < that->height; y++){
		for (int x = 0; x < that->width; x++)
		{
			index = x + y * that->width;
			index_r = index_t -  index;
			that->texture[index] = buffer[index_r];
		}
	}
}
__PLATFORM void TextureLocal_LoadTexture(TextureLocal* that,INT w, INT h, INT n) {
	if (that->texture) {
		return;
	}
	that->width = w;
	that->height = h;
	
	that->texture = new DWORD[sizeof(DWORD)* that->height * that->width];
	if (0 == n) n = 2;
	int d = that->width / n;
	int s = 1;
	for (int i = 0; i < that->width; i++) {
		if (i % d == 0) {
			s = -s;
		}
		for (int j = 0; j < that->height; j++) {
			if (j % d == 0) {
				s = -s;
			}
			that->texture[j * that->width + i] = s > 0 ? DARKGRAY : LIGHTGRAY;
		}
	}
}
__PLATFORM TextureLocal * _TextureLocal(TextureLocal * that){
	that->prev = that->_prev;
	that->next = that->_next;
	_MultiLinkLocalElement(&that->super, MAX_TEXTURELOCAL_LINK);

	/////////////////////////////////////
	that->texture = NULL;
	that->uniqueID = 0;
	that->image = NULL;

	that->LoadTexture = TextureLocal_LoadTexture;
	that->LoadTextureEx = TextureLocal_LoadTextureEx;
	that->destory = TextureLocal_destory;
	/////////////////////////////////////

	return that;
}


/////////////////////////////////////
typedef struct TextureLocalPool TextureLocalPool;
struct TextureLocalPool {
	__SUPERLOCAL(ElementLocalPool, TextureLocalPool, TextureLocal);
};
__PLATFORM TextureLocal * TextureLocalPool_at(TextureLocalPool * that, int index) {
	return &that->pool[index];
}
__PLATFORM void _TextureLocalPool(TextureLocalPool * that, TextureLocal * pool, UMAP * map, int size){
	_ElementLocalPool(&that->super, (MultiLinkLocalElement*)pool, map, size);

	that->at = TextureLocalPool_at;
}

#define MAX_TEXTURELOCAL	10
#define MAP_TEXTURELOCAL	GET_MAP_SIZE(MAX_TEXTURELOCAL)
typedef struct TextureLocalPoolImp TextureLocalPoolImp;
struct TextureLocalPoolImp {
	TextureLocal pool[MAX_TEXTURELOCAL];
	UMAP map[MAP_TEXTURELOCAL];

	TextureLocalPool textPool;
};
__PLATFORM TextureLocalPoolImp * _TextureLocalPoolImp(TextureLocalPoolImp *that) {

	for (int i = 0; i < MAX_TEXTURELOCAL; i++) {
		_TextureLocal(&that->pool[i]);
	}
	_TextureLocalPool(&that->textPool, that->pool, that->map, MAX_TEXTURELOCAL);

	return that;
}
typedef struct TextureLocalMan TextureLocalMan;
struct TextureLocalMan{
	__SUPERLOCAL(MultiLinkLocalBase, TextureLocalMan, TextureLocal);

	TextureLocalPool * textPool;
	
	////////////////////////////
	void (*clearLink)(TextureLocalMan * that);
	////////////////////////////
};
__PLATFORM void TextureLocalMan_clearlink(TextureLocalMan * that){
	if (that->link) {
		TextureLocal * temp = that->link;
		do {
			if (that->removeLink(that, temp) == NULL) {
				break;
			}
			if (!temp->free(temp)) {
				temp->destory(temp);
				that->textPool->back(that->textPool, temp);
			}

			temp = that->link;
		} while (temp);
	}
}
__PLATFORM TextureLocalMan * _TextureLocalMan(TextureLocalMan * that, int index, TextureLocalPoolImp * poolImp){
	_MultiLinkLocalBase(&that->super, index);

	that->textPool = &poolImp->textPool;

	///////////////////////////////////////
	that->clearLink = TextureLocalMan_clearlink;
	///////////////////////////////////////

	return that;
}
/////////////////////////////////////


typedef class TextureLocalManager TextureLocalManager;
class TextureLocalManager {
public:
	TextureLocalManager(){
	}
	~TextureLocalManager() {
		textures.clearLink(&textures);
	}
	void Init() {
		_TextureLocalMan(&textures, 0, texturePoolImp);
	}

	TextureLocalMan textures;
	TextureLocalPoolImp * texturePoolImp;

	INT addTexture(char * filename) {
		TextureLocal * texture = texturePoolImp->textPool.get(&texturePoolImp->textPool);
		if (!texture) {
			return 0;
		}
		_TextureLocal(texture);
		texture->uniqueID = this->textures.linkcount;
		texture->LoadTextureEx(texture, filename);

		this->textures.insertLink(&this->textures, texture, NULL, NULL);

		return texture->uniqueID;
	}

	INT addTexture(INT w, INT h, INT n) {
		TextureLocal * texture = texturePoolImp->textPool.get(&texturePoolImp->textPool);
		if (!texture) {
			return 0;
		}
		_TextureLocal(texture);
		texture->uniqueID = this->textures.linkcount;
		texture->LoadTexture(texture, w, h, n);

		this->textures.insertLink(&this->textures, texture, NULL, NULL);

		return texture->uniqueID;
	}

};


#endif