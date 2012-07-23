/*
 * PortMixer
 * Linux ALSA Implementation
 *
 * Copyright (c) 2002, 2006
 *
 * Written by Dominic Mazzoni
 *        and Leland Lucius
 *
 * PortMixer is intended to work side-by-side with PortAudio,
 * the Portable Real-Time Audio Library by Ross Bencina and
 * Phil Burk.
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files
 * (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge,
 * publish, distribute, sublicense, and/or sell copies of the Software,
 * and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * Any person wishing to distribute modifications to the Software is
 * requested to send the modifications to the original developer so that
 * they can be incorporated into the canonical version.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
 * ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 * CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <alsa/asoundlib.h>

#include "portaudio.h"
#include "pa_unix_oss.h"

#include "portmixer.h"
#include "px_mixer.h"

#if !defined(FALSE)
#define FALSE 0
#endif

#if !defined(TRUE)
#define TRUE 1
#endif

typedef struct PxSelem
{
   snd_mixer_selem_id_t *sid;
   snd_mixer_elem_t *elem;
   char *name;
} PxSelem;

typedef struct PxDev
{
   snd_mixer_t *handle;
   int card;

   int numselems;
   PxSelem *selems;
} PxDev;

typedef struct PxInfo
{
   int numMixers;
   char *mixers;

   PxDev capture;
   PxDev playback;
} PxInfo;

static int open_mixer(PxDev *dev, int card, int playback)
{
   snd_mixer_elem_t *elem;
   char name[256];
   int err;
   int i;

   sprintf(name, "hw:%d", card);

   dev->card = card;
   dev->handle = NULL;

   do {
      err = snd_mixer_open(&dev->handle, 0);
      if (err < 0) {
         break;
      }

      err = snd_mixer_attach(dev->handle, name);
      if (err < 0) {
         break;
      }

      err = snd_mixer_selem_register(dev->handle, NULL, NULL);
      if (err < 0) {
         break;
      }

      err = snd_mixer_load(dev->handle);
      if (err < 0) {
         break;
      }

      for (elem = snd_mixer_first_elem(dev->handle);
           elem != NULL;
           elem = snd_mixer_elem_next(elem))
      {
         if (!playback) {
            if (!snd_mixer_selem_has_capture_volume(elem) &&
                !snd_mixer_selem_has_capture_switch(elem) &&
                !snd_mixer_selem_has_common_volume(elem)) {
               continue;
            }
         }
         else {
            if (!snd_mixer_selem_has_playback_volume(elem) &&
                !snd_mixer_selem_has_playback_switch(elem) &&
                !snd_mixer_selem_has_common_volume(elem)) {
               continue;
            }
         }
         dev->numselems++;
      }

      dev->selems = calloc(dev->numselems, sizeof(PxSelem));
      if (dev->selems == NULL) {
         break;
      }

      i = 0;
      for (elem = snd_mixer_first_elem(dev->handle);
           elem != NULL;
           elem = snd_mixer_elem_next(elem))
      {
         if (!playback) {
            if (!snd_mixer_selem_has_capture_volume(elem) &&
                !snd_mixer_selem_has_capture_switch(elem) &&
                !snd_mixer_selem_has_common_volume(elem)) {
               continue;
            }
         }
         else {
            if (!snd_mixer_selem_has_playback_volume(elem) &&
                !snd_mixer_selem_has_playback_switch(elem) &&
                !snd_mixer_selem_has_common_volume(elem)) {
               continue;
            }
         }
               
         if (snd_mixer_selem_id_malloc(&dev->selems[i].sid) < 0) {
            break;
         }

         snd_mixer_selem_get_id(elem, dev->selems[i].sid);
         dev->selems[i].elem = elem;

         snprintf(name,
                  sizeof(name),
                  "%s:%d",
                  snd_mixer_selem_id_get_name(dev->selems[i].sid),
                  snd_mixer_selem_id_get_index(dev->selems[i].sid));

         dev->selems[i].name = strdup(name);
         if (!dev->selems[i].name) {
            break;
         }
         i++;
      }

      if (i == dev->numselems) {
         return TRUE;
      }

   } while (FALSE);

   if (dev->selems) {
      for (i = 0; i < dev->numselems; i++) {
         if (dev->selems[i].sid) {
            snd_mixer_selem_id_free(dev->selems[i].sid);
         }
         if (dev->selems[i].name) {
            free(dev->selems[i].name);
         }
      }
      free(dev->selems);
      dev->selems = NULL;
   }

   if (dev->handle) {
      snd_mixer_close(dev->handle);
      dev->handle = NULL;
   }

   return FALSE;
}

int OpenMixer_Linux_ALSA(px_mixer *Px, int index)
{
   PxInfo *info;
   int card;

   if (!initialize(Px)) {
      return FALSE;
   }

   info = (PxInfo *) Px->info;

   if (PaAlsa_GetStreamInputCard(Px->pa_stream, &card) == paNoError) {
      if (!open_mixer(&info->capture, card, FALSE)) {
         return cleanup(Px);
      }
   }

   if (PaAlsa_GetStreamOutputCard(Px->pa_stream, &card) == paNoError) {
      if (!open_mixer(&info->playback, card, TRUE)) {
         return cleanup(Px);
      }
   }

   return TRUE;
}

static int initialize(px_mixer *Px)
{
   Px->info = calloc(1, sizeof(PxInfo));
   if (Px->info == NULL) {
      return FALSE;
   }

   Px->CloseMixer = close_mixer;
   Px->GetNumMixers = get_num_mixers;
   Px->GetMixerName = get_mixer_name;
   Px->GetMasterVolume = get_master_volume;
   Px->SetMasterVolume = set_master_volume;
   Px->SupportsPCMOutputVolume = supports_pcm_output_volume;
   Px->GetPCMOutputVolume = get_pcm_output_volume;
   Px->SetPCMOutputVolume = set_pcm_output_volume;
   Px->GetNumOutputVolumes = get_num_output_volumes;
   Px->GetOutputVolumeName = get_output_volume_name;
   Px->GetOutputVolume = get_output_volume;
   Px->SetOutputVolume = set_output_volume;
   Px->GetNumInputSources = get_num_input_sources;
   Px->GetInputSourceName = get_input_source_name;
   Px->GetCurrentInputSource = get_current_input_source;
   Px->SetCurrentInputSource = set_current_input_source;
   Px->GetInputVolume = get_input_volume;
   Px->SetInputVolume = set_input_volume;
   
//   Px->SupportsOutputBalance = supports_output_balance;
//   Px->GetOutputBalance = get_output_balance;
//   Px->SetOutputBalance = set_output_balance; 
//   Px->SupportsPlaythrough = supports_play_through;
//   Px->GetPlaythrough = get_play_through;
//   Px->SetPlaythrough = set_play_through;
   
   return TRUE;
}

static int cleanup(px_mixer *Px)
{
   PxInfo *info = (PxInfo *)Px->info;
   int i;

   if (info->capture.selems) {
      for (i = 0; i < info->capture.numselems; i++) {
         if (info->capture.selems[i].sid) {
            snd_mixer_selem_id_free(info->capture.selems[i].sid);
         }
         if (info->capture.selems[i].name) {
            free(info->capture.selems[i].name);
         }
      }
      free(info->capture.selems);
   }

   if (info->capture.handle) {
      snd_mixer_close(info->capture.handle);
   }

   if (info->playback.selems) {
      for (i = 0; i < info->playback.numselems; i++) {
         if (info->playback.selems[i].sid) {
            snd_mixer_selem_id_free(info->playback.selems[i].sid);
         }
         if (info->playback.selems[i].name) {
            free(info->playback.selems[i].name);
         }
      }
      free(info->playback.selems);
   }

  if (info->playback.handle) {
      snd_mixer_close(info->playback.handle);
   }

   if (info) {
      free(info);
      Px->info = NULL;
   }

   return FALSE;
}

static PxVolume get_volume_indexed(PxDev *dev, int i, int playback)
{
   snd_mixer_elem_t *elem;
   long vol, min, max;

   if (!dev->handle) {
      return 0.0;
   }

   if (i < 0 || i > dev->numselems) {
      return 0.0;
   }

   elem = dev->selems[i].elem;
   if (playback) {
      snd_mixer_selem_get_playback_volume_range(elem, &min, &max);
      if (snd_mixer_selem_has_playback_channel(elem, SND_MIXER_SCHN_FRONT_LEFT)) {
         snd_mixer_selem_get_playback_volume(elem, SND_MIXER_SCHN_FRONT_LEFT, &vol);
         return (PxVolume) vol / (max - min);
      }
   }
   else {
      snd_mixer_selem_get_capture_volume_range(elem, &min, &max);
      if (snd_mixer_selem_has_capture_channel(elem, SND_MIXER_SCHN_FRONT_LEFT)) {
         snd_mixer_selem_get_capture_volume(elem, SND_MIXER_SCHN_FRONT_LEFT, &vol);
         return (PxVolume) vol / (max - min);
      }
   }
   
   return 0.0;
}

static PxVolume get_volume(PxDev *dev, const char *name, int playback)
{
   const char *sname;
   int i;

   if (!dev->handle) {
      return 0.0;
   }

   for (i = 0; i < dev->numselems; i++) {
      sname = snd_mixer_selem_id_get_name(dev->selems[i].sid);
      if (strcmp(sname, name) == 0) {
         return get_volume_indexed(dev, i, playback);
      }
   }

   return 0.0;
}

static void set_volume_indexed(PxDev *dev, int i, PxVolume volume, int playback)
{
   snd_mixer_elem_t *elem;
   long vol, min, max;
   int j;

   if (!dev->handle) {
      return;
   }

   if (i < 0 || i > dev->numselems) {
      return;
   }

   elem = dev->selems[i].elem;
   if (playback) {
      snd_mixer_selem_get_playback_volume_range(elem, &min, &max);
      for (j = 0; j < SND_MIXER_SCHN_LAST; j++) {
         if (snd_mixer_selem_has_playback_channel(elem, j)) {
            vol = (long) (volume * (max - min) + 0.5);
            snd_mixer_selem_set_playback_volume(elem, j, vol);
         }
      }
   }
   else {
      snd_mixer_selem_get_capture_volume_range(elem, &min, &max);
      for (j = 0; j < SND_MIXER_SCHN_LAST; j++) {
         if (snd_mixer_selem_has_capture_channel(elem, j)) {
            vol = (long) (volume * (max - min) + 0.5);
            snd_mixer_selem_set_capture_volume(elem, j, vol);
         }
      }
   }

   return;
}

static void set_volume(PxDev *dev, const char *name, PxVolume volume, int playback)
{
   const char *sname;
   int i;

   if (!dev->handle) {
      return;
   }

   for (i = 0; i < dev->numselems; i++) {
      sname = snd_mixer_selem_id_get_name(dev->selems[i].sid);
      if (strcmp(sname, name) == 0) {
         set_volume_indexed(dev, i, volume, playback);
         break;
      }
   }

   return;
}

static void close_mixer(px_mixer *Px)
{
   cleanup(Px);

   return;
}

static int get_num_mixers(px_mixer *Px)
{
   PxInfo *info = (PxInfo *)Px->info;
   int i;
   int fd;

   info->numMixers = 0;
#if 0
   for (i = 0; i < MIXER_COUNT_MAX; i++) {
      strcpy(info->mixers[i], MIXER_NAME_BASE);

      if (i == 0)
         info->mixers[i][strlen(MIXER_NAME_BASE)] = 0;
      else
         info->mixers[i][strlen(MIXER_NAME_BASE)] = '0' + (i - 1);
         
      fd = open(info->mixers[i], O_RDWR);
      if (fd >= 0) {
         info->mixerIndexes[info->numMixers] = i;
         info->numMixers++;
         close(fd);
      }
   }
#endif
   return info->numMixers;
}

static const char *get_mixer_name(px_mixer *Px, int i)
{
   PxInfo *info = (PxInfo *)Px->info;
#if 0
   if (info->numMixers <= 0)
      get_num_mixers(Px);

   if (i >= 0 && i < info->numMixers) {
      return info->mixers[info->mixerIndexes[i]];
   }
#endif
   return NULL;
}

/*
|| Master volume
*/

