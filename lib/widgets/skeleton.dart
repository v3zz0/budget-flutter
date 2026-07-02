import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme.dart';

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({super.key, this.width, this.height = 16, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class SkeletonShimmer extends StatelessWidget {
  final Widget child;
  const SkeletonShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.card,
      highlightColor: AppColors.input,
      child: child,
    );
  }
}

// Skeleton per la Dashboard
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 3 mini card riepilogo
          Row(
            children: List.generate(3, (i) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                child: const SkeletonBox(height: 70, radius: 12),
              ),
            )),
          ),
          const SizedBox(height: 16),
          // 5 righe categorie
          ...List.generate(5, (_) => const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: SkeletonBox(height: 80, radius: 12),
          )),
        ],
      ),
    );
  }
}

// Skeleton per il Salvadanaio
class SalvadanaiSkeleton extends StatelessWidget {
  const SalvadanaiSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonBox(height: 130, radius: 20),
          SizedBox(height: 16),
          SkeletonBox(height: 220, radius: 20),
          SizedBox(height: 16),
          SkeletonBox(height: 160, radius: 20),
        ],
      ),
    );
  }
}
