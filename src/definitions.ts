export type CameraPosition = 'rear' | 'front';
export interface CameraPreviewOptions {
  parent?: string;
  className?: string;
  width?: number;
  height?: number;
  x?: number;
  y?: number;
  toBack?: boolean;
  paddingBottom?: number;
  rotateWhenOrientationChanged?: boolean;
  position?: CameraPosition | string;
  storeToFile?: boolean;
  disableExifHeaderStripping?: boolean;
  enableHighResolution?: boolean;
  disableAudio?: boolean;
  lockAndroidOrientation?: boolean;
  enableOpacity?: boolean;
  enableZoom?: boolean;
}
export interface CameraPreviewPictureOptions {
  height?: number;
  width?: number;
  quality?: number;
}

export interface CameraSampleOptions {
  quality?: number;
}

export type CameraPreviewFlashMode = 'off' | 'on' | 'auto' | 'red-eye' | 'torch';

export interface CameraOpacityOptions {
  opacity?: number;
}

export interface CameraPreviewShapeOptions {
  type?: string;
  color?: string;
}

export interface CameraPreviewPlugin {
  start(options: CameraPreviewOptions): Promise<void>;
  startRecordVideo(options: CameraPreviewOptions): Promise<void>;
  stop(): Promise<void>;
  stopRecordVideo(): Promise<void>;
  capture(options: CameraPreviewPictureOptions): Promise<{ value: string }>;
  captureSample(options: CameraSampleOptions): Promise<{ value: string }>;
  getSupportedFlashModes(): Promise<{
    result: CameraPreviewFlashMode[];
  }>;
  setFlashMode(options: { flashMode: CameraPreviewFlashMode | string }): Promise<void>;
  flip(): Promise<void>;
  setOpacity(options: CameraOpacityOptions): Promise<void>;
  isCameraStarted(): Promise<{ value: boolean }>;
  addShape(options: CameraPreviewShapeOptions): Promise<void>;
  captureForReview(options?: CameraPreviewPictureOptions): Promise<void>;
  confirmReview(): Promise<{ value: string; originalValue: string; editData: string }>;
  startFromImage(options: { base64: string; editData?: string }): Promise<void>;
  cancelReview(): Promise<void>;
  setZoom(options: { zoom: number }): Promise<void>;
  rotateReview(): Promise<void>;
}
