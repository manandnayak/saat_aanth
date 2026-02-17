import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const SaatAanthhApp());
}

class SaatAanthhApp extends StatelessWidget {
  const SaatAanthhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saat – Aanthh',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3949AB)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

enum Suit { spades, hearts, diamonds, clubs }

enum Rank { seven, eight, nine, ten, jack, queen, king, ace }

int rankValue(Rank r) {
  switch (r) {
    case Rank.ace:
      return 14;
    case Rank.king:
      return 13;
    case Rank.queen:
      return 12;
    case Rank.jack:
      return 11;
    case Rank.ten:
      return 10;
    case Rank.nine:
      return 9;
    case Rank.eight:
      return 8;
    case Rank.seven:
      return 7;
  }
}

String suitSymbol(Suit s) {
  switch (s) {
    case Suit.spades:
      return '♠';
    case Suit.hearts:
      return '♥';
    case Suit.diamonds:
      return '♦';
    case Suit.clubs:
      return '♣';
  }
}

String suitName(Suit s) {
  switch (s) {
    case Suit.spades:
      return 'Spades';
    case Suit.hearts:
      return 'Hearts';
    case Suit.diamonds:
      return 'Diamonds';
    case Suit.clubs:
      return 'Clubs';
  }
}

String rankLabel(Rank r) {
  switch (r) {
    case Rank.ace:
      return 'A';
    case Rank.king:
      return 'K';
    case Rank.queen:
      return 'Q';
    case Rank.jack:
      return 'J';
    case Rank.ten:
      return '10';
    case Rank.nine:
      return '9';
    case Rank.eight:
      return '8';
    case Rank.seven:
      return '7';
  }
}

class GameCard {
  final Suit suit;
  final Rank rank;
  GameCard(this.suit, this.rank);

  @override
  String toString() => '${rankLabel(rank)}${suitSymbol(suit)}';
}

enum AiLevel { aggressive, strategic, relentless }

class PlayerZone {
  final List<GameCard> hand = [];
  final List<GameCard?> rowUp = List.filled(5, null);
  final List<GameCard?> rowDown = List.filled(5, null);

  List<GameCard> playableCards() {
    final cards = <GameCard>[];
    cards.addAll(hand);
    for (final c in rowUp) {
      if (c != null) cards.add(c);
    }
    return cards;
  }

  bool playCard(GameCard card) {
    final idxHand = hand.indexWhere((c) => (c.suit == card.suit && c.rank == card.rank));
    if (idxHand != -1) {
      hand.removeAt(idxHand);
      return true;
    }
    for (int i = 0; i < 5; i++) {
      final up = rowUp[i];
      if (up != null && up.suit == card.suit && up.rank == card.rank) {
        rowUp[i] = rowDown[i];
        rowDown[i] = null;
        return true;
      }
    }
    return false;
  }
}

class GameState {
  final Random rng;
  final AiLevel aiLevel;

  final PlayerZone human = PlayerZone();
  final PlayerZone ai = PlayerZone();

  Suit? trump;
  bool humanIsCaller = true;

  int round = 1;
  int humanTricks = 0;
  int aiTricks = 0;

  int humanPoints = 0;
  int aiPoints = 0;

  bool humanLeads = true;

  GameCard? leadCard;
  GameCard? responseCard;

  String message = '';

  GameState({required this.aiLevel, required int seed}) : rng = Random(seed);

