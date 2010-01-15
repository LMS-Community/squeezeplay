/*
** Copyright 2010 Logitech. All Rights Reserved.
**
** This file is licensed under BSD. Please see the LICENSE file for details.
*/

#include <unistd.h>
#include <sys/times.h>
#include <limits.h>


#include <SDL/SDL.h>
#include <SDL/SDL_gfxPrimitives.h>
#include <SDL/SDL_framerate.h>
#include <SDL/SDL_image.h>
#include <SDL/SDL_ttf.h>

#define LOOP 500



SDL_Surface *makeSurface(Uint16 width, Uint16 height, Uint16 bpp, Uint16 R, Uint16 G, Uint16 B) {
	/*
	 * Use default pixel masks
	 */
	Uint32 Rmask = 0;
	Uint32 Gmask = 0;
	Uint32 Bmask = 0;
	Uint32 Amask = 0;

	if (bpp == 32) {
		/*
		 * Work out the optimium pixel masks for the display with
		 * 32bit alpha surfaces. If we get this wrong a non-optimised
		 * blitter will be used.
		 */
		const SDL_VideoInfo *video_info = SDL_GetVideoInfo();
		if (video_info->vfmt->Rmask < video_info->vfmt->Bmask) {
			Rmask = 0xFF << 0;
			Bmask = 0xFF << 16;
		}
		else {
			Rmask = 0xFF << 16;
			Bmask = 0xFF << 0;
		}

		Gmask = 0xFF << 8;
		Amask = 0xFF << 24;
	}


	SDL_Surface *img = SDL_CreateRGBSurface(SDL_SWSURFACE, width, height, bpp, Rmask, Gmask, Bmask, Amask);

	printf("\tImage is %d bbp mask: %x %x %x %x\n", img->format->BitsPerPixel, img->format->Rmask, img->format->Gmask, img->format->Bmask, img->format->Amask);
	printf("\tImage hardware is %d\n", (img->flags & SDL_HWSURFACE));


	SDL_Rect r;

	r.x = 0;
	r.y = 0;
	r.w = width;
	r.h = height;
	SDL_FillRect(img, &r, SDL_MapRGBA(img->format, R,G,B, 100));

	r.h = height / 2;
	SDL_FillRect(img, &r, SDL_MapRGBA(img->format, R,G,B, 255));

	return img;
}


SDL_Surface *loadImage(const char *filename, int hasAlpha) {
	SDL_Surface *img = IMG_Load(filename);
	printf("\tLoaded image is %d bbp mask: %x %x %x %x\n", img->format->BitsPerPixel, img->format->Rmask, img->format->Gmask, img->format->Bmask, img->format->Amask);

	if (!hasAlpha) {
		const SDL_VideoInfo *video_info = SDL_GetVideoInfo();

		img = SDL_ConvertSurface(img, video_info->vfmt, 0);
		printf("\tConverted image is %d bbp mask: %x %x %x %x\n", img->format->BitsPerPixel, img->format->Rmask, img->format->Gmask, img->format->Bmask, img->format->Amask);
	}

	return img;
}



void timedBlit(SDL_Surface *srf, SDL_Surface *img) {
	FPSmanager manager;
	struct tms tms0, tms1;
	clock_t clk0, clk1;

	printf("\tstart.. \n");
	SDL_Rect r;
	
	SDL_Surface *bg = loadImage("/usr/share/jive/applets/SetupWallpaper/wallpaper/Chapple_1.jpg", 0);

	SDL_initFramerate(&manager);
	SDL_setFramerate(&manager, 20);

	Uint32 t0 = SDL_GetTicks();
	clk0 = times(&tms0);

	int i,j;
	for (i=0; i<LOOP; i++) {
		//SDL_Delay(10);

		SDL_BlitSurface(bg, NULL, srf, NULL);

		r.x = i & 0x7f;
		r.y = i & 0x7f;

		for (j=0; j<50; j++) {
			r.y = (i & 0x7f) + j;
			SDL_BlitSurface(img, NULL, srf, &r);
		}


		//SDL_framerateDelay(&manager);
#if 1
		SDL_Flip(srf);

#else
		/* Use this to test the double buffering */
		SDL_FillRect(srf, NULL, SDL_MapRGBA(srf->format, 255, 0, 0, 0));
		SDL_Flip(srf);
		SDL_FillRect(srf, NULL, SDL_MapRGBA(srf->format, 0, 0, 255, 0));
#endif
	}

	Uint32 t1 = SDL_GetTicks();
	clk1 = times(&tms1);

	printf("\t... took %dms %0.2ffps %0.2f%% user %0.2f%% system %0.2f%% cpu\n",
	       (t1-t0),
	       (LOOP / (double)(t1-t0)) * 1000,
	       ((double)((tms1.tms_utime-tms0.tms_utime)) / (clk1-clk0)) * 100,
	       ((double)((tms1.tms_stime-tms0.tms_stime)) / (clk1-clk0)) * 100,
	       ((double)((tms1.tms_utime-tms0.tms_utime) + (tms1.tms_stime-tms0.tms_stime)) / (clk1-clk0)) * 100
		);
}


