/// 2.4 GHz Wi-Fi Radio Channels.
enum WifiChannel {
  ch1(1),
  ch2(2),
  ch3(3),
  ch4(4),
  ch5(5),
  ch6(6),
  ch7(7),
  ch8(8),
  ch9(9),
  ch10(10),
  ch11(11),
  ch12(12),
  ch13(13);

  const WifiChannel(this.number);
  final int number;
}

/// Strongly-typed, declarative Swarm Group identity.
final class SwarmId {
  const SwarmId._(this.identifier);

  /// Custom named swarm identity.
  const SwarmId.custom(this.identifier);

  final String identifier;

  /// Built-in pre-defined swarm domains:
  static const SwarmId robotics = SwarmId._('robot_swarm');
  static const SwarmId sensorFleet = SwarmId._('sensor_fleet');
  static const SwarmId telemetry = SwarmId._('telemetry_mesh');
  static const SwarmId droneFleet = SwarmId._('drone_fleet');
  static const SwarmId agvFleet = SwarmId._('agv_fleet');
  static const SwarmId smartHome = SwarmId._('smart_home');

  @override
  String toString() => identifier;
}

/// Wireless Mesh & ESP-NOW peer-to-peer communication configuration.
final class MeshSwarmConfig {
  const MeshSwarmConfig({
    this.swarm = SwarmId.robotics,
    this.channel = WifiChannel.ch1,
    this.encrypt = false,
    this.primaryKey = const <int>[],
    this.maxPeers = 20,
  });

  final SwarmId swarm;
  final WifiChannel channel;
  final bool encrypt;
  final List<int> primaryKey;
  final int maxPeers;

  Map<String, Object?> toJson() => <String, Object?>{
        'groupName': swarm.identifier,
        'channel': channel.number,
        'encrypt': encrypt,
        'primaryKey': primaryKey,
        'maxPeers': maxPeers,
      };
}