static PxVolume get_master_volume(px_mixer *Px)
{
   PxInfo *info = (PxInfo *)Px->info;

   return get_volume(&info->playback, "Master", TRUE);
}

static void set_master_volume(px_mixer *Px, PxVolume volume)
{
   PxInfo *info = (PxInfo *)Px->info;

   set_volume(&info->playback, "Master", volume, TRUE);

   return;
}

/*
|| Main output volume
*/

static int supports_pcm_output_volume(px_mixer *Px)
{
   PxInfo *info = (PxInfo *)Px->info;
   snd_mixer_selem_id_t *id;

   if (info->playback.handle) {
      snd_mixer_selem_id_alloca(&id);
      snd_mixer_selem_id_set_name(id, "PCM");

      if (snd_mixer_find_selem(info->playback.handle, id)) {
         return TRUE;
      }
   }

   return FALSE;
}

static PxVolume get_pcm_output_volume(px_mixer *Px)
{
   PxInfo *info = (PxInfo *)Px->info;

   return get_volume(&info->playback, "PCM", TRUE);
}

static void set_pcm_output_volume(px_mixer *Px, PxVolume volume)
{
   PxInfo *info = (PxInfo *)Px->info;

   set_volume(&info->playback, "PCM", volume, TRUE);

   return;
}