int main(int argc, char *args[]) {

	if (SDL_Init(SDL_INIT_VIDEO) == -1) {
		printf("SDL Init failed %s\n", SDL_GetError());
		exit(-1);
	}
	if (TTF_Init() == -1) {
		printf("TTF Init failed %s\n", TTF_GetError());
		exit(-1);
	}


	/* double buffered hardware surface */
	SDL_Surface *srf = SDL_SetVideoMode(240, 320, 16, /*SDL_HWSURFACE | SDL_DOUBLEBUF*/ 0);
	if (!srf) {
		printf("No surface\n");
		exit(-1);
	}

	printf("Screen is %d bbp mask: %x %x %x %x\n", srf->format->BitsPerPixel, srf->format->Rmask, srf->format->Gmask, srf->format->Bmask, srf->format->Amask);
	printf("Screen hardware is %d\n", (srf->flags & SDL_HWSURFACE));


	SDL_Surface *img;
	SDL_Rect r;
	SDL_Color black = { 255, 255, 255 };
#if 0
	SDL_Color white = { 0, 0, 0 };
#endif
	r.x = 0;
	r.y = 0;
	r.w = 320;


	TTF_Font *font = TTF_OpenFont("/usr/share/jive/fonts/FreeSans.ttf", 60);
	if (!font) {
		printf("Can't open font %s\n", TTF_GetError());
		exit(-1);
	}


	/* blended text */
	printf("Blended text:\n");
	img = TTF_RenderText_Blended(font, "Hello World blended", black);
	timedBlit(srf, img);


#if 0
	/* solid text */
	printf("Solid text:\n");
	img = TTF_RenderText_Solid(font, "Hello World solid", black);
	timedBlit(srf, img);


	/* shaded text */
	printf("Shaded text:\n");
	img = TTF_RenderText_Shaded(font, "Hello World shaded", black, white);
	timedBlit(srf, img);


	/* large image (no alpha) */
	printf("Large image (no alpha):\n");
	img = loadImage("/usr/share/jive/applets/SetupWallpaper/wallpaper/stone.png", 0);
	timedBlit(srf, img);


	/* small image (with alpha) */
	printf("Small image (with alpha):\n");
	img = loadImage("/usr/share/jive/applets/QVGAbaseSkin/images/icon_battery_charging.png", 1);
	timedBlit(srf, img);


	/* 16 bit surface */
	printf("Large 16 bit surface:\n");
	img = makeSurface(220, 300, 16, 255,0,0);
	timedBlit(srf, img);


	/* small 16 bit surface */
	printf("Small 16 bit surface:\n");
	img = makeSurface(20, 30, 16, 0,255,0);
	timedBlit(srf, img);


	/* large 32 bit surface */
	printf("Large 32 bit surface:\n");
	img = makeSurface(220, 300, 32, 255,255,0);
	timedBlit(srf, img);


	/* small 32 bit surface */
	printf("Small 32 bit surface:\n");
	img = makeSurface(20, 30, 32, 255,0,0);
	timedBlit(srf, img);


	/* medium 32 bit surface */
	printf("Medium 32 bit surface:\n");
	img = makeSurface(240, 30, 32, 0,255,0);
	timedBlit(srf, img);


	/* all done */
	sleep(5);
#endif

	SDL_Quit();

	return 0;
}

