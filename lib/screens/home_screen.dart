import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> _opcionesFiltro1 = [];
  List<String> _opcionesFiltro2 = [];

  String? _filtro1Seleccionado;
  String? _filtro2Seleccionado;

  List<Map<dynamic, dynamic>> _resultados = [];

  @override
  void initState() {
    super.initState();
    cargarFiltrosDesdeFirebase();
  }

  Future<void> cargarFiltrosDesdeFirebase() async {
    final app = Firebase.app();
    final database = FirebaseDatabase.instanceFor(
      app: app,
      databaseURL: 'https://flutterrealtimeapp-91382-default-rtdb.firebaseio.com',
    );

    final ref = database.ref();
    final snapshot = await ref.get();

    if (snapshot.exists) {
      final data = snapshot.value as List<dynamic>;

      final Set<String> horas = {};
      final Set<String> edificiosNumericos = {};

      for (var clase in data) {
        if (clase is Map) {
          if (clase['A'] != null && clase['A'].toString().isNotEmpty) {
            String aula = clase['A'].toString();
            String prefijo = aula.substring(0, 1);
            edificiosNumericos.add(prefijo);
          }
          if (clase['B'] != null) {
            horas.add(clase['B']);
          }
        }
      }

      final edificiosFinales =
      edificiosNumericos.map((e) => "Edificio $e").toList()..sort();

      int parseHora(String horaStr) {
        final parts = horaStr.split(' ');
        if (parts.length != 2) return 0;

        final hm = parts[0].split(':');
        if (hm.length != 2) return 0;

        int hora = int.tryParse(hm[0]) ?? 0;
        int minuto = int.tryParse(hm[1]) ?? 0;
        final ampm = parts[1].toLowerCase();

        if (ampm == 'pm' && hora != 12) {
          hora += 12;
        }
        if (ampm == 'am' && hora == 12) {
          hora = 0;
        }

        return hora * 60 + minuto;
      }

      final horasFinales = horas.toList()
        ..sort((a, b) => parseHora(a).compareTo(parseHora(b)));

      setState(() {
        _opcionesFiltro1 = edificiosFinales;
        _opcionesFiltro2 = horasFinales;
      });

    }
  }

  Widget _buildFiltro({
    required String? value,
    required List<String> opciones,
    required String hint,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: DropdownButton<String>(
        value: value,
        hint: Text(hint),
        isExpanded: true,
        underline: SizedBox(),
        items: opciones.map((opcion) {
          return DropdownMenuItem<String>(
            value: opcion,
            child: Text(opcion),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  void buscarClases() async {
    if (_filtro1Seleccionado == null || _filtro2Seleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona ambos filtros')),
      );
      return;
    }

    final app = Firebase.app();
    final database = FirebaseDatabase.instanceFor(
      app: app,
      databaseURL: 'https://flutterrealtimeapp-91382-default-rtdb.firebaseio.com',
    );

    final ref = database.ref();
    final snapshot = await ref.get();

    if (snapshot.exists) {
      final data = snapshot.value as List<dynamic>;

      final resultadosFiltrados = data.where((clase) {
        if (clase is Map) {
          final aula = clase['A']?.toString() ?? '';
          final hora = clase['B']?.toString() ?? '';

          String edificio = "Edificio ${aula.substring(0, 1)}";
          return edificio == _filtro1Seleccionado && hora == _filtro2Seleccionado;
        }
        return false;
      }).toList();

      setState(() {
        _resultados = resultadosFiltrados.map((clase) {
          return {
            'materia': clase['F'] ?? 'Materia desconocida',
            'aula': clase['A'] ?? 'Sin aula',
          };
        }).toList();
      });

      if (_resultados.isEmpty) {
        print("No se encontraron clases con esos filtros.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo
          Positioned.fill(
            child: Image.asset(
              'assets/images/inicio.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // Contenido interactivo
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SizedBox(height: 125),
                  // Filtros y botón
                  Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: _buildFiltro(
                          value: _filtro1Seleccionado,
                          opciones: _opcionesFiltro1,
                          hint: 'Edificio',
                          onChanged: (value) {
                            setState(() => _filtro1Seleccionado = value);
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildFiltro(
                          value: _filtro2Seleccionado,
                          opciones: _opcionesFiltro2,
                          hint: 'Hora',
                          onChanged: (value) {
                            setState(() => _filtro2Seleccionado = value);
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.search, color: Colors.white),
                          onPressed: buscarClases,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (_resultados.isNotEmpty)
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView(
                          children: _resultados.map((clase) {
                            return ListTile(
                              leading: Icon(Icons.class_),
                              title: Text(clase["materia"]),
                              subtitle: Text("Aula ${clase["aula"]}"),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
