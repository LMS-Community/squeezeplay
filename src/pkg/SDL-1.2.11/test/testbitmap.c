
/* Simple program:  Test bitmap blits */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "SDL.h"
#include "picture.xbm"

/* Call this instead of exit(), so we can clean up SDL: atexit() is evil. */
static void quit(int rc)
{
	SDL_Quit();
	exit(rc);
}

SDL_Surface *LoadXBM(SDL_Surface *screen, int w, int h, Uint8 *bits)
{
	SDL_Surface *bitmap;
	Uint8 *line;

	/* Allocate the bitmap */
	bitmap = SDL_CreateRGBSurface(SDL_SWSURFACE, w, h, 1, 0, 0, 0, 0);
	if ( bitmap == NULL ) {
		fprintf(stderr, "Couldn't allocate bitmap: %s\n",
						SDL_GetError());
		return(NULL);
	}

	/* Copy the pixels */
	line = (Uint8 *)bitmap->pixels;
	w = (w+7)/8;
	while ( h-- ) {
		memcpy(line, bits, w);
		/* X11 Bitmap images have the bits reversed */
		{ int i, j; Uint8 *buf, byte;
			for ( buf=line, i=0; i<w; ++i, ++buf ) {
				byte = *buf;
				*buf = 0;
				for ( j=7; j>=0; --j ) {
					*buf |= (byte&0x01)<<j;
					byte >>= 1;
				}
			}
		}
		line += bitmap->pitch;
		bits += w;
	}
	return(bitmap);
}


 /* Print modifier info */
    void PrintModifiers( SDLMod mod ){
        printf( "Modifers: " );

        /* If there are none then say so and return */
        if( mod == KMOD_NONE ){
            printf( "None\n" );
            return;
        }

        /* Check for the presence of each SDLMod value */
        /* This looks messy, but there really isn't    */
        /* a clearer way.                              */
        if( mod & KMOD_NUM ) printf( "NUMLOCK " );
        if( mod & KMOD_CAPS ) printf( "CAPSLOCK " );
        if( mod & KMOD_LCTRL ) printf( "LCTRL " );
        if( mod & KMOD_RCTRL ) printf( "RCTRL " );
        if( mod & KMOD_RSHIFT ) printf( "RSHIFT " );
        if( mod & KMOD_LSHIFT ) printf( "LSHIFT " );
        if( mod & KMOD_RALT ) printf( "RALT " );
        if( mod & KMOD_LALT ) printf( "LALT " );
        if( mod & KMOD_CTRL ) printf( "CTRL " );
        if( mod & KMOD_SHIFT ) printf( "SHIFT " );
        if( mod & KMOD_ALT ) printf( "ALT " );
        printf( "\n" );
    }

/* Print all information about a key event */
    void PrintKeyInfo( SDL_KeyboardEvent *key ){
        /* Is it a release or a press? */
        if( key->type == SDL_KEYUP )
            printf( "Release:- " );
        else
            printf( "Press:- " );

        /* Print the hardware scancode first */
        printf( "Scancode: 0x%02X", key->keysym.scancode );
        /* Print the name of the key */
        printf( ", Name: %s", SDL_GetKeyName( key->keysym.sym ) );
        /* We want to print the unicode info, but we need to make */
        /* sure its a press event first (remember, release events */
        /* don't have unicode info                                */
        if( key->type == SDL_KEYDOWN ){
            /* If the Unicode value is less than 0x80 then the    */
            /* unicode value can be used to get a printable       */
            /* representation of the key, using (char)unicode.    */
            printf(", Unicode: " );
            if( key->keysym.unicode < 0x80 && key->keysym.unicode > 0 ){
                printf( "%c (0x%04X)", (char)key->keysym.unicode,
                        key->keysym.unicode );
            }
            else{
                printf( "? (0x%04X)", key->keysym.unicode );
            }
        }
        printf( "\n" );
        /* Print modifier info */
        PrintModifiers( key->keysym.mod );
    }

