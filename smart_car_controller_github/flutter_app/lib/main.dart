import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const CarControllerApp());
}

class CarControllerApp extends StatelessWidget {
  const CarControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
      ),
      home: const CarControllerPage(),
    );
  }
}

class CarControllerPage extends StatefulWidget {
  const CarControllerPage({super.key});

  @override
  State<CarControllerPage> createState() => _CarControllerPageState();
}

class _CarControllerPageState extends State<CarControllerPage> {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  final TextEditingController _ipController = TextEditingController(text: '192.168.4.1');

  int _frontDistance = -1;
  int _backDistance = -1;
  bool _frontBlocked = false;
  bool _backBlocked = false;
  int _speed = 180;

  String _activeCommand = 'S';

  void _connect() {
    if (_channel != null) {
      _channel!.sink.close();
    }

    final uri = Uri.parse('ws://${_ipController.text}:81');
    _channel = WebSocketChannel.connect(uri);

    setState(() => _isConnected = true);

    _channel!.stream.listen(
      (message) {
        final data = jsonDecode(message) as Map<String, dynamic>;
        setState(() {
          _frontDistance = data['front'] as int? ?? -1;
          _backDistance = data['back'] as int? ?? -1;
          _frontBlocked = data['frontBlocked'] as bool? ?? false;
          _backBlocked = data['backBlocked'] as bool? ?? false;
          _speed = data['speed'] as int? ?? 180;
        });
      },
      onDone: () {
        setState(() => _isConnected = false);
      },
      onError: (_) {
        setState(() => _isConnected = false);
      },
    );
  }

  void _disconnect() {
    _channel?.sink.close();
    _channel = null;
    setState(() {
      _isConnected = false;
      _activeCommand = 'S';
    });
  }

  void _sendCommand(String cmd) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(cmd);
      setState(() => _activeCommand = cmd);
    }
  }

  void _sendSpeed(int speed) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add('V$speed');
    }
  }

  Color _distanceColor(int distance, bool blocked) {
    if (distance < 0) return Colors.grey;
    if (blocked) return Colors.red;
    if (distance < 30) return Colors.orange;
    return Colors.green;
  }

  IconData _distanceIcon(int distance, bool blocked) {
    if (distance < 0) return Icons.help_outline;
    if (blocked) return Icons.warning;
    if (distance < 30) return Icons.info_outline;
    return Icons.check_circle_outline;
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildConnectionBar(),
              const SizedBox(height: 16),
              _buildSensorPanel(),
              const SizedBox(height: 16),
              Expanded(child: _buildControls()),
              const SizedBox(height: 8),
              _buildSpeedSlider(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _isConnected ? Icons.wifi : Icons.wifi_off,
            color: _isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ipController,
              enabled: !_isConnected,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
                hintText: 'ESP32 IP',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: _isConnected ? _disconnect : _connect,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isConnected ? Colors.red.shade700 : Colors.green.shade700,
              ),
              child: Text(_isConnected ? 'Disconnect' : 'Connect'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorPanel() {
    return Row(
      children: [
        Expanded(child: _buildSensorCard('FRONT', _frontDistance, _frontBlocked)),
        const SizedBox(width: 12),
        Expanded(child: _buildSensorCard('BACK', _backDistance, _backBlocked)),
      ],
    );
  }

  Widget _buildSensorCard(String label, int distance, bool blocked) {
    final color = _distanceColor(distance, blocked);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: blocked ? Colors.red.withOpacity(0.15) : Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: blocked ? Border.all(color: Colors.red, width: 2) : null,
      ),
      child: Column(
        children: [
          Icon(_distanceIcon(distance, blocked), color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            distance < 0 ? '--' : '$distance cm',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (blocked)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'WALL!',
                style: TextStyle(
                  color: Colors.red.shade300,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildControlButton(
            Icons.arrow_upward,
            'F',
            _activeCommand == 'F',
            _frontBlocked,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(
                Icons.arrow_back,
                'L',
                _activeCommand == 'L',
                false,
              ),
              const SizedBox(width: 12),
              _buildControlButton(
                Icons.stop,
                'S',
                _activeCommand == 'S',
                false,
                isStop: true,
              ),
              const SizedBox(width: 12),
              _buildControlButton(
                Icons.arrow_forward,
                'R',
                _activeCommand == 'R',
                false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildControlButton(
            Icons.arrow_downward,
            'B',
            _activeCommand == 'B',
            _backBlocked,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    IconData icon,
    String cmd,
    bool isActive,
    bool isBlocked, {
    bool isStop = false,
  }) {
    Color bgColor;
    if (isBlocked && isActive) {
      bgColor = Colors.red.shade700;
    } else if (isActive) {
      bgColor = Colors.blue;
    } else if (isStop) {
      bgColor = Colors.grey.shade800;
    } else {
      bgColor = Colors.white12;
    }

    return GestureDetector(
      onTapDown: (_) => _sendCommand(cmd),
      onTapUp: (_) => _sendCommand('S'),
      onTapCancel: () => _sendCommand('S'),
      child: Container(
        width: isStop ? 70 : 70,
        height: isStop ? 70 : 70,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: bgColor.withOpacity(0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              icon,
              color: isBlocked && isActive ? Colors.white : Colors.white70,
              size: isStop ? 32 : 28,
            ),
            if (isBlocked && isActive)
              Positioned(
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'BLOCKED',
                    style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedSlider() {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.speed, color: Colors.white54),
            const SizedBox(width: 8),
            const Text('Speed', style: TextStyle(color: Colors.white54, fontSize: 13)),
            const Spacer(),
            Text(
              '$_speed',
              style: TextStyle(
                color: _speed > 200
                    ? Colors.red
                    : _speed > 120
                        ? Colors.orange
                        : Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        Slider(
          value: _speed.toDouble(),
          min: 0,
          max: 255,
          divisions: 255,
          activeColor: _speed > 200
              ? Colors.red
              : _speed > 120
                  ? Colors.orange
                  : Colors.green,
          onChanged: (val) {
            setState(() => _speed = val.round());
            _sendSpeed(val.round());
          },
        ),
      ],
    );
  }
}