  void newGame({required bool humanCaller}) {
    humanIsCaller = humanCaller;
    trump = null;
    round = 1;
    humanTricks = 0;
    aiTricks = 0;
    humanLeads = true; // Player 1 leads Round 1; in this app you are Player 1.
    leadCard = null;
    responseCard = null;
    message = '';

    // Build deck
    final deck = <GameCard>[];
    final ranks = [Rank.ace, Rank.king, Rank.queen, Rank.jack, Rank.ten, Rank.nine, Rank.eight];
    for (final s in Suit.values) {
      for (final r in ranks) {
        deck.add(GameCard(s, r));
      }
    }
    deck.add(GameCard(Suit.spades, Rank.seven));
    deck.add(GameCard(Suit.hearts, Rank.seven));

    deck.shuffle(rng);

    // Deal 5 to human, 5 to AI
    human.hand
      ..clear()
      ..addAll(deck.sublist(0, 5));
    ai.hand
      ..clear()
      ..addAll(deck.sublist(5, 10));

    // Face-down rows
    for (int i = 0; i < 5; i++) {
      human.rowDown[i] = deck[10 + i];
      ai.rowDown[i] = deck[15 + i];
    }

    // Face-up rows
    for (int i = 0; i < 5; i++) {
      human.rowUp[i] = deck[20 + i];
      ai.rowUp[i] = deck[25 + i];
    }

    if (humanIsCaller) {
      message = 'You are the Caller (target 8). Choose trump now or tap Postpone.';
    } else {
      trump = _aiChooseTrump();
      message = 'AI is the Caller (target 8). Trump is ${suitName(trump!)}.';
    }
  }

  int targetForHuman() => humanIsCaller ? 8 : 7;
  int targetForAi() => humanIsCaller ? 7 : 8;

  Suit _aiChooseTrump() {
    final scores = <Suit, double>{ for (final s in Suit.values) s: 0.0 };
    final all = [...ai.hand, ...ai.rowUp.whereType<GameCard>()];
    for (final c in all) {
      scores[c.suit] = (scores[c.suit] ?? 0) + (rankValue(c.rank) / 14.0) + 0.35;
    }
    for (final s in Suit.values) {
      scores[s] = (scores[s] ?? 0) + rng.nextDouble() * 0.05;
    }
    Suit best = Suit.spades;
    double bestScore = -1;
    for (final e in scores.entries) {
      if (e.value > bestScore) {
        bestScore = e.value;
        best = e.key;
      }
    }
    return best;
  }

  bool humanWinsTrick(GameCard lead, GameCard resp) {
    final t = trump;
    if (t != null) {
      final leadTrump = lead.suit == t;
      final respTrump = resp.suit == t;
      if (respTrump && !leadTrump) return false;
      if (leadTrump && !respTrump) return true;
      if (leadTrump && respTrump) return rankValue(lead.rank) > rankValue(resp.rank);
    }
    if (lead.suit == resp.suit) return rankValue(lead.rank) > rankValue(resp.rank);
    return true; // responder off-suit without trump loses
  }

  void playLead(GameCard chosenByLeader) {
    if (trump == null) {
      message = 'Trump not selected yet.';
      return;
    }

    leadCard = null;
    responseCard = null;

    if (humanLeads) {
      if (!human.playCard(chosenByLeader)) {
        message = 'Invalid play.';
        return;
      }
      leadCard = chosenByLeader;
      final aiPlay = _aiRespondToLead(chosenByLeader);
      ai.playCard(aiPlay);
      responseCard = aiPlay;
      final humanWin = humanWinsTrick(chosenByLeader, aiPlay);
      _applyTrickResult(humanWin);
    } else {
      final aiLead = chosenByLeader;
      if (!ai.playCard(aiLead)) {
        message = 'AI error: invalid play.';
        return;
      }
      leadCard = aiLead;
      message = 'AI led ${aiLead}. Your turn to respond.';
    }
  }

  void playResponseToAiLead(GameCard humanResponse) {
    if (leadCard == null || trump == null) {
      message = 'No active lead.';
      return;
    }
    if (!human.playCard(humanResponse)) {
      message = 'Invalid response.';
      return;
    }
    responseCard = humanResponse;

    // AI is leader; compute AI win then invert
    final aiWins = _aiWinsTrick(leadCard!, humanResponse);
    _applyTrickResult(!aiWins);
  }

