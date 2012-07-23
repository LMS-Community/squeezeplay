/*
** Lua binding: jive
** Generated automatically by tolua++-1.0.92 on Wed Apr  9 13:56:44 2008.
*/

#ifndef __cplusplus
#include "stdlib.h"
#endif
#include "string.h"

#include "tolua++.h"

/* Exported function */
TOLUA_API int tolua_jive_open (lua_State* tolua_S);

#include "common.h"
#include "jive.h"
#define tolua_outside
#define tolua_create
#define tolua_delete
typedef JiveSurface Surface;
typedef JiveTile Tile;
typedef JiveFont Font;

/* function to release collected object via destructor */
#ifdef __cplusplus

static int tolua_jive_jive_ui_Surface_free00 (lua_State* tolua_S)
{
 Surface* self = (Surface*) tolua_tousertype(tolua_S,1,0);
 delete self;
 return 0;
}

static int tolua_jive_jive_ui_Font__free00 (lua_State* tolua_S)
{
 Font* self = (Font*) tolua_tousertype(tolua_S,1,0);
 delete self;
 return 0;
}

static int tolua_jive_jive_ui_Tile_free00 (lua_State* tolua_S)
{
 Tile* self = (Tile*) tolua_tousertype(tolua_S,1,0);
 delete self;
 return 0;
}
#endif


/* function to register type */
static void tolua_reg_types (lua_State* tolua_S)
{
 tolua_usertype(tolua_S,"SDL_Rect");
 tolua_usertype(tolua_S,"Surface");
 tolua_usertype(tolua_S,"Font");
 tolua_usertype(tolua_S,"Tile");
}

/* get function: x of class  SDL_Rect */
#ifndef TOLUA_DISABLE_tolua_get_SDL_Rect_x
static int tolua_get_SDL_Rect_x(lua_State* tolua_S)
{
  SDL_Rect* self = (SDL_Rect*)  tolua_tousertype(tolua_S,1,0);
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in accessing variable 'x'",NULL);
#endif
 tolua_pushinteger(tolua_S,(lua_Integer)self->x);
 return 1;
}
#endif //#ifndef TOLUA_DISABLE

/* set function: x of class  SDL_Rect */
#ifndef TOLUA_DISABLE_tolua_set_SDL_Rect_x
static int tolua_set_SDL_Rect_x(lua_State* tolua_S)
{
  SDL_Rect* self = (SDL_Rect*)  tolua_tousertype(tolua_S,1,0);
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (!self) tolua_error(tolua_S,"invalid 'self' in accessing variable 'x'",NULL);
 if (!tolua_isinteger(tolua_S,2,0,&tolua_err))
 tolua_error(tolua_S,"#vinvalid type in variable assignment.",&tolua_err);
#endif
  self->x = ((  short)  tolua_tointeger(tolua_S,2,0))
;
 return 0;
}
#endif //#ifndef TOLUA_DISABLE

/* get function: y of class  SDL_Rect */
#ifndef TOLUA_DISABLE_tolua_get_SDL_Rect_y
static int tolua_get_SDL_Rect_y(lua_State* tolua_S)
{
  SDL_Rect* self = (SDL_Rect*)  tolua_tousertype(tolua_S,1,0);
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in accessing variable 'y'",NULL);
#endif
 tolua_pushinteger(tolua_S,(lua_Integer)self->y);
 return 1;
}
#endif //#ifndef TOLUA_DISABLE

/* set function: y of class  SDL_Rect */
#ifndef TOLUA_DISABLE_tolua_set_SDL_Rect_y
static int tolua_set_SDL_Rect_y(lua_State* tolua_S)
{
  SDL_Rect* self = (SDL_Rect*)  tolua_tousertype(tolua_S,1,0);
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (!self) tolua_error(tolua_S,"invalid 'self' in accessing variable 'y'",NULL);
 if (!tolua_isinteger(tolua_S,2,0,&tolua_err))
 tolua_error(tolua_S,"#vinvalid type in variable assignment.",&tolua_err);
#endif
  self->y = ((  short)  tolua_tointeger(tolua_S,2,0))
;
 return 0;
}
#endif //#ifndef TOLUA_DISABLE

/* get function: w of class  SDL_Rect */
#ifndef TOLUA_DISABLE_tolua_get_SDL_Rect_unsigned_w
static int tolua_get_SDL_Rect_unsigned_w(lua_State* tolua_S)
{
  SDL_Rect* self = (SDL_Rect*)  tolua_tousertype(tolua_S,1,0);
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in accessing variable 'w'",NULL);
#endif
 tolua_pushinteger(tolua_S,(lua_Integer)self->w);
 return 1;
}
#endif //#ifndef TOLUA_DISABLE

/* set function: w of class  SDL_Rect */
#ifndef TOLUA_DISABLE_tolua_set_SDL_Rect_unsigned_w
static int tolua_set_SDL_Rect_unsigned_w(lua_State* tolua_S)
{
  SDL_Rect* self = (SDL_Rect*)  tolua_tousertype(tolua_S,1,0);
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (!self) tolua_error(tolua_S,"invalid 'self' in accessing variable 'w'",NULL);
 if (!tolua_isinteger(tolua_S,2,0,&tolua_err))
 tolua_error(tolua_S,"#vinvalid type in variable assignment.",&tolua_err);
#endif
  self->w = (( unsigned short)  tolua_tointeger(tolua_S,2,0))
;
 return 0;
}
#endif //#ifndef TOLUA_DISABLE

/* get function: h of class  SDL_Rect */
#ifndef TOLUA_DISABLE_tolua_get_SDL_Rect_unsigned_h
static int tolua_get_SDL_Rect_unsigned_h(lua_State* tolua_S)
{
  SDL_Rect* self = (SDL_Rect*)  tolua_tousertype(tolua_S,1,0);
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in accessing variable 'h'",NULL);
#endif
 tolua_pushinteger(tolua_S,(lua_Integer)self->h);
 return 1;
}
#endif //#ifndef TOLUA_DISABLE

