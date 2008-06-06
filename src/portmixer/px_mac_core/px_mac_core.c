/*
 * PortMixer
 * Mac OS X / CoreAudio implementation
 *
 * Copyright (c) 2002
 *
 * Written by Dominic Mazzoni
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

#include <CoreServices/CoreServices.h>
#include <CoreAudio/CoreAudio.h>
#include <AudioToolbox/AudioConverter.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <unistd.h>
#include <stdlib.h>

#include "portaudio.h"
#include "portmixer.h"

#if defined(PaStream)
#define PA_V18
#include "pa_host.h"
#else
#define PA_V19
#include "pa_mac_core_internal.h"
#endif

typedef enum PaDeviceMode
{
    PA_MODE_OUTPUT_ONLY,
    PA_MODE_INPUT_ONLY,
    PA_MODE_IO_ONE_DEVICE,
    PA_MODE_IO_TWO_DEVICES
} PaDeviceMode;

typedef struct PaHostInOut_s
{
    AudioDeviceID      audioDeviceID; /* CoreAudio specific ID */
    int                bytesPerUserNativeBuffer; /* User buffer size in native host format. Depends on numChannels. */
    AudioConverterRef  converter;
    void              *converterBuffer;
    int                numChannels;
} PaHostInOut;

/**************************************************************
 * Structure for internal host specific stream data.
 * This is allocated on a per stream basis.
 */
typedef struct PaHostSoundControl
{
    PaHostInOut        input;
    PaHostInOut        output;
    AudioDeviceID      primaryDeviceID;
} PaHostSoundControl;

// define value of isInput passed to CoreAudio routines
#define IS_INPUT    (true)
#define IS_OUTPUT   (false)

typedef struct PxInfo
{
   AudioDeviceID  input;
   AudioDeviceID  output;
   UInt32         *srcids;
   char           **srcnames;
   int            numsrcs;
} PxInfo;

static PxInfo *Px_FreeInfo( PxInfo *info )
{
   int i;

   if (info) {
      if (info->srcids) {
         free(info->srcids);
      }

      if (info->srcnames) {
         for (i = 0; i < info->numsrcs; i++) {
            if (info->srcnames[i]) {
               free(info->srcnames[i]);
            }
         }
         free(info->srcnames);
      }
      free(info);
   }

   return NULL;
}

int Px_GetNumMixers( void *pa_stream )
{
   return 1;
}

const char *Px_GetMixerName( void *pa_stream, int index )
{
   return "CoreAudio";
}

PxMixer *Px_OpenMixer( void *pa_stream, int index )
{
   PxInfo                     *info;
   PaHostSoundControl         *macInfo;
   OSStatus                   err;
   UInt32                     outSize;
   UInt32                     inID;
   int                        i;

   info = (PxInfo *)calloc(1, sizeof(PxInfo));
   if (!info) {
      return (PxMixer *)info;
   }

#if defined(PA_V18)
   internalPortAudioStream     *past;
   
   past = (internalPortAudioStream *) pa_stream;
   macInfo = (PaHostSoundControl *) past->past_DeviceData;

   info->input = macInfo->input.audioDeviceID;
   info->output = macInfo->output.audioDeviceID;
#endif

#if defined(PA_V19)
   PaMacCoreStream             *pamcs;
   
   pamcs = (PaMacCoreStream *) pa_stream;

   info->input = pamcs->inputDevice;
   info->output = pamcs->outputDevice;
#endif 

   if (info->input == kAudioDeviceUnknown) {
      outSize = sizeof(AudioDeviceID);
      err = AudioHardwareGetProperty(kAudioHardwarePropertyDefaultInputDevice,
                                     &outSize,
                                     &info->input);
      if (err) {
         return Px_FreeInfo(info);
      }
   }

   outSize = sizeof(UInt32);
   err = AudioDeviceGetPropertyInfo(info->input,
                                    0,
                                    IS_INPUT,
                                    kAudioDevicePropertyDataSources,
                                    &outSize,
                                    NULL);
   if (err) {
      return Px_FreeInfo(info);
   }

   info->numsrcs  = outSize / sizeof(UInt32);
   info->srcids   = (UInt32 *)malloc(outSize);
   info->srcnames = (char **)calloc(info->numsrcs, sizeof(char *));

   if (info->srcids == NULL || info->srcnames == NULL) {
      return Px_FreeInfo(info);
   }

   err = AudioDeviceGetProperty(info->input,
                                0,
                                IS_INPUT,
                                kAudioDevicePropertyDataSources,
                                &outSize,
                                info->srcids);
   if (err) {
      return Px_FreeInfo(info);
   }

   for (i = 0; i < info->numsrcs; i++) {
      AudioValueTranslation trans;
      CFStringRef           name;
      Boolean               ok;

      trans.mInputData = &info->srcids[i];
      trans.mInputDataSize = sizeof(UInt32);
      trans.mOutputData = &name;
      trans.mOutputDataSize = sizeof(CFStringRef);

      outSize = sizeof(AudioValueTranslation);
      err = AudioDeviceGetProperty(info->input,
                                   0,
                                   IS_INPUT,
                                   kAudioDevicePropertyDataSourceNameForIDCFString,
                                   &outSize,
                                   &trans);
      if (err) {
         return Px_FreeInfo(info);
      }

      info->srcnames[i] = malloc(CFStringGetLength(name)+1);
      if (info->srcnames[i] == NULL) {
         return Px_FreeInfo(info);
      }

      ok = CFStringGetCString(name,
                              info->srcnames[i],
                              CFStringGetLength(name)+1,
                              kCFStringEncodingISOLatin1);
      if (!ok) {
         return Px_FreeInfo(info);
      }
   }

   return (PxMixer *)info;
}

