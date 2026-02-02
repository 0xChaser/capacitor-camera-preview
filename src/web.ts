import { WebPlugin } from '@capacitor/core';

import type {
  CameraPreviewOptions,
  CameraPreviewPictureOptions,
  CameraPreviewPlugin,
  CameraPreviewFlashMode,
  CameraSampleOptions,
  CameraOpacityOptions,
  CameraPreviewShapeOptions,
} from './definitions';

export class CameraPreviewWeb extends WebPlugin implements CameraPreviewPlugin {
  private isBackCamera: boolean;

  async start(options: CameraPreviewOptions): Promise<void> {
    return new Promise(async (resolve, reject) => {
      await navigator.mediaDevices
        .getUserMedia({
          audio: !options.disableAudio,
          video: true,
        })
        .then((stream: MediaStream) => {
          stream.getTracks().forEach((track) => track.stop());
        })
        .catch((error) => {
          reject(error);
        });

      const video = document.getElementById('video');
      const parent = document.getElementById(options.parent);

      if (!video) {
        const videoElement = document.createElement('video');
        videoElement.id = 'video';
        videoElement.setAttribute('class', options.className || '');

        if (options.position !== 'rear') {
          videoElement.setAttribute('style', '-webkit-transform: scaleX(-1); transform: scaleX(-1);');
        }

        const userAgent = navigator.userAgent.toLowerCase();
        const isSafari = userAgent.includes('safari') && !userAgent.includes('chrome');

        if (isSafari) {
          videoElement.setAttribute('autoplay', 'true');
          videoElement.setAttribute('muted', 'true');
          videoElement.setAttribute('playsinline', 'true');
        }

        parent.appendChild(videoElement);

        if (navigator.mediaDevices?.getUserMedia) {
          const constraints: MediaStreamConstraints = {
            video: {
              width: { ideal: options.width },
              height: { ideal: options.height },
            },
          };

          if (options.position === 'rear') {
            (constraints.video as MediaTrackConstraints).facingMode = 'environment';
            this.isBackCamera = true;
          } else {
            this.isBackCamera = false;
          }

          navigator.mediaDevices.getUserMedia(constraints).then(
            function (stream) {
              videoElement.srcObject = stream;
              videoElement.play();
              resolve();
            },
            (err) => {
              reject(err);
            },
          );
        }
      } else {
        reject({ message: 'camera already started' });
      }
    });
  }

  async startRecordVideo(): Promise<void> {
    throw this.unimplemented('Not implemented on web.');
  }

  async stopRecordVideo(): Promise<void> {
    throw this.unimplemented('Not implemented on web.');
  }

  async stop(): Promise<any> {
    const video = document.getElementById('video') as HTMLVideoElement;
    if (video) {
      video.pause();

      const st: any = video.srcObject;
      const tracks = st.getTracks();

      for (const track of tracks) {
        track.stop();
      }
      video.remove();
    }
  }

  async capture(options: CameraPreviewPictureOptions): Promise<any> {
    return new Promise((resolve) => {
      const video = document.getElementById('video') as HTMLVideoElement;
      const canvas = document.createElement('canvas');


      const context = canvas.getContext('2d');
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;

      if (!this.isBackCamera) {
        context.translate(video.videoWidth, 0);
        context.scale(-1, 1);
      }
      context.drawImage(video, 0, 0, video.videoWidth, video.videoHeight);

      let base64EncodedImage;

      if (options.quality != undefined) {
        base64EncodedImage = canvas
          .toDataURL('image/jpeg', options.quality / 100.0)
          .replace('data:image/jpeg;base64,', '');
      } else {
        base64EncodedImage = canvas.toDataURL('image/png').replace('data:image/png;base64,', '');
      }

      resolve({
        value: base64EncodedImage,
      });
    });
  }

  async captureSample(_options: CameraSampleOptions): Promise<any> {
    return this.capture(_options);
  }

  async getSupportedFlashModes(): Promise<{
    result: CameraPreviewFlashMode[];
  }> {
    throw new Error('getSupportedFlashModes not supported under the web platform');
  }

  async setFlashMode(_options: { flashMode: CameraPreviewFlashMode | string }): Promise<void> {
    throw new Error('setFlashMode not supported under the web platform');
  }

  async flip(): Promise<void> {
    throw new Error('flip not supported under the web platform');
  }

  async setOpacity(_options: CameraOpacityOptions): Promise<any> {
    const video = document.getElementById('video') as HTMLVideoElement;
    if (!!video && !!_options['opacity']) {
      video.style.setProperty('opacity', _options['opacity'].toString());
    }
  }

  async isCameraStarted(): Promise<{ value: boolean }> {
    throw this.unimplemented('Not implemented on web.');
  }

  async addShape(_options: CameraPreviewShapeOptions): Promise<void> {
    throw this.unimplemented('Not implemented on web.');
  }

  async captureForReview(_options?: CameraPreviewPictureOptions): Promise<void> {
    throw this.unimplemented('Not implemented on web.');
  }

  async confirmReview(): Promise<{ value: string; originalValue: string; editData: string }> {
    throw this.unimplemented('Not implemented on web.');
  }

  async startFromImage(_options: { base64: string; editData?: string }): Promise<void> {
    throw this.unimplemented('Not implemented on web.');
  }

  async cancelReview(): Promise<void> {
    throw this.unimplemented('Not implemented on web.');
  }

  async setZoom(_options: { zoom: number }): Promise<void> {
    throw this.unimplemented('Not implemented on web.');
  }

  async rotateReview(): Promise<void> {
    throw this.unimplemented('Not implemented on web.');
  }
}