/*
|| All output volumes
*/

static int get_num_output_volumes(px_mixer *Px)
{
   PxInfo *info = (PxInfo *)Px->info;

   if (info->playback.handle) {
      return info->playback.numselems;
   }

   return 0;
}

static const char *get_output_volume_name(px_mixer *Px, int i)
{
   PxInfo *info = (PxInfo *)Px->info;
   snd_mixer_elem_t *elem;
   char name[64];
   int ndx = 0;

   if (info->playback.handle) {
      if (i >= 0 && i < info->playback.numselems) {
         return info->playback.selems[i].name;
      }
   }

   return NULL;
}

static PxVolume get_output_volume(px_mixer *Px, int i)
{
   PxInfo *info = (PxInfo *)Px->info;

   return get_volume_indexed(&info->playback, i, TRUE);
}

static void set_output_volume(px_mixer *Px, int i, PxVolume volume)
{
   PxInfo *info = (PxInfo *)Px->info;

   set_volume_indexed(&info->playback, i, volume, TRUE);

   return;
}

/*
|| Input source
*/

static int get_num_input_sources(px_mixer *Px)
{
   PxInfo *info = (PxInfo *)Px->info;

   if (info->capture.handle) {
      return info->capture.numselems;
   }

   return 0;
}

static const char *get_input_source_name(px_mixer *Px, int i)
{
   PxInfo *info = (PxInfo *)Px->info;

   if (info->capture.handle) {
      if (i >= 0 && i < info->capture.numselems) {
         return info->capture.selems[i].name;
      }
   }

   return NULL;
}

