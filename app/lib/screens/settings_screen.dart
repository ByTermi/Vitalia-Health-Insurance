import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../storage/database_service.dart';

const _kBg = Color(0xFFEFF2F6);
const _kSurface = Color(0xFFFFFFFF);
const _kInk = Color(0xFF1F2533);
const _kAccent = Color(0xFF03045E);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _api = ApiService.instance;
  final _db = DatabaseService.instance;
  bool _connected = false;
  bool _working = false;
  String? _statusMsg;

  @override
  void initState() {
    super.initState();
    _api.checkHealth().then((ok) {
      if (mounted) setState(() => _connected = ok);
    });
  }

  Future<void> _showIpDialog() async {
    var profiles = await _db.getAllProfiles();
    if (!mounted) return;
    final ipCtrl = TextEditingController(text: _api.ip);
    final portCtrl = TextEditingController(text: _api.port.toString());
    final nameCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: _kSurface,
          title: const Text('Conexión al Backend',
              style: TextStyle(color: _kInk, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (profiles.isNotEmpty) ...[
                    Text('Perfiles guardados',
                        style: TextStyle(color: _kInk.withOpacity(0.5), fontSize: 12)),
                    const SizedBox(height: 4),
                    ...profiles.map((p) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(p.name,
                              style: const TextStyle(color: _kInk, fontSize: 13)),
                          subtitle: Text('${p.ip}:${p.port}',
                              style: TextStyle(
                                  color: _kInk.withOpacity(0.5), fontSize: 11)),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: _kInk.withOpacity(0.38), size: 18),
                            onPressed: () async {
                              await _db.deleteProfile(p.id!);
                              final updated = await _db.getAllProfiles();
                              setStateDialog(() => profiles = updated);
                            },
                          ),
                          onTap: () async {
                            Navigator.of(ctx).pop();
                            await _db.touchProfile(p.id!);
                            setState(() {
                              _api.ip = p.ip;
                              _api.port = p.port;
                              _connected = false;
                            });
                            final ok = await _api.checkHealth();
                            if (mounted) setState(() => _connected = ok);
                          },
                        )),
                    Divider(color: _kInk.withOpacity(0.10)),
                    const SizedBox(height: 4),
                  ],
                  _field(ipCtrl, 'IP del servidor', '10.0.2.2'),
                  const SizedBox(height: 8),
                  _field(portCtrl, 'Puerto', '8000',
                      type: TextInputType.number),
                  const SizedBox(height: 8),
                  _field(nameCtrl, 'Guardar como perfil', 'Casa, Trabajo...'),
                  const SizedBox(height: 6),
                  Text(
                    'Emulador: 10.0.2.2 · Dispositivo físico: IP local del PC',
                    style:
                        TextStyle(color: _kInk.withOpacity(0.38), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancelar',
                  style: TextStyle(color: _kInk.withOpacity(0.54))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent, foregroundColor: Colors.white),
              onPressed: () async {
                final ip = ipCtrl.text.trim();
                final port = int.tryParse(portCtrl.text.trim()) ?? 8000;
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  await _db.insertProfile(ServerProfile(
                    name: name,
                    ip: ip,
                    port: port,
                    lastUsed: DateTime.now().millisecondsSinceEpoch,
                  ));
                }
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                setState(() {
                  _api.ip = ip;
                  _api.port = port;
                  _connected = false;
                });
                final ok = await _api.checkHealth();
                if (mounted) setState(() => _connected = ok);
              },
              child: const Text('Conectar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearLocalData() async {
    setState(() => _working = true);
    await _db.pruneOld(keepMs: 0);
    setState(() {
      _working = false;
      _statusMsg = 'Datos locales borrados';
    });
  }

  Future<void> _deleteBackendData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFDECEC),
        title: const Text('Borrar todos mis datos',
            style: TextStyle(color: _kInk, fontWeight: FontWeight.bold)),
        content: Text(
          'Esto elimina todos tus eventos de actividad, caídas y VitaPoints '
          'del servidor de forma permanente (Art. 17 RGPD — Derecho al olvido).\n\n'
          'Los datos locales del dispositivo no se eliminan aquí.',
          style: TextStyle(color: _kInk.withOpacity(0.70)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: TextStyle(color: _kInk.withOpacity(0.54))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Borrar mis datos',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _working = true);
    final ok = await _api.deleteUserData();
    setState(() {
      _working = false;
      _statusMsg = ok
          ? 'Datos eliminados del servidor (204)'
          : 'Error: servidor no alcanzable';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        title: const Text('Ajustes',
            style: TextStyle(color: _kInk, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kInk),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _working
          ? const Center(child: CircularProgressIndicator(color: _kAccent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('Backend'),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _connected
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_off_outlined,
                            color: _connected
                                ? _kAccent
                                : _kInk.withOpacity(0.38),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_api.ip}:${_api.port}',
                              style:
                                  const TextStyle(color: _kInk, fontSize: 14),
                            ),
                          ),
                          TextButton(
                            onPressed: _showIpDialog,
                            child: const Text('Cambiar',
                                style: TextStyle(color: _kAccent)),
                          ),
                        ],
                      ),
                      Text(
                        _connected ? 'Conectado' : 'Sin conexión',
                        style: TextStyle(
                            color: _connected
                                ? _kAccent
                                : _kInk.withOpacity(0.38),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _section('Datos locales'),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SQLite en el dispositivo: lecturas de sensores y caídas locales.',
                        style: TextStyle(
                            color: _kInk.withOpacity(0.55), fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orangeAccent,
                            side: const BorderSide(color: Colors.orangeAccent),
                          ),
                          onPressed: _clearLocalData,
                          child: const Text('Borrar datos locales'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _section('Privacidad — RGPD'),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Art. 17 RGPD — Derecho al olvido.\n'
                        'Elimina permanentemente todos tus datos de actividad, caídas '
                        'y VitaPoints del servidor.',
                        style: TextStyle(
                            color: _kInk.withOpacity(0.55),
                            fontSize: 12,
                            height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.13),
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                          onPressed: _deleteBackendData,
                          child: const Text('Borrar mis datos del servidor'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_statusMsg != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kInk.withOpacity(0.08)),
                    ),
                    child: Text(_statusMsg!,
                        style: const TextStyle(color: _kAccent, fontSize: 13)),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label,
            style: TextStyle(
                color: _kInk.withOpacity(0.55),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kInk.withOpacity(0.06)),
        ),
        child: child,
      );

  Widget _field(TextEditingController ctrl, String label, String hint,
          {TextInputType? type}) =>
      TextField(
        controller: ctrl,
        style: const TextStyle(color: _kInk),
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: _kInk.withOpacity(0.55)),
          hintText: hint,
          hintStyle: TextStyle(color: _kInk.withOpacity(0.28)),
          enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _kInk.withOpacity(0.20))),
          focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: _kAccent)),
        ),
      );
}
