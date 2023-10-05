# Auto Transcode

A script used to automate the transcoding of News' TV material. The files are originally encoded in dvvideo
and need to be transcoded in H264/x264 for video and the audio encoding can be copied @pcm_s16le.
Use wrapper .mp4. The aspect ratio must be the as source at 16x9, bit rate unspecified (SD @3.5M and HD @8.5M). The script caters for input files with the following structure:
V0, A1CH0, A2CH1 or V0, A1CH0:1 The output will alway be V0, A1CH0:1 Unique mono

## House Formats

```
IMX 30
IMX 50
XDCAM HD 50
AVC-Intra 100
```