static int get_current_input_source(px_mixer *Px)
{
   PxInfo *info = (PxInfo *)Px->info;
   snd_mixer_elem_t *elem;
   int sw;
   int i, j;

   if (!info->capture.handle) {
      return -1;
   }

   for (i = 0; i < info->capture.numselems; i++) {
      elem = info->capture.selems[i].elem;
      for (j = 0; j <= SND_MIXER_SCHN_LAST; j++) {
         if (snd_mixer_selem_has_capture_switch(elem)) {
            snd_mixer_selem_get_capture_switch(elem, j, &sw);
            if (sw) {
               return i;
            }
         }
      }
   }

   return -1; /* none */
}

static void set_current_input_source(px_mixer *Px, int i)
{
   PxInfo *info = (PxInfo *)Px->info;
   snd_mixer_elem_t *elem;
   int j;

   if (!info->capture.handle) {
      return;
   }

   if (i < 0 || i >= info->capture.numselems) {
      return;
   }

   elem = info->capture.selems[i].elem;
   for (j = 0; j <= SND_MIXER_SCHN_LAST; j++) {
      if (snd_mixer_selem_has_capture_switch(elem)) {
         snd_mixer_selem_set_capture_switch(elem, j, TRUE);
      }
   }

   return;
}

/*
|| Input volume
*/

static PxVolume get_input_volume(px_mixer *Px)
{
   PxInfo *info = (PxInfo *)Px->info;

   return get_volume(&info->capture, "Capture", FALSE);
}

static void set_input_volume(px_mixer *Px, PxVolume volume)
{
   PxInfo *info = (PxInfo *)Px->info;

   set_volume(&info->capture, "Capture", volume, FALSE);

   return;
}
