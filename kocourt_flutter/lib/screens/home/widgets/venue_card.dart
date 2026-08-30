import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/icons.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';

class VenueCard extends StatefulWidget {
  final Map<String, dynamic> venue;
  final int index;
  final bool isFavorited;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const VenueCard({
    super.key,
    required this.venue,
    required this.index,
    required this.isFavorited,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  State<VenueCard> createState() => _VenueCardState();
}

class _VenueCardState extends State<VenueCard> with TickerProviderStateMixin {
  late final AnimationController _heartController;
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  bool _pressing = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    // Cap stagger delay to avoid long delays on large lists
    final delay = Duration(milliseconds: 80 * widget.index.clamp(0, 5));
    Future.delayed(delay, () {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _heartController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _onFavoriteTap() {
    _heartController.forward(from: 0);
    widget.onFavorite();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = getVenueImage(widget.venue);
    final rate = widget.venue['hourly_rate'];
    final rating = widget.venue['avg_rating'];
    final bookingCount = widget.venue['booking_count'];
    final reviewCount = widget.venue['review_count'];
    final sportType = widget.venue['sport_type'] ?? '';
    final category = sportCategories.firstWhere(
      (c) => c.id == sportType,
      orElse: () => sportCategories.first,
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressing = true),
          onTapUp: (_) => setState(() => _pressing = false),
          onTapCancel: () => setState(() => _pressing = false),
          child: AnimatedScale(
            scale: _pressing ? 0.975 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image section
                  Stack(
                    children: [
                      // Main image
                      AspectRatio(
                        aspectRatio: 16 / 10,
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppColors.surfaceDim,
                            child: Center(
                              child: Icon(Icons.sports_tennis, size: 40, color: AppColors.textDisabled),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.surfaceDim,
                            child: Center(
                              child: Icon(Icons.image_not_supported_outlined, size: 40, color: AppColors.textDisabled),
                            ),
                          ),
                        ),
                      ),

                      // Bottom gradient overlay
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.5),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.0, 0.4, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Top row: badge + favorite
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Row(
                          children: [
                            if (widget.index == 0)
                              _AnimatedBadge(
                                text: 'POPULAR',
                                color: AppColors.primary,
                                textColor: Colors.white,
                                icon: Icons.local_fire_department_rounded,
                              )
                            else if (sportType.isNotEmpty)
                              _AnimatedBadge(
                                text: category.label.toUpperCase(),
                                emoji: category.emoji,
                                color: Colors.black.withValues(alpha: 0.5),
                                textColor: Colors.white,
                              ),
                            const Spacer(),
                            // Favorite button
                            GestureDetector(
                              onTap: _onFavoriteTap,
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 1.0, end: 1.3).animate(
                                  CurvedAnimation(
                                    parent: _heartController,
                                    curve: Curves.easeOutBack,
                                  ),
                                ),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.12),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    widget.isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    size: 18,
                                    color: widget.isFavorited ? AppColors.primary : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bottom left: Price tag
                      if (rate != null)
                        Positioned(
                          bottom: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '\u20B9$rate',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '/hr',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Bottom right: Rating
                      if (rating != null)
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 14, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  double.parse(rating.toString()).toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Card body
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name + verified badge
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.venue['name'] ?? '',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.venue['is_verified'] == true) ...[
                              const SizedBox(width: 5),
                              const Icon(Icons.verified_rounded, size: 17, color: AppColors.primary),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Location
                        Row(
                          children: [
                            Icon(AppIcons.mapPin, size: 13, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                widget.venue['distance_km'] != null
                                    ? '${widget.venue['distance_km']} km away'
                                    : widget.venue['location'] ?? 'Nearby',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Footer divider
                        Container(
                          height: 1,
                          color: AppColors.borderLight,
                        ),
                        const SizedBox(height: 12),

                        // Footer: status + reviews
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Availability indicator
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: bookingCount != null && bookingCount > 0
                                    ? AppColors.warningLight
                                    : AppColors.secondary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: bookingCount != null && bookingCount > 0
                                          ? AppColors.warning
                                          : AppColors.secondary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    bookingCount != null && bookingCount > 0
                                        ? '$bookingCount booked today'
                                        : 'Available now',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: bookingCount != null && bookingCount > 0
                                          ? AppColors.accentDark
                                          : AppColors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (reviewCount != null && reviewCount > 0)
                              Row(
                                children: [
                                  Icon(Icons.chat_bubble_outline_rounded, size: 13, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$reviewCount reviews',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  final IconData? icon;
  final String? emoji;

  const _AnimatedBadge({
    required this.text,
    required this.color,
    required this.textColor,
    this.icon,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: textColor),
            const SizedBox(width: 4),
          ],
          if (emoji != null) ...[
            Text(emoji!, style: const TextStyle(fontSize: 10)),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
