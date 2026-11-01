/// The four games' round id prefixes. A round number comes from the clock, so
/// games on the same clock share it; the prefix is what tells them apart.
enum GameRound {
  tripleChance('TC'),
  luckyCard('LC'),
  spin2win('SW'),
  lucky16('LS');

  const GameRound(this.prefix);

  final String prefix;

  /// How a round is written everywhere: TC-17413022.
  String id(int roundNumber) => '$prefix-$roundNumber';
}