/*
 Px_CloseMixer() closes a mixer opened using Px_OpenMixer and frees any
 memory associated with it. 
*/

void Px_CloseMixer(PxMixer *mixer)
{
   PxInfo *info = (PxInfo *)mixer;

   Px_FreeInfo(info);
}

/*
 Master (output) volume
*/

PxVolume Px_GetMasterVolume( PxMixer *mixer )
{
   PxInfo *info = (PxInfo *)mixer;

   return 0.0;
}

void Px_SetMasterVolume( PxMixer *mixer, PxVolume volume )
{
   PxInfo *info = (PxInfo *)mixer;
}

/*
 PCM output volume
*/

static PxVolume Px_GetVolume(AudioDeviceID device, Boolean isInput)
{
   OSStatus err;
   UInt32   outSize;
   Float32  vol, maxvol=0.0;
   UInt32   mute, anymuted=0;
   int ch;
   PxVolume max;

   for(ch=0; ch<=2; ch++) {
      outSize = sizeof(Float32);
      err = AudioDeviceGetProperty(device, ch, isInput,
                                   kAudioDevicePropertyVolumeScalar,
                                   &outSize, &vol);
      if (!err) {
         if (vol > maxvol)
            maxvol = vol;
      }

      outSize = sizeof(UInt32);
      err = AudioDeviceGetProperty(device, ch, isInput,
                                   kAudioDevicePropertyMute,
                                   &outSize, &mute);

      if (!err) {
         if (mute)
            anymuted = 1;
      }
   }

   if (anymuted)
      maxvol = 0.0;

   return maxvol;
}

static void Px_SetVolume(AudioDeviceID device, Boolean isInput,
                         PxVolume volume)
{
   Float32  vol = volume;
   UInt32 mute = 0;
   int ch;
   OSStatus err;

   /* Implement a passive attitude towards muting.  If they
      drag the volume above 0.05, unmute it.  But if they
      drag the volume down below that, just set the volume,
      don't actually mute.
   */

   for(ch=0; ch<=2; ch++) {
      err =  AudioDeviceSetProperty(device, 0, ch, isInput,
                                    kAudioDevicePropertyVolumeScalar,
                                    sizeof(Float32), &vol);
      if (vol > 0.05) {
         err =  AudioDeviceSetProperty(device, 0, ch, isInput,
                                       kAudioDevicePropertyMute,
                                       sizeof(UInt32), &mute);
      }
   }
}

int Px_SupportsPCMOutputVolume( PxMixer* mixer ) 
{
	return 1 ;
}

PxVolume Px_GetPCMOutputVolume( PxMixer *mixer )
{
   PxInfo *info = (PxInfo *)mixer;

   return Px_GetVolume(info->output, IS_OUTPUT);
}