  bool _aiWinsTrick(GameCard leadByAi, GameCard humanResp) {
    final t = trump;
    if (t != null) {
      final leadTrump = leadByAi.suit == t;
      final respTrump = humanResp.suit == t;
      if (respTrump && !leadTrump) return false;
      if (leadTrump && !respTrump) return true;
      if (leadTrump && respTrump) return rankValue(leadByAi.rank) > rankValue(humanResp.rank);
    }
    if (leadByAi.suit == humanResp.suit) return rankValue(leadByAi.rank) > rankValue(humanResp.rank);
    return true;
  }

  void _applyTrickResult(bool humanWon) {
    if (humanWon) {
      humanTricks++;
      humanLeads = true;
      message = 'You won Round $round.';
    } else {
      aiTricks++;
      humanLeads = false;
      message = 'AI won Round $round.';
    }

    round++;
    leadCard = null;
    responseCard = null;

    if (round > 15) {
      final hExtra = max(0, humanTricks - targetForHuman());
      final aExtra = max(0, aiTricks - targetForAi());
      humanPoints += hExtra;
      aiPoints += aExtra;
      message = 'Game over. You: $humanTricks (extra $hExtra). AI: $aiTricks (extra $aExtra).\n'
          'Match Points — You: $humanPoints | AI: $aiPoints. Tap New Game.';
    } else {
      if (!humanLeads) {
        final aiLead = _aiChooseLead();
        playLead(aiLead);
      }
    }
  }

  List<GameCard> _aiPlayable() => ai.playableCards();

  GameCard _aiRespondToLead(GameCard lead) {
    final playable = _aiPlayable();

    final canFollow = playable.where((c) => c.suit == lead.suit).toList();
    if (canFollow.isNotEmpty) {
      final winning = canFollow.where((c) => rankValue(c.rank) > rankValue(lead.rank)).toList();
      if (winning.isNotEmpty) {
        winning.sort((a, b) => rankValue(a.rank).compareTo(rankValue(b.rank)));
        return winning.first; // lowest winning
      }
      canFollow.sort((a, b) => rankValue(a.rank).compareTo(rankValue(b.rank)));
      return canFollow.first; // sacrifice lowest
    }

    final t = trump!;
    final trumps = playable.where((c) => c.suit == t).toList();
    final shouldTrump = _aiShouldTrump();

    if (shouldTrump && trumps.isNotEmpty) {
      trumps.sort((a, b) => rankValue(a.rank).compareTo(rankValue(b.rank)));
      return trumps.first;
    }

    final nonTrumps = playable.where((c) => c.suit != t).toList();
    nonTrumps.sort((a, b) => rankValue(a.rank).compareTo(rankValue(b.rank)));
    return nonTrumps.isNotEmpty ? nonTrumps.first : trumps.first;
  }

  bool _aiShouldTrump() {
    final remaining = 16 - round;
    final aiNeeds = max(0, targetForAi() - aiTricks);

    if (aiLevel == AiLevel.relentless) return true;
    if (aiLevel == AiLevel.strategic) {
      final humanClose = humanTricks >= targetForHuman() - 1;
      if (humanClose) return true;
      if (aiNeeds >= (remaining / 2).ceil()) return true;
      return remaining <= 5;
    }
    return aiNeeds > 0 || remaining <= 6;
  }

