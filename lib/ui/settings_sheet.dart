/// Settings: music, sound effects, haptics, language — plus a small stats
/// block (lifetime flips, deaths, dives). Bottom sheet from the title screen.
library;

import 'package:flutter/material.dart';

import '../audio/flip_audio.dart';
import '../game/palette.dart';
import '../store/store.dart';
import 'feel.dart';
import 'language.dart';

Future<void> showFlipSettings(
  BuildContext context,
  Store store, {
  FlipAudio? audio,
}) {
  final a = audio ?? FlipAudio.instance;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Palette.slab,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SettingsSheet(store: store, audio: a),
  );
}

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key, required this.store, required this.audio});
  final Store store;
  final FlipAudio audio;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late bool _music = widget.store.musicOn;
  late bool _sfx = widget.store.sfxOn;
  late bool _haptics = widget.store.hapticsOn;

  static const _title = TextStyle(
    fontWeight: FontWeight.w900,
    fontSize: 18,
    letterSpacing: 1,
  );

  Widget _toggle({
    required Key key,
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      key: key,
      value: value,
      onChanged: (v) {
        Feel.select();
        onChanged(v);
      },
      activeThumbColor: Palette.player,
      secondary: Icon(icon, color: value ? Palette.player : Palette.textDim),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Text(ft(context, 'SETTINGS'), style: _title),
            const SizedBox(height: 6),
            _toggle(
              key: const Key('settings-music'),
              icon: Icons.music_note_rounded,
              label: ft(context, 'Music'),
              value: _music,
              onChanged: (v) {
                setState(() => _music = v);
                store.setMusicOn(v);
                widget.audio.musicEnabled = v;
              },
            ),
            _toggle(
              key: const Key('settings-sfx'),
              icon: Icons.graphic_eq_rounded,
              label: ft(context, 'Sound effects'),
              value: _sfx,
              onChanged: (v) {
                setState(() => _sfx = v);
                store.setSfxOn(v);
                widget.audio.sfxEnabled = v;
                if (v) widget.audio.sfx(Sfx.tap);
              },
            ),
            _toggle(
              key: const Key('settings-haptics'),
              icon: Icons.vibration_rounded,
              label: ft(context, 'Vibration'),
              value: _haptics,
              onChanged: (v) {
                setState(() => _haptics = v);
                store.setHapticsOn(v);
                Feel.enabled = v;
                if (v) Feel.tap();
              },
            ),
            ListTile(
              key: const Key('settings-language'),
              leading: const Icon(Icons.language, color: Palette.textDim),
              title: Text(
                ft(context, 'Language'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Palette.textDim,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              onTap: () {
                Navigator.of(context).pop();
                showFlipLanguage(context);
              },
            ),
            const Divider(
              color: Palette.slabEdge,
              height: 20,
              indent: 20,
              endIndent: 20,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 18,
                runSpacing: 6,
                children: [
                  _Stat(
                    value: '${store.totalFlips}',
                    label: ft(context, 'flips'),
                  ),
                  _Stat(
                    value: '${store.totalDeaths}',
                    label: ft(context, 'deaths'),
                  ),
                  _Stat(
                    value: '${store.deepRuns}',
                    label: ft(context, 'dives'),
                  ),
                  _Stat(
                    value: '${store.deepBest} m',
                    label: ft(context, 'deepest'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              ft(context, 'Original soundtrack by Tsoro Studios'),
              style: const TextStyle(
                fontSize: 11,
                color: Palette.textDim,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Palette.textDim,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