/* set function: h of class  SDL_Rect */
#ifndef TOLUA_DISABLE_tolua_set_SDL_Rect_unsigned_h
static int tolua_set_SDL_Rect_unsigned_h(lua_State* tolua_S)
{
  SDL_Rect* self = (SDL_Rect*)  tolua_tousertype(tolua_S,1,0);
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (!self) tolua_error(tolua_S,"invalid 'self' in accessing variable 'h'",NULL);
 if (!tolua_isinteger(tolua_S,2,0,&tolua_err))
 tolua_error(tolua_S,"#vinvalid type in variable assignment.",&tolua_err);
#endif
  self->h = (( unsigned short)  tolua_tointeger(tolua_S,2,0))
;
 return 0;
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_newRGB of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_newRGB00
static int tolua_jive_jive_ui_Surface_newRGB00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertable(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,4,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  unsigned short w = (( unsigned short)  tolua_tointeger(tolua_S,2,0));
  unsigned short h = (( unsigned short)  tolua_tointeger(tolua_S,3,0));
 {
  tolua_create Surface* tolua_ret = (tolua_create Surface*)  jive_surface_newRGB(w,h);
 tolua_pushusertype_and_takeownership(tolua_S,(void *)tolua_ret,"Surface");
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'newRGB'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_newRGBA of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_newRGBA00
static int tolua_jive_jive_ui_Surface_newRGBA00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertable(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,4,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  unsigned short w = (( unsigned short)  tolua_tointeger(tolua_S,2,0));
  unsigned short h = (( unsigned short)  tolua_tointeger(tolua_S,3,0));
 {
  tolua_create Surface* tolua_ret = (tolua_create Surface*)  jive_surface_newRGBA(w,h);
 tolua_pushusertype_and_takeownership(tolua_S,(void *)tolua_ret,"Surface");
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'newRGBA'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_load_image of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_loadImage00
static int tolua_jive_jive_ui_Surface_loadImage00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertable(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isstring(tolua_S,2,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,3,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  const char* path = ((const char*)  tolua_tostring(tolua_S,2,0));
 {
  tolua_create Surface* tolua_ret = (tolua_create Surface*)  jive_surface_load_image(path);
 tolua_pushusertype_and_takeownership(tolua_S,(void *)tolua_ret,"Surface");
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'loadImage'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_load_image_data of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_loadImageData00
static int tolua_jive_jive_ui_Surface_loadImageData00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertable(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isstring(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,4,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  const char* data = ((const char*)  tolua_tostring(tolua_S,2,0));
  unsigned int len = (( unsigned int)  tolua_tointeger(tolua_S,3,0));
 {
  tolua_create Surface* tolua_ret = (tolua_create Surface*)  jive_surface_load_image_data(data,len);
 tolua_pushusertype_and_takeownership(tolua_S,(void *)tolua_ret,"Surface");
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'loadImageData'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_font_draw_text of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_drawText00
static int tolua_jive_jive_ui_Surface_drawText00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertable(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isusertype(tolua_S,2,"Font",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isstring(tolua_S,4,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,5,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Font* font = ((Font*)  tolua_tousertype(tolua_S,2,0));
  unsigned int color = (( unsigned int)  tolua_tointeger(tolua_S,3,0));
  const char* str = ((const char*)  tolua_tostring(tolua_S,4,0));
 {
  tolua_create Surface* tolua_ret = (tolua_create Surface*)  jive_font_draw_text(font,color,str);
 tolua_pushusertype_and_takeownership(tolua_S,(void *)tolua_ret,"Surface");
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'drawText'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_free of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_free00
static int tolua_jive_jive_ui_Surface_free00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,2,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_free'",NULL);
#endif
 {
  jive_surface_free(self);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'free'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_release of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_release00
static int tolua_jive_jive_ui_Surface_release00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,2,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_release'",NULL);
#endif
 {
  jive_surface_release(self);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'release'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_save_bmp of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_saveBMP00
static int tolua_jive_jive_ui_Surface_saveBMP00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isstring(tolua_S,2,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,3,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
  const char* file = ((const char*)  tolua_tostring(tolua_S,2,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_save_bmp'",NULL);
#endif
 {
  tolua_outside int tolua_ret = (tolua_outside int)  jive_surface_save_bmp(self,file);
 tolua_pushinteger(tolua_S,(lua_Integer)tolua_ret);
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'saveBMP'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_cmp of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_compare00
static int tolua_jive_jive_ui_Surface_compare00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isusertype(tolua_S,2,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,4,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
  Surface* b = ((Surface*)  tolua_tousertype(tolua_S,2,0));
  unsigned int key = (( unsigned int)  tolua_tointeger(tolua_S,3,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_cmp'",NULL);
#endif
 {
  tolua_outside int tolua_ret = (tolua_outside int)  jive_surface_cmp(self,b,key);
 tolua_pushinteger(tolua_S,(lua_Integer)tolua_ret);
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'compare'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_set_offset of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_setOffset00
static int tolua_jive_jive_ui_Surface_setOffset00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,4,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
   short x = ((  short)  tolua_tointeger(tolua_S,2,0));
   short y = ((  short)  tolua_tointeger(tolua_S,3,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_set_offset'",NULL);
#endif
 {
  jive_surface_set_offset(self,x,y);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'setOffset'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_set_clip_arg of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_setClip00
static int tolua_jive_jive_ui_Surface_setClip00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,6,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
  unsigned short x = (( unsigned short)  tolua_tointeger(tolua_S,2,0));
  unsigned short y = (( unsigned short)  tolua_tointeger(tolua_S,3,0));
  unsigned short w = (( unsigned short)  tolua_tointeger(tolua_S,4,0));
  unsigned short h = (( unsigned short)  tolua_tointeger(tolua_S,5,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_set_clip_arg'",NULL);
#endif
 {
  jive_surface_set_clip_arg(self,x,y,w,h);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'setClip'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_get_clip_arg of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_getClip00
static int tolua_jive_jive_ui_Surface_getClip00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,1,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,1,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,1,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,1,&tolua_err) ||
 !tolua_isnoobj(tolua_S,6,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
  unsigned short x = (( unsigned short)  tolua_tointeger(tolua_S,2,0));
  unsigned short y = (( unsigned short)  tolua_tointeger(tolua_S,3,0));
  unsigned short w = (( unsigned short)  tolua_tointeger(tolua_S,4,0));
  unsigned short h = (( unsigned short)  tolua_tointeger(tolua_S,5,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_get_clip_arg'",NULL);
#endif
 {
  jive_surface_get_clip_arg(self,&x,&y,&w,&h);
 tolua_pushinteger(tolua_S,(lua_Integer)x);
 tolua_pushinteger(tolua_S,(lua_Integer)y);
 tolua_pushinteger(tolua_S,(lua_Integer)w);
 tolua_pushinteger(tolua_S,(lua_Integer)h);
 }
 }
 return 4;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'getClip'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_blit of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_blit00
static int tolua_jive_jive_ui_Surface_blit00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isusertype(tolua_S,2,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,5,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
  Surface* dst = ((Surface*)  tolua_tousertype(tolua_S,2,0));
   short dx = ((  short)  tolua_tointeger(tolua_S,3,0));
   short dy = ((  short)  tolua_tointeger(tolua_S,4,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_blit'",NULL);
#endif
 {
  jive_surface_blit(self,dst,dx,dy);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'blit'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_blit_clip of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_blitClip00
static int tolua_jive_jive_ui_Surface_blitClip00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isusertype(tolua_S,6,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,7,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,8,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,9,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
  unsigned short sx = (( unsigned short)  tolua_tointeger(tolua_S,2,0));
  unsigned short sy = (( unsigned short)  tolua_tointeger(tolua_S,3,0));
  unsigned short sw = (( unsigned short)  tolua_tointeger(tolua_S,4,0));
  unsigned short sh = (( unsigned short)  tolua_tointeger(tolua_S,5,0));
  Surface* dst = ((Surface*)  tolua_tousertype(tolua_S,6,0));
  unsigned short dx = (( unsigned short)  tolua_tointeger(tolua_S,7,0));
  unsigned short dy = (( unsigned short)  tolua_tointeger(tolua_S,8,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_blit_clip'",NULL);
#endif
 {
  jive_surface_blit_clip(self,sx,sy,sw,sh,dst,dx,dy);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'blitClip'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_blit_alpha of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_blitAlpha00
static int tolua_jive_jive_ui_Surface_blitAlpha00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isusertype(tolua_S,2,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,6,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
  Surface* dst = ((Surface*)  tolua_tousertype(tolua_S,2,0));
   short dx = ((  short)  tolua_tointeger(tolua_S,3,0));
   short dy = ((  short)  tolua_tointeger(tolua_S,4,0));
  unsigned char alpha = (( unsigned char)  tolua_tointeger(tolua_S,5,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_blit_alpha'",NULL);
#endif
 {
  jive_surface_blit_alpha(self,dst,dx,dy,alpha);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'blitAlpha'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_get_size of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_getSize00
static int tolua_jive_jive_ui_Surface_getSize00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,1,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,1,&tolua_err) ||
 !tolua_isnoobj(tolua_S,4,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
  unsigned short w = (( unsigned short)  tolua_tointeger(tolua_S,2,0));
  unsigned short h = (( unsigned short)  tolua_tointeger(tolua_S,3,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_get_size'",NULL);
#endif
 {
  jive_surface_get_size(self,&w,&h);
 tolua_pushinteger(tolua_S,(lua_Integer)w);
 tolua_pushinteger(tolua_S,(lua_Integer)h);
 }
 }
 return 2;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'getSize'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_get_bytes of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_getBytes00
static int tolua_jive_jive_ui_Surface_getBytes00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,2,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_get_bytes'",NULL);
#endif
 {
  tolua_outside int tolua_ret = (tolua_outside int)  jive_surface_get_bytes(self);
 tolua_pushinteger(tolua_S,(lua_Integer)tolua_ret);
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'getBytes'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_rotozoomSurface of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_rotozoom00
static int tolua_jive_jive_ui_Surface_rotozoom00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isnumber(tolua_S,2,0,&tolua_err) ||
 !tolua_isnumber(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,1,&tolua_err) ||
 !tolua_isnoobj(tolua_S,5,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
  double angle = ((double)  tolua_tonumber(tolua_S,2,0));
  double zoom = ((double)  tolua_tonumber(tolua_S,3,0));
  int smooth = ((int)  tolua_tointeger(tolua_S,4,1));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_rotozoomSurface'",NULL);
#endif
 {
  tolua_create Surface* tolua_ret = (tolua_create Surface*)  jive_surface_rotozoomSurface(self,angle,zoom,smooth);
 tolua_pushusertype_and_takeownership(tolua_S,(void *)tolua_ret,"Surface");
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'rotozoom'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_zoomSurface of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_zoom00
static int tolua_jive_jive_ui_Surface_zoom00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isnumber(tolua_S,2,0,&tolua_err) ||
 !tolua_isnumber(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,1,&tolua_err) ||
 !tolua_isnoobj(tolua_S,5,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
  double zoomx = ((double)  tolua_tonumber(tolua_S,2,0));
  double zoomy = ((double)  tolua_tonumber(tolua_S,3,0));
  int smooth = ((int)  tolua_tointeger(tolua_S,4,1));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_zoomSurface'",NULL);
#endif
 {
  tolua_create Surface* tolua_ret = (tolua_create Surface*)  jive_surface_zoomSurface(self,zoomx,zoomy,smooth);
 tolua_pushusertype_and_takeownership(tolua_S,(void *)tolua_ret,"Surface");
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'zoom'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_shrinkSurface of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_shrink00
static int tolua_jive_jive_ui_Surface_shrink00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,4,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
  int factorx = ((int)  tolua_tointeger(tolua_S,2,0));
  int factory = ((int)  tolua_tointeger(tolua_S,3,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_shrinkSurface'",NULL);
#endif
 {
  tolua_create Surface* tolua_ret = (tolua_create Surface*)  jive_surface_shrinkSurface(self,factorx,factory);
 tolua_pushusertype_and_takeownership(tolua_S,(void *)tolua_ret,"Surface");
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'shrink'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_pixelColor of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_pixel00
static int tolua_jive_jive_ui_Surface_pixel00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,5,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
   short x = ((  short)  tolua_tointeger(tolua_S,2,0));
   short y = ((  short)  tolua_tointeger(tolua_S,3,0));
  unsigned int col = (( unsigned int)  tolua_tointeger(tolua_S,4,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_pixelColor'",NULL);
#endif
 {
  jive_surface_pixelColor(self,x,y,col);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'pixel'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_hlineColor of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_hline00
static int tolua_jive_jive_ui_Surface_hline00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,6,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
   short x1 = ((  short)  tolua_tointeger(tolua_S,2,0));
   short x2 = ((  short)  tolua_tointeger(tolua_S,3,0));
   short y = ((  short)  tolua_tointeger(tolua_S,4,0));
  unsigned int color = (( unsigned int)  tolua_tointeger(tolua_S,5,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_hlineColor'",NULL);
#endif
 {
  jive_surface_hlineColor(self,x1,x2,y,color);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'hline'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_vlineColor of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_vline00
static int tolua_jive_jive_ui_Surface_vline00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,6,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
   short x = ((  short)  tolua_tointeger(tolua_S,2,0));
   short y1 = ((  short)  tolua_tointeger(tolua_S,3,0));
   short y2 = ((  short)  tolua_tointeger(tolua_S,4,0));
  unsigned int color = (( unsigned int)  tolua_tointeger(tolua_S,5,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_vlineColor'",NULL);
#endif
 {
  jive_surface_vlineColor(self,x,y1,y2,color);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'vline'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_rectangleColor of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_rectangle00
static int tolua_jive_jive_ui_Surface_rectangle00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,6,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,7,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
   short x1 = ((  short)  tolua_tointeger(tolua_S,2,0));
   short y1 = ((  short)  tolua_tointeger(tolua_S,3,0));
   short x2 = ((  short)  tolua_tointeger(tolua_S,4,0));
   short y2 = ((  short)  tolua_tointeger(tolua_S,5,0));
  unsigned int col = (( unsigned int)  tolua_tointeger(tolua_S,6,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_rectangleColor'",NULL);
#endif
 {
  jive_surface_rectangleColor(self,x1,y1,x2,y2,col);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'rectangle'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_boxColor of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_filledRectangle00
static int tolua_jive_jive_ui_Surface_filledRectangle00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,6,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,7,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
   short x1 = ((  short)  tolua_tointeger(tolua_S,2,0));
   short y1 = ((  short)  tolua_tointeger(tolua_S,3,0));
   short x2 = ((  short)  tolua_tointeger(tolua_S,4,0));
   short y2 = ((  short)  tolua_tointeger(tolua_S,5,0));
  unsigned int col = (( unsigned int)  tolua_tointeger(tolua_S,6,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_boxColor'",NULL);
#endif
 {
  jive_surface_boxColor(self,x1,y1,x2,y2,col);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'filledRectangle'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_lineColor of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_line00
static int tolua_jive_jive_ui_Surface_line00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,6,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,7,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
   short x1 = ((  short)  tolua_tointeger(tolua_S,2,0));
   short y1 = ((  short)  tolua_tointeger(tolua_S,3,0));
   short x2 = ((  short)  tolua_tointeger(tolua_S,4,0));
   short y2 = ((  short)  tolua_tointeger(tolua_S,5,0));
  unsigned int col = (( unsigned int)  tolua_tointeger(tolua_S,6,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_lineColor'",NULL);
#endif
 {
  jive_surface_lineColor(self,x1,y1,x2,y2,col);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'line'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_aalineColor of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_aaline00
static int tolua_jive_jive_ui_Surface_aaline00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,6,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,7,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
   short x1 = ((  short)  tolua_tointeger(tolua_S,2,0));
   short y1 = ((  short)  tolua_tointeger(tolua_S,3,0));
   short x2 = ((  short)  tolua_tointeger(tolua_S,4,0));
   short y2 = ((  short)  tolua_tointeger(tolua_S,5,0));
  unsigned int col = (( unsigned int)  tolua_tointeger(tolua_S,6,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_aalineColor'",NULL);
#endif
 {
  jive_surface_aalineColor(self,x1,y1,x2,y2,col);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'aaline'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_circleColor of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_circle00
static int tolua_jive_jive_ui_Surface_circle00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,6,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
   short x = ((  short)  tolua_tointeger(tolua_S,2,0));
   short y = ((  short)  tolua_tointeger(tolua_S,3,0));
   short r = ((  short)  tolua_tointeger(tolua_S,4,0));
  unsigned int col = (( unsigned int)  tolua_tointeger(tolua_S,5,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_circleColor'",NULL);
#endif
 {
  jive_surface_circleColor(self,x,y,r,col);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'circle'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_aacircleColor of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_aacircle00
static int tolua_jive_jive_ui_Surface_aacircle00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,6,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
   short x = ((  short)  tolua_tointeger(tolua_S,2,0));
   short y = ((  short)  tolua_tointeger(tolua_S,3,0));
   short r = ((  short)  tolua_tointeger(tolua_S,4,0));
  unsigned int col = (( unsigned int)  tolua_tointeger(tolua_S,5,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_aacircleColor'",NULL);
#endif
 {
  jive_surface_aacircleColor(self,x,y,r,col);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'aacircle'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_filledCircleColor of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_filledCircle00
static int tolua_jive_jive_ui_Surface_filledCircle00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,6,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
   short x = ((  short)  tolua_tointeger(tolua_S,2,0));
   short y = ((  short)  tolua_tointeger(tolua_S,3,0));
   short r = ((  short)  tolua_tointeger(tolua_S,4,0));
  unsigned int col = (( unsigned int)  tolua_tointeger(tolua_S,5,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_filledCircleColor'",NULL);
#endif
 {
  jive_surface_filledCircleColor(self,x,y,r,col);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'filledCircle'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_ellipseColor of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_ellipse00
static int tolua_jive_jive_ui_Surface_ellipse00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,6,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,7,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
   short x = ((  short)  tolua_tointeger(tolua_S,2,0));
   short y = ((  short)  tolua_tointeger(tolua_S,3,0));
   short rx = ((  short)  tolua_tointeger(tolua_S,4,0));
   short ry = ((  short)  tolua_tointeger(tolua_S,5,0));
  unsigned int col = (( unsigned int)  tolua_tointeger(tolua_S,6,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_ellipseColor'",NULL);
#endif
 {
  jive_surface_ellipseColor(self,x,y,rx,ry,col);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'ellipse'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_aaellipseColor of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_aaellipse00
static int tolua_jive_jive_ui_Surface_aaellipse00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,6,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,7,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
   short x = ((  short)  tolua_tointeger(tolua_S,2,0));
   short y = ((  short)  tolua_tointeger(tolua_S,3,0));
   short rx = ((  short)  tolua_tointeger(tolua_S,4,0));
   short ry = ((  short)  tolua_tointeger(tolua_S,5,0));
  unsigned int col = (( unsigned int)  tolua_tointeger(tolua_S,6,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_aaellipseColor'",NULL);
#endif
 {
  jive_surface_aaellipseColor(self,x,y,rx,ry,col);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'aaellipse'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_filledEllipseColor of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_filledEllipse00
static int tolua_jive_jive_ui_Surface_filledEllipse00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,6,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,7,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
   short x = ((  short)  tolua_tointeger(tolua_S,2,0));
   short y = ((  short)  tolua_tointeger(tolua_S,3,0));
   short rx = ((  short)  tolua_tointeger(tolua_S,4,0));
   short ry = ((  short)  tolua_tointeger(tolua_S,5,0));
  unsigned int col = (( unsigned int)  tolua_tointeger(tolua_S,6,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_filledEllipseColor'",NULL);
#endif
 {
  jive_surface_filledEllipseColor(self,x,y,rx,ry,col);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'filledEllipse'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_pieColor of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_pie00
static int tolua_jive_jive_ui_Surface_pie00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,6,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,7,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,8,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
   short x = ((  short)  tolua_tointeger(tolua_S,2,0));
   short y = ((  short)  tolua_tointeger(tolua_S,3,0));
   short rad = ((  short)  tolua_tointeger(tolua_S,4,0));
   short start = ((  short)  tolua_tointeger(tolua_S,5,0));
   short end = ((  short)  tolua_tointeger(tolua_S,6,0));
  unsigned int col = (( unsigned int)  tolua_tointeger(tolua_S,7,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_pieColor'",NULL);
#endif
 {
  jive_surface_pieColor(self,x,y,rad,start,end,col);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'pie'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_filledPieColor of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_filledPie00
static int tolua_jive_jive_ui_Surface_filledPie00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,6,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,7,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,8,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
   short x = ((  short)  tolua_tointeger(tolua_S,2,0));
   short y = ((  short)  tolua_tointeger(tolua_S,3,0));
   short rad = ((  short)  tolua_tointeger(tolua_S,4,0));
   short start = ((  short)  tolua_tointeger(tolua_S,5,0));
   short end = ((  short)  tolua_tointeger(tolua_S,6,0));
  unsigned int col = (( unsigned int)  tolua_tointeger(tolua_S,7,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_filledPieColor'",NULL);
#endif
 {
  jive_surface_filledPieColor(self,x,y,rad,start,end,col);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'filledPie'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_trigonColor of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_trigon00
static int tolua_jive_jive_ui_Surface_trigon00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,6,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,7,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,8,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,9,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
   short x1 = ((  short)  tolua_tointeger(tolua_S,2,0));
   short y1 = ((  short)  tolua_tointeger(tolua_S,3,0));
   short x2 = ((  short)  tolua_tointeger(tolua_S,4,0));
   short y2 = ((  short)  tolua_tointeger(tolua_S,5,0));
   short x3 = ((  short)  tolua_tointeger(tolua_S,6,0));
   short y3 = ((  short)  tolua_tointeger(tolua_S,7,0));
  unsigned int col = (( unsigned int)  tolua_tointeger(tolua_S,8,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_trigonColor'",NULL);
#endif
 {
  jive_surface_trigonColor(self,x1,y1,x2,y2,x3,y3,col);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'trigon'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_aatrigonColor of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_aatrigon00
static int tolua_jive_jive_ui_Surface_aatrigon00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,6,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,7,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,8,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,9,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
   short x1 = ((  short)  tolua_tointeger(tolua_S,2,0));
   short y1 = ((  short)  tolua_tointeger(tolua_S,3,0));
   short x2 = ((  short)  tolua_tointeger(tolua_S,4,0));
   short y2 = ((  short)  tolua_tointeger(tolua_S,5,0));
   short x3 = ((  short)  tolua_tointeger(tolua_S,6,0));
   short y3 = ((  short)  tolua_tointeger(tolua_S,7,0));
  unsigned int col = (( unsigned int)  tolua_tointeger(tolua_S,8,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_aatrigonColor'",NULL);
#endif
 {
  jive_surface_aatrigonColor(self,x1,y1,x2,y2,x3,y3,col);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'aatrigon'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_filledTrigonColor of class  Surface */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Surface_filledTrigon00
static int tolua_jive_jive_ui_Surface_filledTrigon00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,6,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,7,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,8,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,9,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Surface* self = (Surface*)  tolua_tousertype(tolua_S,1,0);
   short x1 = ((  short)  tolua_tointeger(tolua_S,2,0));
   short y1 = ((  short)  tolua_tointeger(tolua_S,3,0));
   short x2 = ((  short)  tolua_tointeger(tolua_S,4,0));
   short y2 = ((  short)  tolua_tointeger(tolua_S,5,0));
   short x3 = ((  short)  tolua_tointeger(tolua_S,6,0));
   short y3 = ((  short)  tolua_tointeger(tolua_S,7,0));
  unsigned int col = (( unsigned int)  tolua_tointeger(tolua_S,8,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_surface_filledTrigonColor'",NULL);
#endif
 {
  jive_surface_filledTrigonColor(self,x1,y1,x2,y2,x3,y3,col);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'filledTrigon'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_tile_fill_color of class  Tile */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Tile_fillColor00
static int tolua_jive_jive_ui_Tile_fillColor00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertable(tolua_S,1,"Tile",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,3,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  unsigned int col = (( unsigned int)  tolua_tointeger(tolua_S,2,0));
 {
  tolua_create Tile* tolua_ret = (tolua_create Tile*)  jive_tile_fill_color(col);
 tolua_pushusertype_and_takeownership(tolua_S,(void *)tolua_ret,"Tile");
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'fillColor'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_tile_load_image of class  Tile */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Tile_loadImage00
static int tolua_jive_jive_ui_Tile_loadImage00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertable(tolua_S,1,"Tile",0,&tolua_err) ||
 !tolua_isstring(tolua_S,2,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,3,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  const char* path = ((const char*)  tolua_tostring(tolua_S,2,0));
 {
  tolua_create Tile* tolua_ret = (tolua_create Tile*)  jive_tile_load_image(path);
 tolua_pushusertype_and_takeownership(tolua_S,(void *)tolua_ret,"Tile");
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'loadImage'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_surface_load_image_data of class  Title - manually added by Triode */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Tile_loadImageData00
static int tolua_jive_jive_ui_Tile_loadImageData00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertable(tolua_S,1,"Tile",0,&tolua_err) ||
 !tolua_isstring(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,4,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  const char* data = ((const char*)  tolua_tostring(tolua_S,2,0));
  unsigned int len = (( unsigned int)  tolua_tointeger(tolua_S,3,0));
 {
  tolua_create Tile* tolua_ret = (tolua_create Tile*)  jive_tile_load_image_data(data,len);
 tolua_pushusertype_and_takeownership(tolua_S,(void *)tolua_ret,"Tile");
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'loadImageData'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE


/* method: jive_tile_load_tiles of class  Tile */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Tile_loadTiles00
static int tolua_jive_jive_ui_Tile_loadTiles00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertable(tolua_S,1,"Tile",0,&tolua_err) ||
 !tolua_istable(tolua_S,2,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,3,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  char* path[9];
 {
#ifndef TOLUA_RELEASE
 if (!tolua_isstringarray(tolua_S,2,9,0,&tolua_err))
 goto tolua_lerror;
 else
#endif
 {
 int i;
 for(i=0; i<9;i++)
  path[i] = ((char*)  tolua_tofieldstring(tolua_S,2,i+1,0));
 }
 }
 {
  tolua_create Tile* tolua_ret = (tolua_create Tile*)  jive_tile_load_tiles(path);
 tolua_pushusertype_and_takeownership(tolua_S,(void *)tolua_ret,"Tile");
 }
 {
 int i;
 for(i=0; i<9;i++)
 tolua_pushfieldstring(tolua_S,2,i+1,(const char*) path[i]);
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'loadTiles'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_tile_load_vtiles of class  Tile */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Tile_loadVTiles00
static int tolua_jive_jive_ui_Tile_loadVTiles00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertable(tolua_S,1,"Tile",0,&tolua_err) ||
 !tolua_istable(tolua_S,2,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,3,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  char* path[3];
 {
#ifndef TOLUA_RELEASE
 if (!tolua_isstringarray(tolua_S,2,3,0,&tolua_err))
 goto tolua_lerror;
 else
#endif
 {
 int i;
 for(i=0; i<3;i++)
  path[i] = ((char*)  tolua_tofieldstring(tolua_S,2,i+1,0));
 }
 }
 {
  tolua_create Tile* tolua_ret = (tolua_create Tile*)  jive_tile_load_vtiles(path);
 tolua_pushusertype_and_takeownership(tolua_S,(void *)tolua_ret,"Tile");
 }
 {
 int i;
 for(i=0; i<3;i++)
 tolua_pushfieldstring(tolua_S,2,i+1,(const char*) path[i]);
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'loadVTiles'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_tile_load_htiles of class  Tile */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Tile_loadHTiles00
static int tolua_jive_jive_ui_Tile_loadHTiles00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertable(tolua_S,1,"Tile",0,&tolua_err) ||
 !tolua_istable(tolua_S,2,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,3,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  char* path[3];
 {
#ifndef TOLUA_RELEASE
 if (!tolua_isstringarray(tolua_S,2,3,0,&tolua_err))
 goto tolua_lerror;
 else
#endif
 {
 int i;
 for(i=0; i<3;i++)
  path[i] = ((char*)  tolua_tofieldstring(tolua_S,2,i+1,0));
 }
 }
 {
  tolua_create Tile* tolua_ret = (tolua_create Tile*)  jive_tile_load_htiles(path);
 tolua_pushusertype_and_takeownership(tolua_S,(void *)tolua_ret,"Tile");
 }
 {
 int i;
 for(i=0; i<3;i++)
 tolua_pushfieldstring(tolua_S,2,i+1,(const char*) path[i]);
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'loadHTiles'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_tile_free of class  Tile */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Tile_free00
static int tolua_jive_jive_ui_Tile_free00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Tile",0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,2,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Tile* self = (Tile*)  tolua_tousertype(tolua_S,1,0);
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_tile_free'",NULL);
#endif
 {
  jive_tile_free(self);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'free'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_tile_blit of class  Tile */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Tile_blit00
static int tolua_jive_jive_ui_Tile_blit00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Tile",0,&tolua_err) ||
 !tolua_isusertype(tolua_S,2,"Surface",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,4,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,5,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,6,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,7,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Tile* self = (Tile*)  tolua_tousertype(tolua_S,1,0);
  Surface* dst = ((Surface*)  tolua_tousertype(tolua_S,2,0));
  unsigned short dx = (( unsigned short)  tolua_tointeger(tolua_S,3,0));
  unsigned short dy = (( unsigned short)  tolua_tointeger(tolua_S,4,0));
  unsigned short dw = (( unsigned short)  tolua_tointeger(tolua_S,5,0));
  unsigned short dh = (( unsigned short)  tolua_tointeger(tolua_S,6,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_tile_blit'",NULL);
#endif
 {
  jive_tile_blit(self,dst,dx,dy,dw,dh);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'blit'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_tile_get_min_size of class  Tile */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Tile_getMinSize00
static int tolua_jive_jive_ui_Tile_getMinSize00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Tile",0,&tolua_err) ||
 !tolua_isinteger(tolua_S,2,1,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,1,&tolua_err) ||
 !tolua_isnoobj(tolua_S,4,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Tile* self = (Tile*)  tolua_tousertype(tolua_S,1,0);
  unsigned short w = (( unsigned short)  tolua_tointeger(tolua_S,2,0));
  unsigned short h = (( unsigned short)  tolua_tointeger(tolua_S,3,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_tile_get_min_size'",NULL);
#endif
 {
  jive_tile_get_min_size(self,&w,&h);
 tolua_pushinteger(tolua_S,(lua_Integer)w);
 tolua_pushinteger(tolua_S,(lua_Integer)h);
 }
 }
 return 2;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'getMinSize'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_font_load of class  Font */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Font_load00
static int tolua_jive_jive_ui_Font_load00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertable(tolua_S,1,"Font",0,&tolua_err) ||
 !tolua_isstring(tolua_S,2,0,&tolua_err) ||
 !tolua_isinteger(tolua_S,3,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,4,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  const char* name = ((const char*)  tolua_tostring(tolua_S,2,0));
  unsigned int size = (( unsigned int)  tolua_tointeger(tolua_S,3,0));
 {
  tolua_create Font* tolua_ret = (tolua_create Font*)  jive_font_load(name,size);
 tolua_pushusertype_and_takeownership(tolua_S,(void *)tolua_ret,"Font");
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'load'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_font_free of class  Font */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Font__free00
static int tolua_jive_jive_ui_Font__free00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Font",0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,2,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Font* self = (Font*)  tolua_tousertype(tolua_S,1,0);
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_font_free'",NULL);
#endif
 {
  jive_font_free(self);
 }
 }
 return 0;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function '_free'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_font_width of class  Font */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Font_width00
static int tolua_jive_jive_ui_Font_width00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Font",0,&tolua_err) ||
 !tolua_isstring(tolua_S,2,0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,3,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Font* self = (Font*)  tolua_tousertype(tolua_S,1,0);
  const char* str = ((const char*)  tolua_tostring(tolua_S,2,0));
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_font_width'",NULL);
#endif
 {
  tolua_outside int tolua_ret = (tolua_outside int)  jive_font_width(self,str);
 tolua_pushinteger(tolua_S,(lua_Integer)tolua_ret);
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'width'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_font_capheight of class  Font */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Font_capheight00
static int tolua_jive_jive_ui_Font_capheight00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Font",0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,2,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Font* self = (Font*)  tolua_tousertype(tolua_S,1,0);
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_font_capheight'",NULL);
#endif
 {
  tolua_outside int tolua_ret = (tolua_outside int)  jive_font_capheight(self);
 tolua_pushinteger(tolua_S,(lua_Integer)tolua_ret);
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'capheight'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_font_height of class  Font */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Font_height00
static int tolua_jive_jive_ui_Font_height00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Font",0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,2,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Font* self = (Font*)  tolua_tousertype(tolua_S,1,0);
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_font_height'",NULL);
#endif
 {
  tolua_outside int tolua_ret = (tolua_outside int)  jive_font_height(self);
 tolua_pushinteger(tolua_S,(lua_Integer)tolua_ret);
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'height'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_font_ascend of class  Font */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Font_ascend00
static int tolua_jive_jive_ui_Font_ascend00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Font",0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,2,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Font* self = (Font*)  tolua_tousertype(tolua_S,1,0);
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_font_ascend'",NULL);
#endif
 {
  tolua_outside int tolua_ret = (tolua_outside int)  jive_font_ascend(self);
 tolua_pushinteger(tolua_S,(lua_Integer)tolua_ret);
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'ascend'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* method: jive_font_offset of class  Font */
#ifndef TOLUA_DISABLE_tolua_jive_jive_ui_Font_offset00
static int tolua_jive_jive_ui_Font_offset00(lua_State* tolua_S)
{
#ifndef TOLUA_RELEASE
 tolua_Error tolua_err;
 if (
 !tolua_isusertype(tolua_S,1,"Font",0,&tolua_err) ||
 !tolua_isnoobj(tolua_S,2,&tolua_err)
 )
 goto tolua_lerror;
 else
#endif
 {
  Font* self = (Font*)  tolua_tousertype(tolua_S,1,0);
#ifndef TOLUA_RELEASE
 if (!self) tolua_error(tolua_S,"invalid 'self' in function 'jive_font_offset'",NULL);
#endif
 {
  tolua_outside int tolua_ret = (tolua_outside int)  jive_font_offset(self);
 tolua_pushinteger(tolua_S,(lua_Integer)tolua_ret);
 }
 }
 return 1;
#ifndef TOLUA_RELEASE
 tolua_lerror:
 tolua_error(tolua_S,"#ferror in function 'offset'.",&tolua_err);
 return 0;
#endif
}
#endif //#ifndef TOLUA_DISABLE

/* Open function */
TOLUA_API int tolua_jive_open (lua_State* tolua_S)
{
 tolua_open(tolua_S);
 tolua_reg_types(tolua_S);
 tolua_module(tolua_S,NULL,0);
 tolua_beginmodule(tolua_S,NULL);
 tolua_module(tolua_S,"jive",0);
 tolua_beginmodule(tolua_S,"jive");
  tolua_module(tolua_S,"ui",0);
  tolua_beginmodule(tolua_S,"ui");
   tolua_cclass(tolua_S,"SDL_Rect","SDL_Rect","",NULL);
   tolua_beginmodule(tolua_S,"SDL_Rect");
    tolua_variable(tolua_S,"x",tolua_get_SDL_Rect_x,tolua_set_SDL_Rect_x);
    tolua_variable(tolua_S,"y",tolua_get_SDL_Rect_y,tolua_set_SDL_Rect_y);
    tolua_variable(tolua_S,"w",tolua_get_SDL_Rect_unsigned_w,tolua_set_SDL_Rect_unsigned_w);
    tolua_variable(tolua_S,"h",tolua_get_SDL_Rect_unsigned_h,tolua_set_SDL_Rect_unsigned_h);
   tolua_endmodule(tolua_S);
   tolua_constant(tolua_S,"true",true);
   tolua_constant(tolua_S,"false",false);
   tolua_constant(tolua_S,"FRAME_RATE",JIVE_FRAME_RATE);
   tolua_constant(tolua_S,"XY_NIL",JIVE_XY_NIL);
   tolua_constant(tolua_S,"WH_NIL",JIVE_WH_NIL);
   tolua_constant(tolua_S,"WH_FILL",JIVE_WH_FILL);
   tolua_constant(tolua_S,"ALIGN_CENTER",JIVE_ALIGN_CENTER);
   tolua_constant(tolua_S,"ALIGN_LEFT",JIVE_ALIGN_LEFT);
   tolua_constant(tolua_S,"ALIGN_RIGHT",JIVE_ALIGN_RIGHT);
   tolua_constant(tolua_S,"ALIGN_TOP",JIVE_ALIGN_TOP);
   tolua_constant(tolua_S,"ALIGN_BOTTOM",JIVE_ALIGN_BOTTOM);
   tolua_constant(tolua_S,"ALIGN_TOP_LEFT",JIVE_ALIGN_TOP_LEFT);
   tolua_constant(tolua_S,"ALIGN_TOP_RIGHT",JIVE_ALIGN_TOP_RIGHT);
   tolua_constant(tolua_S,"ALIGN_BOTTOM_LEFT",JIVE_ALIGN_BOTTOM_LEFT);
   tolua_constant(tolua_S,"ALIGN_BOTTOM_RIGHT",JIVE_ALIGN_BOTTOM_RIGHT);
   tolua_constant(tolua_S,"LAYOUT_NORTH",JIVE_LAYOUT_NORTH);
   tolua_constant(tolua_S,"LAYOUT_EAST",JIVE_LAYOUT_EAST);
   tolua_constant(tolua_S,"LAYOUT_SOUTH",JIVE_LAYOUT_SOUTH);
   tolua_constant(tolua_S,"LAYOUT_WEST",JIVE_LAYOUT_WEST);
   tolua_constant(tolua_S,"LAYOUT_CENTER",JIVE_LAYOUT_CENTER);
   tolua_constant(tolua_S,"LAYOUT_NONE",JIVE_LAYOUT_NONE);
   tolua_constant(tolua_S,"LAYER_FRAME",JIVE_LAYER_FRAME);
   tolua_constant(tolua_S,"LAYER_TITLE",JIVE_LAYER_TITLE);
   tolua_constant(tolua_S,"LAYER_CONTENT",JIVE_LAYER_CONTENT);
   tolua_constant(tolua_S,"LAYER_CONTENT_OFF_STAGE",JIVE_LAYER_CONTENT_OFF_STAGE);
   tolua_constant(tolua_S,"LAYER_CONTENT_ON_STAGE",JIVE_LAYER_CONTENT_ON_STAGE);
   tolua_constant(tolua_S,"LAYER_LOWER",JIVE_LAYER_LOWER);
   tolua_constant(tolua_S,"LAYER_ALL",JIVE_LAYER_ALL);
   tolua_constant(tolua_S,"EVENT_NONE",JIVE_EVENT_NONE);
   tolua_constant(tolua_S,"EVENT_SCROLL",JIVE_EVENT_SCROLL);
   tolua_constant(tolua_S,"EVENT_ACTION",JIVE_EVENT_ACTION);
   tolua_constant(tolua_S,"EVENT_GESTURE",JIVE_EVENT_GESTURE);
   tolua_constant(tolua_S,"EVENT_KEY_DOWN",JIVE_EVENT_KEY_DOWN);
   tolua_constant(tolua_S,"EVENT_KEY_UP",JIVE_EVENT_KEY_UP);
   tolua_constant(tolua_S,"EVENT_KEY_PRESS",JIVE_EVENT_KEY_PRESS);
   tolua_constant(tolua_S,"EVENT_KEY_HOLD",JIVE_EVENT_KEY_HOLD);
   tolua_constant(tolua_S,"EVENT_CHAR_PRESS",JIVE_EVENT_CHAR_PRESS);
   tolua_constant(tolua_S,"EVENT_MOUSE_DOWN",JIVE_EVENT_MOUSE_DOWN);
   tolua_constant(tolua_S,"EVENT_MOUSE_UP",JIVE_EVENT_MOUSE_UP);
   tolua_constant(tolua_S,"EVENT_MOUSE_PRESS",JIVE_EVENT_MOUSE_PRESS);
   tolua_constant(tolua_S,"EVENT_MOUSE_HOLD",JIVE_EVENT_MOUSE_HOLD);
   tolua_constant(tolua_S,"EVENT_MOUSE_MOVE",JIVE_EVENT_MOUSE_MOVE);
   tolua_constant(tolua_S,"EVENT_MOUSE_DRAG",JIVE_EVENT_MOUSE_DRAG);
   tolua_constant(tolua_S,"EVENT_WINDOW_PUSH",JIVE_EVENT_WINDOW_PUSH);
   tolua_constant(tolua_S,"EVENT_WINDOW_POP",JIVE_EVENT_WINDOW_POP);
   tolua_constant(tolua_S,"EVENT_WINDOW_ACTIVE",JIVE_EVENT_WINDOW_ACTIVE);
   tolua_constant(tolua_S,"EVENT_WINDOW_INACTIVE",JIVE_EVENT_WINDOW_INACTIVE);
   tolua_constant(tolua_S,"EVENT_SHOW",JIVE_EVENT_SHOW);
   tolua_constant(tolua_S,"EVENT_HIDE",JIVE_EVENT_HIDE);
   tolua_constant(tolua_S,"EVENT_FOCUS_GAINED",JIVE_EVENT_FOCUS_GAINED);
   tolua_constant(tolua_S,"EVENT_FOCUS_LOST",JIVE_EVENT_FOCUS_LOST);
   tolua_constant(tolua_S,"EVENT_WINDOW_RESIZE",JIVE_EVENT_WINDOW_RESIZE);
   tolua_constant(tolua_S,"EVENT_SWITCH",JIVE_EVENT_SWITCH);
   tolua_constant(tolua_S,"EVENT_MOTION",JIVE_EVENT_MOTION);
   tolua_constant(tolua_S,"EVENT_IR_PRESS",JIVE_EVENT_IR_PRESS);
   tolua_constant(tolua_S,"EVENT_IR_UP",JIVE_EVENT_IR_UP);
   tolua_constant(tolua_S,"EVENT_IR_DOWN",JIVE_EVENT_IR_DOWN);
   tolua_constant(tolua_S,"EVENT_IR_REPEAT",JIVE_EVENT_IR_REPEAT);
   tolua_constant(tolua_S,"EVENT_IR_HOLD",JIVE_EVENT_IR_HOLD);
   tolua_constant(tolua_S,"EVENT_IR_ALL",JIVE_EVENT_IR_ALL);
   tolua_constant(tolua_S,"EVENT_KEY_ALL",JIVE_EVENT_KEY_ALL);
   tolua_constant(tolua_S,"ACTION",JIVE_ACTION);
   tolua_constant(tolua_S,"EVENT_MOUSE_ALL",JIVE_EVENT_MOUSE_ALL);
   tolua_constant(tolua_S,"EVENT_ALL_INPUT",JIVE_EVENT_ALL_INPUT);
   tolua_constant(tolua_S,"EVENT_VISIBLE_ALL",JIVE_EVENT_VISIBLE_ALL);
   tolua_constant(tolua_S,"EVENT_ALL",JIVE_EVENT_ALL);
   tolua_constant(tolua_S,"EVENT_UNUSED",JIVE_EVENT_UNUSED);
   tolua_constant(tolua_S,"EVENT_CONSUME",JIVE_EVENT_CONSUME);
   tolua_constant(tolua_S,"EVENT_QUIT",JIVE_EVENT_QUIT);
   tolua_constant(tolua_S,"GESTURE_L_R",JIVE_GESTURE_L_R);
   tolua_constant(tolua_S,"GESTURE_R_L",JIVE_GESTURE_R_L);
   tolua_constant(tolua_S,"KEY_NONE",JIVE_KEY_NONE);
   tolua_constant(tolua_S,"KEY_GO",JIVE_KEY_GO);
   tolua_constant(tolua_S,"KEY_BACK",JIVE_KEY_BACK);
   tolua_constant(tolua_S,"KEY_UP",JIVE_KEY_UP);
   tolua_constant(tolua_S,"KEY_DOWN",JIVE_KEY_DOWN);
   tolua_constant(tolua_S,"KEY_LEFT",JIVE_KEY_LEFT);
   tolua_constant(tolua_S,"KEY_RIGHT",JIVE_KEY_RIGHT);
   tolua_constant(tolua_S,"KEY_HOME",JIVE_KEY_HOME);
   tolua_constant(tolua_S,"KEY_PLAY",JIVE_KEY_PLAY);
   tolua_constant(tolua_S,"KEY_ADD",JIVE_KEY_ADD);
   tolua_constant(tolua_S,"KEY_PAUSE",JIVE_KEY_PAUSE);
   tolua_constant(tolua_S,"KEY_REW",JIVE_KEY_REW);
   tolua_constant(tolua_S,"KEY_FWD",JIVE_KEY_FWD);
   tolua_constant(tolua_S,"KEY_VOLUME_UP",JIVE_KEY_VOLUME_UP);
   tolua_constant(tolua_S,"KEY_VOLUME_DOWN",JIVE_KEY_VOLUME_DOWN);
   tolua_constant(tolua_S,"KEY_MUTE",JIVE_KEY_MUTE);
   tolua_constant(tolua_S,"KEY_ALARM",JIVE_KEY_ALARM);
   tolua_constant(tolua_S,"KEY_POWER",JIVE_KEY_POWER);
   tolua_constant(tolua_S,"KEY_PRESET_1",JIVE_KEY_PRESET_1);
   tolua_constant(tolua_S,"KEY_PRESET_2",JIVE_KEY_PRESET_2);
   tolua_constant(tolua_S,"KEY_PRESET_3",JIVE_KEY_PRESET_3);
   tolua_constant(tolua_S,"KEY_PRESET_4",JIVE_KEY_PRESET_4);
   tolua_constant(tolua_S,"KEY_PRESET_5",JIVE_KEY_PRESET_5);
   tolua_constant(tolua_S,"KEY_PRESET_6",JIVE_KEY_PRESET_6);
   tolua_constant(tolua_S,"KEY_PAGE_UP",JIVE_KEY_PAGE_UP);
   tolua_constant(tolua_S,"KEY_PAGE_DOWN",JIVE_KEY_PAGE_DOWN);
   tolua_constant(tolua_S,"KEY_PRINT",JIVE_KEY_PRINT);
   tolua_cclass(tolua_S,"Surface","Surface","",tolua_jive_jive_ui_Surface_free00);
   tolua_beginmodule(tolua_S,"Surface");
    tolua_function(tolua_S,"newRGB",tolua_jive_jive_ui_Surface_newRGB00);
    tolua_function(tolua_S,"newRGBA",tolua_jive_jive_ui_Surface_newRGBA00);
    tolua_function(tolua_S,"loadImage",tolua_jive_jive_ui_Surface_loadImage00);
    tolua_function(tolua_S,"loadImageData",tolua_jive_jive_ui_Surface_loadImageData00);
    tolua_function(tolua_S,"drawText",tolua_jive_jive_ui_Surface_drawText00);
    tolua_function(tolua_S,"free",tolua_jive_jive_ui_Surface_free00);
    tolua_function(tolua_S,"release",tolua_jive_jive_ui_Surface_release00);
    tolua_function(tolua_S,"saveBMP",tolua_jive_jive_ui_Surface_saveBMP00);
    tolua_function(tolua_S,"compare",tolua_jive_jive_ui_Surface_compare00);
    tolua_function(tolua_S,"setOffset",tolua_jive_jive_ui_Surface_setOffset00);
    tolua_function(tolua_S,"setClip",tolua_jive_jive_ui_Surface_setClip00);
    tolua_function(tolua_S,"getClip",tolua_jive_jive_ui_Surface_getClip00);
    tolua_function(tolua_S,"blit",tolua_jive_jive_ui_Surface_blit00);
    tolua_function(tolua_S,"blitClip",tolua_jive_jive_ui_Surface_blitClip00);
    tolua_function(tolua_S,"blitAlpha",tolua_jive_jive_ui_Surface_blitAlpha00);
    tolua_function(tolua_S,"getSize",tolua_jive_jive_ui_Surface_getSize00);
    tolua_function(tolua_S,"getBytes",tolua_jive_jive_ui_Surface_getBytes00);
    tolua_function(tolua_S,"rotozoom",tolua_jive_jive_ui_Surface_rotozoom00);
    tolua_function(tolua_S,"zoom",tolua_jive_jive_ui_Surface_zoom00);
    tolua_function(tolua_S,"shrink",tolua_jive_jive_ui_Surface_shrink00);
    tolua_function(tolua_S,"pixel",tolua_jive_jive_ui_Surface_pixel00);
    tolua_function(tolua_S,"hline",tolua_jive_jive_ui_Surface_hline00);
    tolua_function(tolua_S,"vline",tolua_jive_jive_ui_Surface_vline00);
    tolua_function(tolua_S,"rectangle",tolua_jive_jive_ui_Surface_rectangle00);
    tolua_function(tolua_S,"filledRectangle",tolua_jive_jive_ui_Surface_filledRectangle00);
    tolua_function(tolua_S,"line",tolua_jive_jive_ui_Surface_line00);
    tolua_function(tolua_S,"aaline",tolua_jive_jive_ui_Surface_aaline00);
    tolua_function(tolua_S,"circle",tolua_jive_jive_ui_Surface_circle00);
    tolua_function(tolua_S,"aacircle",tolua_jive_jive_ui_Surface_aacircle00);
    tolua_function(tolua_S,"filledCircle",tolua_jive_jive_ui_Surface_filledCircle00);
    tolua_function(tolua_S,"ellipse",tolua_jive_jive_ui_Surface_ellipse00);
    tolua_function(tolua_S,"aaellipse",tolua_jive_jive_ui_Surface_aaellipse00);
    tolua_function(tolua_S,"filledEllipse",tolua_jive_jive_ui_Surface_filledEllipse00);
    tolua_function(tolua_S,"pie",tolua_jive_jive_ui_Surface_pie00);
    tolua_function(tolua_S,"filledPie",tolua_jive_jive_ui_Surface_filledPie00);
    tolua_function(tolua_S,"trigon",tolua_jive_jive_ui_Surface_trigon00);
    tolua_function(tolua_S,"aatrigon",tolua_jive_jive_ui_Surface_aatrigon00);
    tolua_function(tolua_S,"filledTrigon",tolua_jive_jive_ui_Surface_filledTrigon00);
   tolua_endmodule(tolua_S);
   tolua_cclass(tolua_S,"Tile","Tile","",tolua_jive_jive_ui_Tile_free00);
   tolua_beginmodule(tolua_S,"Tile");
    tolua_function(tolua_S,"fillColor",tolua_jive_jive_ui_Tile_fillColor00);
    tolua_function(tolua_S,"loadImage",tolua_jive_jive_ui_Tile_loadImage00);
    tolua_function(tolua_S,"loadImageData",tolua_jive_jive_ui_Tile_loadImageData00);
    tolua_function(tolua_S,"loadTiles",tolua_jive_jive_ui_Tile_loadTiles00);
    tolua_function(tolua_S,"loadVTiles",tolua_jive_jive_ui_Tile_loadVTiles00);
    tolua_function(tolua_S,"loadHTiles",tolua_jive_jive_ui_Tile_loadHTiles00);
    tolua_function(tolua_S,"free",tolua_jive_jive_ui_Tile_free00);
    tolua_function(tolua_S,"blit",tolua_jive_jive_ui_Tile_blit00);
    tolua_function(tolua_S,"getMinSize",tolua_jive_jive_ui_Tile_getMinSize00);
   tolua_endmodule(tolua_S);
   tolua_cclass(tolua_S,"Font","Font","",tolua_jive_jive_ui_Font__free00);
   tolua_beginmodule(tolua_S,"Font");
    tolua_function(tolua_S,"load",tolua_jive_jive_ui_Font_load00);
    tolua_function(tolua_S,"_free",tolua_jive_jive_ui_Font__free00);
    tolua_function(tolua_S,"width",tolua_jive_jive_ui_Font_width00);
    tolua_function(tolua_S,"capheight",tolua_jive_jive_ui_Font_capheight00);
    tolua_function(tolua_S,"height",tolua_jive_jive_ui_Font_height00);
    tolua_function(tolua_S,"ascend",tolua_jive_jive_ui_Font_ascend00);
    tolua_function(tolua_S,"offset",tolua_jive_jive_ui_Font_offset00);
   tolua_endmodule(tolua_S);
  tolua_endmodule(tolua_S);
 tolua_endmodule(tolua_S);
 tolua_endmodule(tolua_S);
 return 1;
}


#if defined(LUA_VERSION_NUM) && LUA_VERSION_NUM >= 501
 TOLUA_API int luaopen_jive (lua_State* tolua_S) {
 return tolua_jive_open(tolua_S);
};
#endif


