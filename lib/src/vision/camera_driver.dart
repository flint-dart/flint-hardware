/// Supported camera resolutions for embedded vision sensors.
enum CameraResolution {
  qqvga(160, 120, 'QQVGA (160x120)'),
  qvga(320, 240, 'QVGA (320x240)'),
  vga(640, 480, 'VGA (640x480)'),
  svga(800, 600, 'SVGA (800x600)'),
  hd(1280, 720, 'HD (1280x720)');

  const CameraResolution(this.width, this.height, this.label);

  final int width;
  final int height;
  final String label;
}

/// Pixel format encoding for vision frames.
enum PixelFormat {
  rgb565(2, 'RGB565'),
  grayscale(1, 'Grayscale 8-bit'),
  jpeg(0, 'Compressed JPEG'),
  yuv422(2, 'YUV422');

  const PixelFormat(this.bytesPerPixel, this.label);

  final int bytesPerPixel;
  final String label;
}

/// Configuration for an embedded camera sensor (e.g. OV2640 / OV5640).
final class CameraConfig {
  const CameraConfig({
    this.resolution = CameraResolution.qvga,
    this.format = PixelFormat.rgb565,
    this.frameRate = 15,
    this.frameBufferCount = 2,
    this.enableJpegCompression = false,
  });

  final CameraResolution resolution;
  final PixelFormat format;
  final int frameRate;
  final int frameBufferCount;
  final bool enableJpegCompression;

  Map<String, Object?> toJson() => <String, Object?>{
        'resolution': resolution.name,
        'width': resolution.width,
        'height': resolution.height,
        'format': format.name,
        'frameRate': frameRate,
        'frameBufferCount': frameBufferCount,
        'enableJpegCompression': enableJpegCompression,
      };
}