void Px_SetPCMOutputVolume( PxMixer *mixer, PxVolume volume )
{
   PxInfo *info = (PxInfo *)mixer;

   Px_SetVolume(info->output, IS_OUTPUT, volume);
}

/*
 All output volumes
*/

int Px_GetNumOutputVolumes( PxMixer *mixer )
{
   PxInfo *info = (PxInfo *)mixer;

   return 1;
}

const char *Px_GetOutputVolumeName( PxMixer *mixer, int i )
{
   if (i == 0)
      return "PCM";
   else
      return "";
}

PxVolume Px_GetOutputVolume( PxMixer *mixer, int i )
{
   return Px_GetPCMOutputVolume(mixer);
}

void Px_SetOutputVolume( PxMixer *mixer, int i, PxVolume volume )
{
   Px_SetPCMOutputVolume(mixer, volume);
}

/*
 Input sources
*/

int Px_GetNumInputSources( PxMixer *mixer )
{
   PxInfo *info = (PxInfo *)mixer;
   OSStatus err;
   UInt32   outSize;

   return info->numsrcs;
}

const char *Px_GetInputSourceName( PxMixer *mixer, int i)
{
   PxInfo *info = (PxInfo *)mixer;

   if (i >= info->numsrcs)
      return "";

   return info->srcnames[i];
}

int Px_GetCurrentInputSource( PxMixer *mixer )
{
   PxInfo *info = (PxInfo *)mixer;
   OSStatus err;
   UInt32   outSize;
   UInt32   outID = 0;
   int      i;

   outSize = sizeof(UInt32);
   err = AudioDeviceGetProperty(info->input,
                                0,
                                IS_INPUT,
                                kAudioDevicePropertyDataSource,
                                &outSize,
                                &outID);

   if (!err) {
      for (i = 0; i < info->numsrcs; i++) {
         if (info->srcids[i] == outID) {
            return i;
         }
      }
   }

   return -1;
}

void Px_SetCurrentInputSource( PxMixer *mixer, int i )
{
   PxInfo *info = (PxInfo *)mixer;
   OSStatus err;

   if (i >= info->numsrcs) {
      return;
   }

   err = AudioDeviceSetProperty(info->input,
                                0,
                                0,
                                IS_INPUT,
                                kAudioDevicePropertyDataSource,
                                sizeof(UInt32),
                                &info->srcids[i]);

   return;
}

/*
 Input volume
*/

PxVolume Px_GetInputVolume( PxMixer *mixer )
{
   PxInfo *info = (PxInfo *)mixer;

   return Px_GetVolume(info->input, IS_INPUT);
}

void Px_SetInputVolume( PxMixer *mixer, PxVolume volume )
{
   PxInfo *info = (PxInfo *)mixer;

   Px_SetVolume(info->input, IS_INPUT, volume);
}

/*
  Balance
*/

int Px_SupportsOutputBalance( PxMixer *mixer )
{
   return 0;
}

PxBalance Px_GetOutputBalance( PxMixer *mixer )
{
   return 0.0;
}

void Px_SetOutputBalance( PxMixer *mixer, PxBalance balance )
{
}

/*
  Playthrough
*/

int Px_SupportsPlaythrough( PxMixer *mixer )
{
   return 1;
}

PxVolume Px_GetPlaythrough( PxMixer *mixer )
{
   PxInfo *info = (PxInfo *)mixer;
   OSStatus err;
   UInt32   outSize;
   UInt32   flag;

   outSize = sizeof(UInt32);
   err =  AudioDeviceGetProperty(info->output, 0, IS_OUTPUT,
                                 kAudioDevicePropertyPlayThru,
                                 &outSize, &flag);
   if (err)
      return 0.0;
 
   if (flag)
      return 1.0;
   else
      return 0.0;
}

void Px_SetPlaythrough( PxMixer *mixer, PxVolume volume )
{
   PxInfo *info = (PxInfo *)mixer;
   UInt32 flag = (volume > 0.01);
   OSStatus err;

   err =  AudioDeviceSetProperty(info->output, 0, 0, IS_OUTPUT,
                                 kAudioDevicePropertyPlayThru,
                                 sizeof(UInt32), &flag);
}

