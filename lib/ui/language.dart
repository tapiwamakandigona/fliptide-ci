import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/palette.dart';

const flipLocales = [
  Locale('en'),
  Locale('fr'),
  Locale('es'),
  Locale('pt', 'BR'),
];
const flipLanguages = {
  'system': 'System',
  'en': 'English',
  'fr': 'Français',
  'es': 'Español',
  'pt': 'Português (Brasil)',
};

class FlipLanguage {
  static final choice = ValueNotifier<String>('system');
  static String valid(Object? value) =>
      value is String && flipLanguages.containsKey(value) ? value : 'system';
  static Locale? locale(String value) => switch (value) {
    'en' => const Locale('en'),
    'fr' => const Locale('fr'),
    'es' => const Locale('es'),
    'pt' => const Locale('pt', 'BR'),
    _ => null,
  };
  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    choice.value = valid(p.get('interfaceLanguage'));
  }

  static Future<bool> save(String value) async {
    choice.value = valid(value);
    return (await SharedPreferences.getInstance()).setString(
      'interfaceLanguage',
      choice.value,
    );
  }
}

// Stable English source key -> French / Spanish / Brazilian Portuguese.
// Literal fallback, no network translator and no course-code manipulation.
const flipCatalog = <String, List<String>>{
  'Language': ['Langue', 'Idioma', 'Idioma'],
  'System': ['Système', 'Sistema', 'Sistema'],
  'Navigation and Shallows lessons are translated. Some store, sharing and later-course text remains in English.': [
    'Les menus et les leçons des Petits Fonds sont traduits. Certains textes de boutique, de partage et des parcours suivants restent en anglais.',
    'Los menús y las lecciones de Bajíos están traducidos. Algunos textos de tienda, de compartir y de los siguientes recorridos siguen en inglés.',
    'Os menus e as lições de Águas Rasas estão traduzidos. Alguns textos da loja, de compartilhamento e dos próximos percursos continuam em inglês.',
  ],
  'Could not save language on this device.': [
    'Impossible d’enregistrer la langue sur cet appareil.',
    'No se pudo guardar el idioma en este dispositivo.',
    'Não foi possível salvar o idioma neste dispositivo.',
  ],
  'one tap flips gravity': [
    'un toucher inverse la gravité',
    'un toque invierte la gravedad',
    'um toque inverte a gravidade',
  ],
  'PLAY': ['JOUER', 'JUGAR', 'JOGAR'],
  'REPLAY THE TIDES': [
    'REJOUER LES MARÉES',
    'REPETIR LAS MAREAS',
    'REJOGAR AS MARÉS',
  ],
  'THE TIDES': ['LES MARÉES', 'LAS MAREAS', 'AS MARÉS'],
  'COURSE CODE': [
    'CODE DE PARCOURS',
    'CÓDIGO DE RECORRIDO',
    'CÓDIGO DO PERCURSO',
  ],
  'Play a course code': [
    'Jouer un code de parcours',
    'Jugar un código de recorrido',
    'Jogar um código de percurso',
  ],
  'Cancel': ['Annuler', 'Cancelar', 'Cancelar'],
  'That code is not valid': [
    'Ce code n’est pas valide',
    'Ese código no es válido',
    'Esse código não é válido',
  ],
  'stars': ['étoiles', 'estrellas', 'estrelas'],
  'cleared': ['terminés', 'superados', 'concluídos'],
  'day': ['jour', 'día', 'dia'],
  'days': ['jours', 'días', 'dias'],
  'DAILY': ['DU JOUR', 'DIARIO', 'DIÁRIO'],
  'DAILY #{number}': [
    'DU JOUR Nº {number}',
    'DIARIO N.º {number}',
    'DIÁRIO Nº {number}',
  ],
  'TIDE {number}': ['MARÉE {number}', 'MAREA {number}', 'MARÉ {number}'],
  'Clear Tide {number} to open.': [
    'Terminez la Marée {number} pour débloquer.',
    'Supera la Marea {number} para desbloquear.',
    'Conclua a Maré {number} para liberar.',
  ],
  'all 30 courses cleared': [
    'les 30 parcours sont terminés',
    'los 30 recorridos superados',
    'os 30 percursos concluídos',
  ],
  'same course for everyone today': [
    'le même parcours pour tous aujourd’hui',
    'el mismo recorrido para todos hoy',
    'o mesmo percurso para todos hoje',
  ],
  'CODE': ['CODE', 'CÓDIGO', 'CÓDIGO'],
  'CLEARED': ['RÉUSSI', 'SUPERADO', 'CONCLUÍDO'],
  'RETRY': ['RÉESSAYER', 'REINTENTAR', 'TENTAR DE NOVO'],
  'NEXT': ['SUIVANT', 'SIGUIENTE', 'PRÓXIMO'],
  'SHARE': ['PARTAGER', 'COMPARTIR', 'COMPARTILHAR'],
  'CARD': ['CARTE', 'TARJETA', 'CARTÃO'],
  'SECOND CHANCE': ['SECONDE CHANCE', 'SEGUNDA OPORTUNIDAD', 'SEGUNDA CHANCE'],
  'Shallows': ['Petits Fonds', 'Bajíos', 'Águas Rasas'],
  'First Light': ['Première Lumière', 'Primera Luz', 'Primeira Luz'],
  'Low Water': ['Basse Mer', 'Marea Baja', 'Maré Baixa'],
  'Sandbar': ['Banc de Sable', 'Banco de Arena', 'Banco de Areia'],
  'Ripples': ['Ondulations', 'Ondas', 'Ondulações'],
  'Rock Pool': ['Bassin Rocheux', 'Poza de Roca', 'Poça de Pedra'],
  'Ebb': ['Reflux', 'Reflujo', 'Vazante'],
  'Learn the flip.': [
    'Apprenez à inverser la gravité.',
    'Aprende a invertir la gravedad.',
    'Aprenda a inverter a gravidade.',
  ],
  'tap to start · tap to flip gravity': [
    'touchez pour commencer · touchez pour inverser la gravité',
    'toca para empezar · toca para invertir la gravedad',
    'toque para começar · toque para inverter a gravidade',
  ],
  'Tap before the red teeth. Land, then tap back.': [
    'Touchez avant les pointes rouges. Posez-vous, puis revenez d’un toucher.',
    'Toca antes de las puntas rojas. Aterriza y toca para volver.',
    'Toque antes dos espinhos vermelhos. Pouse e toque para voltar.',
  ],
  'Open water below? Cross to the ceiling and stay there.': [
    'De l’eau en dessous ? Passez au plafond et restez-y.',
    '¿Agua debajo? Pasa al techo y quédate allí.',
    'Água embaixo? Vá para o teto e fique lá.',
  ],
  'Flip before a wall. You cannot run through its side.': [
    'Inversez avant un mur. Vous ne pouvez pas le traverser.',
    'Invierte antes de un muro. No puedes atravesarlo.',
    'Inverta antes de uma parede. Você não pode atravessá-la.',
  ],
  'Read the next side. One calm tap is enough.': [
    'Regardez le prochain côté. Un toucher calme suffit.',
    'Mira el siguiente lado. Un toque tranquilo basta.',
    'Observe o próximo lado. Um toque tranquilo basta.',
  ],
  'Stay above a long hazard. There is no need to keep tapping.': [
    'Restez au-dessus d’un long obstacle. Inutile de toucher sans cesse.',
    'Quédate encima de un peligro largo. No hace falta seguir tocando.',
    'Fique acima de um perigo longo. Não precisa continuar tocando.',
  ],
  'Walls, water, teeth. Find the safe side and trust the rhythm.': [
    'Murs, eau, pointes. Trouvez le côté sûr et suivez le rythme.',
    'Muros, agua, puntas. Busca el lado seguro y confía en el ritmo.',
    'Paredes, água, espinhos. Encontre o lado seguro e confie no ritmo.',
  ],
  'The lighthouse is dark. Carry its last spark inland.': [
    'Le phare est éteint. Portez sa dernière étincelle vers la terre.',
    'El faro está apagado. Lleva su última chispa tierra adentro.',
    'O farol está apagado. Leve sua última faísca para o interior.',
  ],
  'The tide took the path. The ceiling is another shore.': [
    'La marée a pris le chemin. Le plafond est une autre rive.',
    'La marea se llevó el camino. El techo es otra orilla.',
    'A maré levou o caminho. O teto é outra margem.',
  ],
  'Old sea walls still hold. Go around, not through.': [
    'Les vieux murs tiennent encore. Contournez-les.',
    'Los viejos muros aún resisten. Rodéalos, no los atravieses.',
    'As velhas paredes ainda resistem. Contorne, não atravesse.',
  ],
  'The beacon answers in pulses. Learn its rhythm.': [
    'Le phare répond par pulsations. Apprenez son rythme.',
    'El faro responde con pulsos. Aprende su ritmo.',
    'O farol responde em pulsos. Aprenda seu ritmo.',
  ],
  'Light moves over still water. Give yourself room to breathe.': [
    'La lumière glisse sur l’eau calme. Laissez-vous le temps de respirer.',
    'La luz cruza el agua quieta. Date espacio para respirar.',
    'A luz passa sobre a água calma. Dê espaço para respirar.',
  ],
  'Behind you, the first beacon wakes. Ahead: the Drift.': [
    'Derrière vous, le premier phare s’éveille. Devant : la Dérive.',
    'Detrás, el primer faro despierta. Delante: la Deriva.',
    'Atrás, o primeiro farol desperta. Adiante: a Deriva.',
  ],
  'Drift': ['Dérive', 'Deriva', 'Deriva'],
  'attempt {number}': [
    'essai {number}',
    'intento {number}',
    'tentativa {number}',
  ],
  'tell someone': ['partagez-le', 'cuéntalo', 'conte para alguém'],
  'tap anywhere to retry': [
    'touchez n’importe où pour réessayer',
    'toca en cualquier sitio para reintentar',
    'toque em qualquer lugar para tentar de novo',
  ],
  'Close': ['Fermer', 'Cerrar', 'Fechar'],
};

