/*

Read uncompressed format produced by libgd from SqueezeCenter.
- only supports truecolor at present - 32 bits per pixel with alpha channel

*/

#include <stdio.h>
#include <string.h>

#include "SDL_image.h"

#define MAGIC 65534

/* See if an image is contained in a data source */
int IMG_isGD(SDL_RWops *src)
{
	int start;
	int is_GD;
	Uint16 magic;

	start = SDL_RWtell(src);

	magic = SDL_ReadBE16(src);

	is_GD = (magic == MAGIC);

	SDL_RWseek(src, start, SEEK_SET);

	return(is_GD);
}

#include "SDL_error.h"
#include "SDL_video.h"
#include "SDL_endian.h"

static SDL_Surface *LoadGD_RW (SDL_RWops *src, int freesrc)
{
	/*
	 GD Format:
	  Uint16 - magic no = 65534
	  Uint16 - width
	  Uint16 - height
	  Uint8  - truecolor
	  Uint32 - transparent
	  <pixels - 32 bits per pixel>
	 */

	Uint16 magic;
	Uint16 w, h;
	Uint8  truecolor;
	Uint32 transparent;
	SDL_Surface *surface = NULL;
	Uint32 *ptr, pixel;
	int was_error = 0;
	int i;

	if ( src == NULL ) {
		was_error = 1;
		goto done;
	}

	magic = SDL_ReadBE16(src);
	w = SDL_ReadBE16(src);
	h = SDL_ReadBE16(src);
	SDL_RWread(src, &truecolor, 1, 1);
	transparent = SDL_ReadBE32(src);

	if ( magic != MAGIC || !truecolor ) {
		printf("GD Format not supported\n");
		was_error = 1;
		goto done;
	}		

	// create a surface
	surface = SDL_CreateRGBSurface(SDL_SWSURFACE, w, h, 32, 0x0000FF00, 0x00FF0000, 0xFF000000, 0x000000FF);

	if ( surface == NULL ) {
		was_error = 1;
		goto done;
	}

	// copy bits and manipulate alpha channel (GD uses 7f for transparent)
	ptr = surface->pixels;
	SDL_RWread(src, surface->pixels, w*h*4, 1);
	for (i = 0; i < w*h; i++) {
		pixel = *ptr;
		*ptr= pixel & 0x0000007f ? 0x00000000 : pixel | 0x000000ff;
		ptr++;
	}

done:
	if ( was_error ) {
		if ( surface ) {
			SDL_FreeSurface(surface);
		}
		surface = NULL;
	}
	if ( freesrc && src ) {
		SDL_RWclose(src);
	}
	return(surface);
}

SDL_Surface *IMG_LoadGD_RW(SDL_RWops *src)
{
	return(LoadGD_RW(src, 0));
}

