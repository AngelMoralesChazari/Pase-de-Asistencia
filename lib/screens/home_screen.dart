import 'dart:ui';
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
      final dataMap = snapshot.value as Map<dynamic, dynamic>;

      final Set<String> horas = {};
      final Set<String> edificiosNumericos = {};

      for (var clase in dataMap.values) {
        if (clase is Map) {
          if (clase['A'] != null && clase['A'].toString().isNotEmpty) {
            String aula = clase['A'].toString();
            if (aula.length >= 1) {
              String prefijo = aula.substring(0, 1);
              edificiosNumericos.add(prefijo);
            }
          }
          if (clase['B'] != null) {
            final horaCruda = clase['B'].toString().trim();
            // Filtrar horas válidas
            if (horaCruda.contains(':') && horaCruda.length >= 4 && horaCruda != '00:00' && horaCruda != '--') {
              horas.add(horaCruda);
            }
          }
        }
      }

      final edificiosFinales =
      edificiosNumericos.map((e) => "Edificio $e").toList()..sort();

      int parseHora(String horaStr) {
        horaStr = horaStr.trim();
        // Extraer solo la hora inicial antes de " a "
        final partes = horaStr.split(' a ');
        if (partes.isEmpty) return 0;

        String horaInicial = partes[0]; // Ejemplo: "18:20"

        // Parsear hora inicial en formato 24h
        final hm = horaInicial.split(':');
        if (hm.length != 2) return 0;

        int hora = int.tryParse(hm[0]) ?? 0;
        int minuto = int.tryParse(hm[1]) ?? 0;

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
      final dataMap = snapshot.value as Map<dynamic, dynamic>;

      final resultadosFiltrados = dataMap.values.where((clase) {
        if (clase is Map) {
          final aula = clase['A']?.toString() ?? '';
          final hora = clase['B']?.toString() ?? '';

          String edificio = aula.length >= 1 ? "Edificio ${aula.substring(0, 1)}" : '';

          return edificio.isNotEmpty
              && edificio == _filtro1Seleccionado
              && hora.trim() == _filtro2Seleccionado?.trim();
        }
        return false;
      }).toList();

      setState(() {
        _resultados = resultadosFiltrados.map((clase) {
          return {
            'aula': clase['A'] ?? '',
            'horario': clase['B'] ?? '',
            'dia': clase['C'] ?? '',
            'grupo': clase['D'] ?? '',
            'materia': clase['F'] ?? '',
            'profe': clase['G'] ?? '',
            'profeid': clase['H'] ?? '',
          };
        }).toList();
      });

      if (_resultados.isEmpty) {
        print("No se encontraron clases con esos filtros.");
      }
    }
  }

  Widget _buildFiltro({
    required String? value,
    required List<String> opciones,
    required String hint,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        hintText: hint,
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Color(0xFF193863)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
      ),
      isExpanded: true,
      icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
      dropdownColor: Colors.grey[200],
      items: opciones.map((opcion) {
        return DropdownMenuItem<String>(
          value: opcion,
          child: Text(opcion),
        );
      }).toList(),
      onChanged: onChanged,
    );
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
                            return Card(
                              margin: EdgeInsets.only(bottom: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: Colors.grey.withOpacity(0.3),
                                    width: 1.0,
                                  )),
                              child: ExpansionTile(
                                title: Text(
                                  clase["profe"],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                collapsedBackgroundColor: Colors.white,
                                backgroundColor: Colors.grey[200],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadiusGeometry.circular(8),
                                ),
                                collapsedShape: RoundedRectangleBorder(
                                  borderRadius: BorderRadiusGeometry.circular(8),
                                ),
                                children: [
                                  Padding(
                                    padding:
                                    EdgeInsets.symmetric(horizontal: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        _buildInfoRow('Horario:', clase["horario"]),
                                        _buildInfoRow('Aula:', clase["aula"]),
                                        _buildInfoRow('Grupo:', clase["grupo"]),
                                        _buildInfoRow('Materia:', clase["materia"]),
                                        SizedBox(height: 10),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}