  GameCard _aiChooseLead() {
    final playable = _aiPlayable();
    final t = trump!;

    // Suit strength
    final strength = <Suit, double>{ for (final s in Suit.values) s: 0.0 };
    for (final c in playable) {
      strength[c.suit] = (strength[c.suit] ?? 0) + rankValue(c.rank) / 14.0 + 0.25;
    }

    if (aiLevel == AiLevel.relentless) {
      // Prefer strong non-trump to pull trumps
      Suit? bestNon;
      double best = -1;
      for (final s in Suit.values) {
        if (s == t) continue;
        final v = strength[s] ?? 0;
        if (v > best) {
          best = v;
          bestNon = s;
        }
      }
      if (bestNon != null) {
        final list = playable.where((c) => c.suit == bestNon).toList();
        if (list.isNotEmpty) {
          list.sort((a, b) => rankValue(b.rank).compareTo(rankValue(a.rank)));
          return list.first;
        }
      }
    }

    Suit bestSuit = Suit.spades;
    double bestScore = -1;
    for (final e in strength.entries) {
      if (e.value > bestScore) {
        bestScore = e.value;
        bestSuit = e.key;
      }
    }

    final candidates = playable.where((c) => c.suit == bestSuit).toList();
    candidates.sort((a, b) => rankValue(b.rank).compareTo(rankValue(a.rank)));
    if (aiLevel == AiLevel.strategic && candidates.length >= 2) {
      return candidates[candidates.length ~/ 2];
    }
    return candidates.first;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AiLevel _level = AiLevel.strategic;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('saat_aanth')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Saat – Aanthh (Player vs Computer)',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Choose AI difficulty (aggressive levels aiming to win extra rounds):'),
            const SizedBox(height: 12),
            SegmentedButton<AiLevel>(
              segments: const [
                ButtonSegment(value: AiLevel.aggressive, label: Text('Aggressive')),
                ButtonSegment(value: AiLevel.strategic, label: Text('Strategic')),
                ButtonSegment(value: AiLevel.relentless, label: Text('Relentless')),
              ],
              selected: {_level},
              onSelectionChanged: (s) => setState(() => _level = s.first),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GameScreen(level: _level)),
                );
              },
            ),
            const SizedBox(height: 12),
            const Divider(),
            const Text('Rules snapshot', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('• 30 cards: A,K,Q,J,10,9,8 (all suits) + 7♠,7♥\n'
                '• Caller chooses trump; targets 8 wins vs 7\n'
                '• 15 rounds; winner leads next round\n'
                '• Must follow suit if possible; trump beats non-trump\n'
                '• Playing an open row card reveals the face-down card beneath it'),
          ],
        ),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  final AiLevel level;
  const GameScreen({super.key, required this.level});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameState gs;

  bool choosingTrump = false;
  bool postponeMode = false;
  final Set<int> peeked = {};

  @override
  void initState() {
    super.initState();
    gs = GameState(aiLevel: widget.level, seed: DateTime.now().millisecondsSinceEpoch);
    gs.newGame(humanCaller: true);
    choosingTrump = true;
  }

  void newGame() {
    final nextCallerHuman = !gs.humanIsCaller;
    gs.newGame(humanCaller: nextCallerHuman);
    choosingTrump = gs.humanIsCaller;
    postponeMode = false;
    peeked.clear();
    setState(() {});
  }

  List<GameCard> playableForHumanResponse() {
    final lead = gs.leadCard;
    final cards = gs.human.playableCards();
    if (lead == null) return cards;
    if (cards.any((c) => c.suit == lead.suit)) {
      return cards.where((c) => c.suit == lead.suit).toList();
    }
    return cards;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saat – Aanthh'),
        actions: [
          IconButton(
            tooltip: 'New Game',
            icon: const Icon(Icons.refresh),
            onPressed: newGame,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _statusCard(),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _trickCard(),
                    const SizedBox(height: 12),
                    _aiCard(),
                    const SizedBox(height: 12),
                    _humanCard(),
                    const SizedBox(height: 8),
                    _msgCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard() {
    final trump = gs.trump;
    final caller = gs.humanIsCaller ? 'You' : 'AI';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Round: ${min(gs.round, 15)}/15', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('Caller: $caller (Targets You ${gs.targetForHuman()} / AI ${gs.targetForAi()})'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('Trump: ${trump == null ? '—' : suitName(trump)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('Tricks — You ${gs.humanTricks} : ${gs.aiTricks} AI'),
              ],
            ),
            const SizedBox(height: 4),
            Text('Match Points — You ${gs.humanPoints} : ${gs.aiPoints} AI'),
          ],
        ),
      ),
    );
  }

  Widget _trickCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Current Trick', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _bigCard('Lead', gs.leadCard)),
                const SizedBox(width: 10),
                Expanded(child: _bigCard('Response', gs.responseCard)),
              ],
            ),
            const SizedBox(height: 8),
            if (choosingTrump && gs.humanIsCaller) _trumpChooser(),
          ],
        ),
      ),
    );
  }

  Widget _bigCard(String label, GameCard? card) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Text(card?.toString() ?? '—', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _trumpChooser() {
    if (!postponeMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose Trump', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: Suit.values.map((s) {
              return ElevatedButton(
                onPressed: () {
                  setState(() {
                    gs.trump = s;
                    choosingTrump = false;
                    gs.message = 'Trump set to ${suitName(s)}. You lead Round 1.';
                  });
                },
                child: Text('${suitName(s)} ${suitSymbol(s)}'),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              setState(() {
                postponeMode = true;
                peeked.clear();
                gs.message = 'Postponed: tap exactly 2 hidden row cards to peek, then pick trump.';
              });
            },
            child: const Text('Postpone (peek 2 row cards)'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Postpone Mode: Peek 2 cards', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: List.generate(5, (i) {
            final isPeeked = peeked.contains(i);
            final display = isPeeked ? gs.human.rowUp[i]!.toString() : '🂠';
            return ElevatedButton(
              onPressed: () {
                if (peeked.contains(i)) return;
                if (peeked.length >= 2) return;
                setState(() => peeked.add(i));
              },
              child: Text(display, style: const TextStyle(fontSize: 18)),
            );
          }),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: Suit.values.map((s) {
            return ElevatedButton(
              onPressed: peeked.length == 2
                  ? () {
                      setState(() {
                        gs.trump = s;
                        choosingTrump = false;
                        postponeMode = false;
                        gs.message = 'Trump chosen as ${suitName(s)} based on 2 peeked cards. You lead Round 1.';
                      });
                    }
                  : null,
              child: Text('${suitName(s)} ${suitSymbol(s)}'),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text('Peeked: ${peeked.length}/2', style: const TextStyle(color: Colors.black54)),
      ],
    );
  }

  Widget _aiCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('AI', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('Hand: ${gs.ai.hand.length} cards'),
              ],
            ),
            const SizedBox(height: 8),
            const Text('AI Face-up Row (playable):'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: List.generate(5, (i) {
                final c = gs.ai.rowUp[i];
                return Chip(label: Text(c?.toString() ?? '—'));
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _humanCard() {
    final canPlay = gs.trump != null && gs.round <= 15;

    final responding = !gs.humanLeads && gs.leadCard != null && gs.responseCard == null;
    final playable = responding ? playableForHumanResponse() : gs.human.playableCards();

    bool enabled(GameCard c) => canPlay && (gs.humanLeads || responding) && playable.any((p) => p.suit == c.suit && p.rank == c.rank);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('You', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('Hand: ${gs.human.hand.length} cards'),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Your Hand (private):'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: gs.human.hand.map((c) {
                return ElevatedButton(
                  onPressed: enabled(c) ? () => setState(() => _playHuman(c)) : null,
                  child: Text(c.toString()),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            const Text('Your Face-up Row (playable):'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: List.generate(5, (i) {
                final c = gs.human.rowUp[i];
                if (c == null) return const Chip(label: Text('—'));
                return OutlinedButton(
                  onPressed: enabled(c) ? () => setState(() => _playHuman(c)) : null,
                  child: Text(c.toString()),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _playHuman(GameCard c) {
    if (gs.round > 15 || gs.trump == null) return;

    final responding = !gs.humanLeads && gs.leadCard != null && gs.responseCard == null;
    if (responding) {
      gs.playResponseToAiLead(c);
    } else if (gs.humanLeads) {
      gs.playLead(c);
    }
  }

  Widget _msgCard() {
    return Card(
      color: const Color(0xFFF7F7F7),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(gs.message.isEmpty ? 'Ready.' : gs.message),
      ),
    );
  }
}