String flipText(
  String source,
  String code, {
  Map<String, Object> args = const {},
}) {
  final index = const {'fr': 0, 'es': 1, 'pt': 2}[code];
  var text = index == null ? source : (flipCatalog[source]?[index] ?? source);
  if (args.isNotEmpty) {
    text = text.replaceAllMapped(
      RegExp(r'\{([a-zA-Z]+)\}'),
      (m) => args[m[1]]?.toString() ?? m[0]!,
    );
  }
  return text;
}

String ft(
  BuildContext context,
  String source, {
  Map<String, Object> args = const {},
}) => flipText(
  source,
  Localizations.maybeLocaleOf(context)?.languageCode ?? 'en',
  args: args,
);

Future<void> showFlipLanguage(
  BuildContext context,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Palette.corridor,
  builder: (_) => ValueListenableBuilder<String>(
    valueListenable: FlipLanguage.choice,
    builder: (context, code, _) => Localizations.override(
      context: context,
      locale: FlipLanguage.locale(code),
      child: Builder(
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ft(context, 'Language'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                DropdownButton<String>(
                  key: const Key('interface-language'),
                  value: FlipLanguage.choice.value,
                  isExpanded: true,
                  items: [
                    for (final item in flipLanguages.entries)
                      DropdownMenuItem(
                        value: item.key,
                        child: Text(
                          item.key == 'system'
                              ? ft(context, item.value)
                              : item.value,
                        ),
                      ),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    final saved = await FlipLanguage.save(value);
                    if (!saved && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ft(
                              context,
                              'Could not save language on this device.',
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),
                Text(
                  ft(
                    context,
                    'Navigation and Shallows lessons are translated. Some store, sharing and later-course text remains in English.',
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(ft(context, 'Close')),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
