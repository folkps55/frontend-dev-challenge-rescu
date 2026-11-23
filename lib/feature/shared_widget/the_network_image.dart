import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Standard network image with a shimmer placeholder and bounded memory decode size.
class TheNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const TheNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveWidth = (width != null && width!.isFinite)
            ? width!
            : (constraints.maxWidth.isFinite ? constraints.maxWidth : null);
        final effectiveHeight = (height != null && height!.isFinite)
            ? height!
            : (constraints.maxHeight.isFinite ? constraints.maxHeight : null);

        // กำหนดเพียง 1 ด้าน (กว้างหรือสูง) เพื่อให้ ResizeImage รักษาสัดส่วนภาพเดิมโดยไม่ยืดเบี้ยว
        final int? memCacheWidth =
            (effectiveWidth != null && effectiveWidth > 0)
                ? (effectiveWidth * devicePixelRatio).round()
                : null;
        final int? memCacheHeight = (memCacheWidth == null &&
                effectiveHeight != null &&
                effectiveHeight > 0)
            ? (effectiveHeight * devicePixelRatio).round()
            : null;

        final image = CachedNetworkImage(
          imageUrl: url,
          width: width,
          height: height,
          fit: fit,
          memCacheWidth: memCacheWidth,
          memCacheHeight: memCacheHeight,
          placeholder: (context, _) => Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(width: width, height: height, color: Colors.white),
          ),
          errorWidget: (context, _, __) => Container(
            width: width,
            height: height,
            color: Colors.grey.shade200,
            child: const Icon(Icons.image_not_supported_outlined),
          ),
        );

        if (borderRadius == null) {
          return image;
        }

        return ClipRRect(
          borderRadius: borderRadius!,
          child: image,
        );
      },
    );
  }
}