int main(int argc, char *argv[])
{
	SDL_Surface *screen;
	SDL_Surface *bitmap;
	Uint8  video_bpp;
	Uint32 videoflags;
	Uint8 *buffer;
	int i, k, done;
	SDL_Event event;
	Uint16 *buffer16;
        Uint16 color;
        Uint8  gradient;
	SDL_Color palette[256];

	/* Initialize SDL */
	if ( SDL_Init(SDL_INIT_VIDEO) < 0 ) {
		fprintf(stderr, "Couldn't initialize SDL: %s\n",SDL_GetError());
		return(1);
	}

	video_bpp = 0;
	videoflags = SDL_SWSURFACE;
	while ( argc > 1 ) {
		--argc;
		if ( strcmp(argv[argc-1], "-bpp") == 0 ) {
			video_bpp = atoi(argv[argc]);
			--argc;
		} else
		if ( strcmp(argv[argc], "-warp") == 0 ) {
			videoflags |= SDL_HWPALETTE;
		} else
		if ( strcmp(argv[argc], "-hw") == 0 ) {
			videoflags |= SDL_HWSURFACE;
		} else
		if ( strcmp(argv[argc], "-fullscreen") == 0 ) {
			videoflags |= SDL_FULLSCREEN;
		} else {
			fprintf(stderr,
			"Usage: %s [-bpp N] [-warp] [-hw] [-fullscreen]\n",
								argv[0]);
			quit(1);
		}
	}

	/* Set 640x480 video mode */
	if ( (screen=SDL_SetVideoMode(240,320,video_bpp,videoflags)) == NULL ) {
		fprintf(stderr, "Couldn't set 640x480x%d video mode: %s\n",
						video_bpp, SDL_GetError());
		quit(2);
	}

	if (video_bpp==8) {
		/* Set a gray colormap, reverse order from white to black */
		for ( i=0; i<256; ++i ) {
			palette[i].r = 255-i;
			palette[i].g = 255-i;
			palette[i].b = 255-i;
		}
		SDL_SetColors(screen, palette, 0, 256);
	}

	/* Set the surface pixels and refresh! */
	if ( SDL_LockSurface(screen) < 0 ) {
		fprintf(stderr, "Couldn't lock the display surface: %s\n",
							SDL_GetError());
		quit(2);
	}
	buffer=(Uint8 *)screen->pixels;
	if (screen->format->BytesPerPixel!=2) {
        	for ( i=0; i<screen->h; ++i ) {
        		memset(buffer,(i*255)/screen->h, screen->pitch);
        		buffer += screen->pitch;
        	}
        }
        else
        {
		for ( i=0; i<screen->h; ++i ) {
			gradient=((i*255)/screen->h);
                        color = SDL_MapRGB(screen->format, gradient, gradient, gradient);
                        buffer16=(Uint16*)buffer;
                        for (k=0; k<screen->w; k++)
                        {
                            *(buffer16+k)=color;
                        }
			buffer += screen->pitch;
		}
        }
	SDL_UnlockSurface(screen);
	SDL_UpdateRect(screen, 0, 0, 0, 0);

	/* Load the bitmap */
	bitmap = LoadXBM(screen, picture_width, picture_height,
					(Uint8 *)picture_bits);
	if ( bitmap == NULL ) {
		quit(1);
	}

	SDL_Rect dstfoo;
	dstfoo.x = 30;
	dstfoo.y = 30;
	dstfoo.w = bitmap->w;
	dstfoo.h = bitmap->h;

	for (i=0; i<320; i+= bitmap->h) {
		dstfoo.y = i;
		dstfoo.x += 10;
		SDL_BlitSurface(bitmap, NULL,
				screen, &dstfoo);
		SDL_UpdateRects(screen,1,&dstfoo);
	}

	/* Wait for a keystroke */
	done = 0;
	while ( !done ) {
		/* Check for events */
		while ( SDL_PollEvent(&event) ) {
			switch (event.type) {
				case SDL_MOUSEBUTTONDOWN: {
					SDL_Rect dst;

					dst.x = event.button.x - bitmap->w/2;
					dst.y = event.button.y - bitmap->h/2;
					dst.w = bitmap->w;
					dst.h = bitmap->h;
					SDL_BlitSurface(bitmap, NULL,
								screen, &dst);
					SDL_UpdateRects(screen,1,&dst);
					}
					break;
				case SDL_KEYDOWN:
				case SDL_KEYUP:
					/* Any key press quits the app... */
					PrintKeyInfo( &event.key );

					//done = 1;
					break;
				case SDL_QUIT:
					done = 1;
					break;
				default:
					printf("event.type %d\n", event.type);
					break;
			}
		}
	}

	printf("7\n");
	SDL_FreeSurface(bitmap);
	SDL_Quit();
	return(0);
}
