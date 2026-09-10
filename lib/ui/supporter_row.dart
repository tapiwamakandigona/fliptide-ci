/// Title-screen Supporter entry point (directive 02O-1, carried onto the new
/// front door). One SUPPORT button plus a quiet "Restore purchase" link while
/// the product is not owned; a single "♥ SUPPORTER · no ads" mark once it is.
/// Renders nothing where there is no store (web, desktop, tests without a fake).
library;

import 'package:flutter/material.dart';

import '../game/palette.dart';
import '../iap/iap_service.dart';
import '../store/store.dart';

class SupporterRow extends StatefulWidget {
  const SupporterRow({super.key, required this.iap, required this.store});

  final IapService iap;
  final Store store;

  @override
  State<SupporterRow> createState() => _SupporterRowState();
}

class _SupporterRowState extends State<SupporterRow> {
  bool _busy = false;
  late bool _supporter = widget.store.supporter;

  @override
  void initState() {
    super.initState();
    widget.iap.owned.addListener(_onOwned);
    // Startup restore: not awaited so the title never waits on Play.
    if (widget.iap.supported && !_supporter) widget.iap.init();
  }

  @override
  void dispose() {
    widget.iap.owned.removeListener(_onOwned);
    super.dispose();
  }

  Future<void> _onOwned() async {
    if (!widget.iap.owned.value) return;
    final was = widget.store.supporter;
    await widget.store.setSupporter(true);
    if (!mounted) return;
    setState(() => _supporter = true);
    if (!was) _toast('Thank you — ads removed');
  }

  void _toast(String msg) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _run(Future<void> Function() body) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await body();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _support() => _run(() async {
        final r = await widget.iap.buy();
        if (!mounted) return;
        switch (r) {
          case PurchaseOutcome.owned:
            await _onOwned();
          case PurchaseOutcome.pending:
            _toast('Purchase pending — it unlocks when Play confirms');
          case PurchaseOutcome.cancelled:
            break;
          case PurchaseOutcome.unavailable:
            _toast('Store not available right now');
          case PurchaseOutcome.error:
            _toast('Purchase did not go through');
        }
      });

  Future<void> _restore() => _run(() async {
        final ok = await widget.iap.restore();
        if (!mounted) return;
        if (ok) {
          await _onOwned();
        } else {
          _toast('No Supporter purchase found for this account');
        }
      });

  @override
  Widget build(BuildContext context) {
    if (!widget.iap.supported) return const SizedBox.shrink();
    if (_supporter) {
      return const Text(
        '♥ SUPPORTER · no ads',
        key: Key('title-supporter-mark'),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Palette.finish),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Palette.corridor,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: const Key('title-support'),
            borderRadius: BorderRadius.circular(12),
            onTap: _support,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Palette.slabEdge.withValues(alpha: 0.4))),
              child: Center(
                child: ValueListenableBuilder<String?>(
                  valueListenable: widget.iap.price,
                  builder: (_, pr, _) => Text(
                    _busy ? '…' : 'SUPPORT · ${pr ?? kSupporterFallbackPrice} · REMOVES ADS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Palette.textDim),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          key: const Key('title-restore'),
          behavior: HitTestBehavior.opaque,
          onTap: _restore,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text('Restore purchase', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Palette.textDim)),
          ),
        ),
      ],
    );
  }
}
