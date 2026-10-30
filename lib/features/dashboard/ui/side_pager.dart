import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';

/// One card at a time, swiped vertically; dots on the right edge show and pick the page.
class SidePager extends StatefulWidget {
  const SidePager({super.key, required this.pages, required this.labels});

  final List<Widget> pages;

  /// Spoken and tooltip name of each page.
  final List<String> labels;

  @override
  State<SidePager> createState() => _SidePagerState();
}

class _SidePagerState extends State<SidePager> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int i) {
    final d = SdMotion.of(context, SdMotion.long);
    if (d == Duration.zero) {
      _controller.jumpToPage(i);
    } else {
      _controller.animateToPage(i, duration: d, curve: SdMotion.curve);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.length == 1) return widget.pages.single;
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        PageView(
          controller: _controller,
          scrollDirection: Axis.vertical,
          onPageChanged: (i) => setState(() => _page = i),
          // Cards on a page keep their content clear of the dots.
          children: [
            for (final p in widget.pages)
              CardEndInset(width: 20, child: RepaintBoundary(child: p)),
          ],
        ),
        Positioned(
          right: SdSpace.xs,
          top: 0,
          bottom: 0,
          child: Center(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: const StadiumBorder(),
                color: scheme.surfaceContainerLowest.withValues(alpha: 0.6),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.pages.length; i++)
                    Tooltip(
                      message: widget.labels[i],
                      child: InkResponse(
                        onTap: () => _go(i),
                        radius: 16,
                        child: SizedBox(
                          width: 20,
                          height: 22,
                          child: Center(
                            child: AnimatedContainer(
                              duration: SdMotion.of(context, SdMotion.medium),
                              curve: SdMotion.curve,
                              width: 6,
                              height: i == _page ? 14 : 6,
                              decoration: ShapeDecoration(
                                shape: const StadiumBorder(),
                                color: i == _page
                                    ? scheme.onSurface
                                    : scheme.onSurfaceVariant.withValues(
                                        alpha: 0.5,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
