//Pantalla de Inicio (Busqueda)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, String> _asistenciasRegistradas = {};
  bool _mostrarMensajeFiltros = false;
  bool _busquedaRealizada = false;
  bool _cargando = false;
  bool _mostrarPanelFiltros = false;
  List<String> _opcionesFiltro1 = [];
  List<String> _opcionesFiltro2 = [];
  List<String> _todasLasHoras = [];

  String? _turnoSeleccionado;
  final List<String> _opcionesTurno = ['AM', 'PM'];

  String? _filtro1Seleccionado;
  String? _filtro2Seleccionado;

  String? _diaActual;

  int _busquedaKey = 0;
  int _expansionTileKey = 0;

  List<Map<dynamic, dynamic>> _pendientes = [];
  List<Map<dynamic, dynamic>> _revisados = [];
  List<Map<dynamic, dynamic>> _noSupervisados = [];

  // Función para normalizar texto
  String quitarTildes(String str) {
    return str
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U');
  }

  List<String> filtrarHorasPorTurno(String turno, List<String> todasLasHoras) {
    return todasLasHoras.where((hora) {
      final partesHora = hora.split(':');
      if (partesHora.length != 2) return false;
      final horaNum = int.tryParse(partesHora[0]) ?? 0;
      if (turno == 'AM') {
        return horaNum < 12;
      } else if (turno == 'PM') {
        return horaNum >= 12;
      }
      return false;
    }).toList();
  }

  //Confirmar Salida
  Future<bool> _confirmarSalida() async {
    final bool? exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[200],
        title: const Text('Confirmar Salida'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              //backgroundColor: Colors.grey[200],
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.blueAccent,
              //backgroundColor: Colors.grey[200],
            ),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pop(true);
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    return exit ?? false;
  }

  @override
  void initState() {
    super.initState();
    _setDiaActual();
    cargarFiltrosDesdeFirebase();
  }

  void _setDiaActual() {
    final now = DateTime.now();
    const dias = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
    ];
    setState(() {
      if (now.weekday >= 1 && now.weekday <= 6) {
        _diaActual = dias[now.weekday - 1];
      } else {
        _diaActual = null;
      }
    });
  }

  Future<void> cargarFiltrosDesdeFirebase() async {
    final app = Firebase.app();
    final database = FirebaseDatabase.instanceFor(
      app: app,
      databaseURL:
          'https://flutterrealtimeapp-91382-default-rtdb.firebaseio.com',
    );

    final ref = database.ref();
    final snapshot = await ref.get();

    if (snapshot.exists) {
      final data = snapshot.value;
      List<dynamic> clasesList = [];
      if (data is List) {
        clasesList = data.where((e) => e != null).toList();
      } else if (data is Map) {
        clasesList = data.values.where((e) => e != null).toList();
      }

      final Set<String> horas = {};
      final Set<String> edificiosNumericos = {};

      for (var clase in clasesList) {
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
            if (horaCruda.contains(':') &&
                horaCruda.length >= 4 &&
                horaCruda != '00:00' &&
                horaCruda != '--') {
              final partes = horaCruda.split(' a ');
              if (partes.isNotEmpty) {
                String horaInicio = partes[0].trim();
                horas.add(horaInicio);
              }
            }
          }
        }
      }

      final edificiosFinales =
          edificiosNumericos.map((e) => "Edificio $e").toList()..sort();

      final horasFinales = horas.toList()
        ..sort((a, b) {
          int ha = int.tryParse(a.split(':')[0]) ?? 0;
          int ma = int.tryParse(a.split(':')[1]) ?? 0;
          int hb = int.tryParse(b.split(':')[0]) ?? 0;
          int mb = int.tryParse(b.split(':')[1]) ?? 0;
          return (ha * 60 + ma).compareTo(hb * 60 + mb);
        });

      setState(() {
        _opcionesFiltro1 = edificiosFinales;
        _opcionesFiltro2 = horasFinales;
        _todasLasHoras = horasFinales;
      });
    }
  }

  Future<List<String>> _filtrarHorasPorEdificio(
    String edificioSeleccionado,
  ) async {
    final app = Firebase.app();
    final database = FirebaseDatabase.instanceFor(
      app: app,
      databaseURL:
          'https://flutterrealtimeapp-91382-default-rtdb.firebaseio.com',
    );

    final ref = database.ref();
    final snapshot = await ref.get();

    if (snapshot.exists) {
      final data = snapshot.value;
      List<dynamic> clasesList = [];
      if (data is List) {
        clasesList = data.where((e) => e != null).toList();
      } else if (data is Map) {
        clasesList = data.values.where((e) => e != null).toList();
      }
      final Set<String> horasDelEdificio = {};

      for (var clase in clasesList) {
        if (clase is Map) {
          final aula = clase['A']?.toString() ?? '';
          final hora = clase['B']?.toString() ?? '';

          // Verificar si la clase pertenece al edificio seleccionado
          if (aula.isNotEmpty) {
            String edificio = "Edificio ${aula.substring(0, 1)}";

            if (edificio == edificioSeleccionado) {
              // Extraer hora de inicio válida
              if (hora.contains(':') &&
                  hora.length >= 4 &&
                  hora != '00:00' &&
                  hora != '--') {
                final partes = hora.split(' a ');
                if (partes.isNotEmpty) {
                  String horaInicio = partes[0].trim();
                  horasDelEdificio.add(horaInicio);
                }
              }
            }
          }
        }
      }

      // Convertir a lista y ordenar
      final horasOrdenadas = horasDelEdificio.toList()
        ..sort((a, b) {
          int ha = int.tryParse(a.split(':')[0]) ?? 0;
          int ma = int.tryParse(a.split(':')[1]) ?? 0;
          int hb = int.tryParse(b.split(':')[0]) ?? 0;
          int mb = int.tryParse(b.split(':')[1]) ?? 0;
          return (ha * 60 + ma).compareTo(hb * 60 + mb);
        });

      // Filtrar por turno si ya hay uno seleccionado
      if (_turnoSeleccionado != null) {
        return filtrarHorasPorTurno(_turnoSeleccionado!, horasOrdenadas);
      }

      return horasOrdenadas;
    }

    return [];
  }

  // ======= INICIO BLOQUE 2 =======
  void buscarClases() async {
    setState(() {
      _cargando = true;
      _busquedaRealizada = true;
    });

    if (_diaActual == null) {
      setState(() {
        _pendientes = [];
        _revisados = [];
        _noSupervisados = [];
        _cargando = false;
        _busquedaKey++;
        _expansionTileKey++;
      });
      return;
    }

    if (_turnoSeleccionado == null ||
        _filtro1Seleccionado == null ||
        _filtro2Seleccionado == null) {
      setState(() {
        _mostrarMensajeFiltros = true;
        _cargando = false;
      });
      return;
    }

    // Si llegamos aquí, todos los filtros están seleccionados, ocultar el mensaje
    setState(() {
      _mostrarMensajeFiltros = false;
    });

    final app = Firebase.app();
    final database = FirebaseDatabase.instanceFor(
      app: app,
      databaseURL:
          'https://flutterrealtimeapp-91382-default-rtdb.firebaseio.com',
    );

    final ref = database.ref();
    final snapshot = await ref.get();

    if (!snapshot.exists) {
      setState(() => _cargando = false);
      return;
    }

    final data = snapshot.value;
    List<dynamic> clasesList = [];
    if (data is List) {
      clasesList = data.where((e) => e != null).toList();
    } else if (data is Map) {
      clasesList = data.values.where((e) => e != null).toList();
    }

    final clasesFiltradas = clasesList.where((clase) {
      if (clase is! Map) return false;

      final aula = clase['A']?.toString() ?? '';
      final hora = clase['B']?.toString() ?? '';
      final edificio = aula.isNotEmpty
          ? "Edificio ${aula.substring(0, 1)}"
          : '';

      if (edificio != _filtro1Seleccionado) return false;

      final partes = hora.split(' a ');
      if (partes.length != 2) return false;
      final horaInicio = partes[0].trim();
      final horaNum = int.tryParse(horaInicio.split(':')[0]) ?? 0;

      if (_turnoSeleccionado == 'AM' && horaNum >= 12) return false;
      if (_turnoSeleccionado == 'PM' && horaNum < 12) return false;

      if (_filtro2Seleccionado != null && horaInicio != _filtro2Seleccionado) {
        return false;
      }

      if (_diaActual != null) {
        final diaClase = quitarTildes(
          clase['C']?.toString().trim().toLowerCase() ?? '',
        );
        final diaActual = quitarTildes(_diaActual!.trim().toLowerCase());
        if (diaClase != diaActual) return false;
      }
      return true;
    }).toList();

    final clasesAgrupadas = _agruparClasesConsecutivas(clasesFiltradas);

    final clasesAgrupadasFiltradas = clasesAgrupadas.where((clase) {
      // Verificar que materia y profe no estén vacíos
      final materia = (clase['materia'] ?? '').toString().trim();
      final profe = (clase['profe'] ?? '').toString().trim();
      final grupo = (clase['grupo'] ?? '').toString().trim();

      // Filtrar si están vacíos o contienen "VACIO" o "sin asignar"
      if (materia.isEmpty ||
          materia.toUpperCase().contains('VACIO') ||
          materia.toLowerCase().contains('sin asignar')) {
        return false;
      }

      if (profe.isEmpty ||
          profe.toUpperCase().contains('VACIO') ||
          profe.toLowerCase().contains('sin asignar')) {
        return false;
      }

      if (grupo.isEmpty || grupo.toLowerCase().contains('sin asignar')) {
        return false;
      }

      return true;
    }).toList();

    // --- Clasificación de la Asistencia ---
    List<Map<dynamic, dynamic>> pendientes = [];
    List<Map<dynamic, dynamic>> revisados = [];
    List<Map<dynamic, dynamic>> noSupervisados = [];

    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);

    for (var clase in clasesAgrupadasFiltradas) {
      final horarioParaClave = clase["horario"]
          .toString()
          .replaceAll(' ', '-')
          .replaceAll(':', '');
      final claveRegistro = "${clase["profeid"]}_$horarioParaClave";
      final asistenciaRegistrada = _asistenciasRegistradas[claveRegistro];

      if (asistenciaRegistrada != null) {
        revisados.add(clase);
        continue;
      }

      final horaInicioStr = _parseHoraInicio(clase["horario"]);
      final partes = horaInicioStr.split(':');
      if (partes.length == 2) {
        final hora = int.tryParse(partes[0]) ?? 0;
        final minuto = int.tryParse(partes[1]) ?? 0;
        final inicioClase = hoy.add(Duration(hours: hora, minutes: minuto));
        final finVentana = inicioClase.add(const Duration(minutes: 15));

        if (now.isAfter(finVentana)) {
          noSupervisados.add(clase);
        } else {
          pendientes.add(clase);
        }
      } else {
        // Si no se puede parsear la hora, lo dejamos en pendientes por defecto
        pendientes.add(clase);
      }
    }

    pendientes = pendientes
        .where((clase) => (clase['materia'] ?? '').toString().trim().isNotEmpty)
        .toList();
    revisados = revisados
        .where((clase) => (clase['materia'] ?? '').toString().trim().isNotEmpty)
        .toList();
    noSupervisados = noSupervisados
        .where((clase) => (clase['materia'] ?? '').toString().trim().isNotEmpty)
        .toList();

    setState(() {
      _pendientes = pendientes;
      _revisados = revisados;
      _noSupervisados = noSupervisados;
      _cargando = false;
      _busquedaKey++;
      _expansionTileKey++;
    });
  }

  // Función para agrupar clases consecutivas
  List<Map<dynamic, dynamic>> _agruparClasesConsecutivas(List<dynamic> clases) {
    // Convertir a lista de mapas y ordenar por profesor, día, aula, materia y hora
    List<Map<String, dynamic>> clasesOrdenadas = clases.map((clase) {
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

    // Ordenar por profesor, día, aula, materia y hora de inicio
    clasesOrdenadas.sort((a, b) {
      // Ordenar por número de aula (considerando posibles letras)
      final regex = RegExp(r'^(\d+)([A-Za-z]*)$');
      final matchA = regex.firstMatch(a['aula']);
      final matchB = regex.firstMatch(b['aula']);

      if (matchA != null && matchB != null) {
        int numA = int.parse(matchA.group(1)!);
        int numB = int.parse(matchB.group(1)!);
        int comp = numA.compareTo(numB);
        if (comp != 0) return comp;
        // Si el número es igual, comparar la parte de letras
        comp = (matchA.group(2) ?? '').compareTo(matchB.group(2) ?? '');
        if (comp != 0) return comp;
      } else if (matchA != null) {
        // A es numérica, B no
        return -1;
      } else if (matchB != null) {
        // B es numérica, A no
        return 1;
      } else {
        // Ambos no son numéricos, comparar alfabéticamente
        int comp = a['aula'].compareTo(b['aula']);
        if (comp != 0) return comp;
      }

      // Si el aula es igual, ordenar por hora de inicio
      int minutosA = _convertirHoraAMinutos(_parseHoraInicio(a['horario']));
      int minutosB = _convertirHoraAMinutos(_parseHoraInicio(b['horario']));
      int comp = minutosA.compareTo(minutosB);
      if (comp != 0) return comp;

      // Si el aula y la hora son iguales, ordenar por nombre de maestro
      comp = a['profe'].compareTo(b['profe']);
      if (comp != 0) return comp;

      // Si también es igual, puedes seguir por día, materia, etc.
      comp = a['dia'].compareTo(b['dia']);
      if (comp != 0) return comp;

      return a['materia'].compareTo(b['materia']);
    });

    List<Map<dynamic, dynamic>> resultado = [];

    for (int i = 0; i < clasesOrdenadas.length; i++) {
      Map<String, dynamic> claseActual = clasesOrdenadas[i];

      // Buscar clases consecutivas del mismo profesor, día, aula y materia
      List<Map<String, dynamic>> clasesConsecutivas = [claseActual];

      for (int j = i + 1; j < clasesOrdenadas.length; j++) {
        Map<String, dynamic> siguienteClase = clasesOrdenadas[j];

        // Verificar si es la misma clase, mismo profesor, día, aula y materia
        if (claseActual['profe'] == siguienteClase['profe'] &&
            claseActual['dia'] == siguienteClase['dia'] &&
            claseActual['aula'] == siguienteClase['aula'] &&
            claseActual['materia'] == siguienteClase['materia']) {
          // Verificar si las horas son consecutivas
          String horaFinAnterior = _parseHoraFin(
            clasesConsecutivas.last['horario'],
          );
          String horaInicioSiguiente = _parseHoraInicio(
            siguienteClase['horario'],
          );

          if (_sonHorasConsecutivas(horaFinAnterior, horaInicioSiguiente)) {
            clasesConsecutivas.add(siguienteClase);
          } else {
            break;
          }
        } else {
          break;
        }
      }

      // Crear el resultado con el rango de horas unificado
      String horaInicio = _parseHoraInicio(clasesConsecutivas.first['horario']);
      String horaFin = _parseHoraFin(clasesConsecutivas.last['horario']);
      String horarioUnificado = '$horaInicio a $horaFin';

      Map<dynamic, dynamic> claseUnificada = {
        'aula': claseActual['aula'],
        'horario': horarioUnificado,
        'dia': claseActual['dia'],
        'grupo': claseActual['grupo'],
        'materia': claseActual['materia'],
        'profe': claseActual['profe'],
        'profeid': claseActual['profeid'],
      };

      resultado.add(claseUnificada);

      // Saltar las clases que ya fueron agrupadas
      i += clasesConsecutivas.length - 1;
    }

    return resultado;
  }

  // Función auxiliar para extraer la hora de inicio
  String _parseHoraInicio(String horario) {
    final partes = horario.split(' a ');
    return partes.isNotEmpty ? partes[0].trim() : '';
  }

  // Función auxiliar para extraer la hora de fin
  String _parseHoraFin(String horario) {
    final partes = horario.split(' a ');
    return partes.length > 1 ? partes[1].trim() : '';
  }

  // Función auxiliar para verificar si dos horas son consecutivas
  bool _sonHorasConsecutivas(String horaFin, String horaInicio) {
    try {
      // Convertir horas a minutos para comparar
      int minutosFin = _convertirHoraAMinutos(horaFin);
      int minutosInicio = _convertirHoraAMinutos(horaInicio);

      // Considerar consecutivas si la diferencia es de 0 a 10 minutos
      int diferencia = minutosInicio - minutosFin;
      return diferencia >= 0 && diferencia <= 10;
    } catch (e) {
      return false;
    }
  }

  // Función auxiliar para convertir hora en formato "HH:MM" a minutos
  int _convertirHoraAMinutos(String hora) {
    final partes = hora.split(':');
    if (partes.length != 2) return 0;

    int horas = int.tryParse(partes[0]) ?? 0;
    int minutos = int.tryParse(partes[1]) ?? 0;

    return horas * 60 + minutos;
  }

  // --- Funciones de asistencias ---

  Future<void> _registrarAsistencia(
    Map<dynamic, dynamic> clase,
    String estadoAsistencia,
  ) async {
    setState(() {
      _cargando = true;
    });

    try {
      final app = Firebase.app();
      final database = FirebaseDatabase.instanceFor(
        app: app,
        databaseURL:
            'https://flutterrealtimeapp-91382-default-rtdb.firebaseio.com',
      );

      final ref = database.ref();

      final now = DateTime.now();
      final fechaActual =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final horarioParaClave = clase["horario"]
          .toString()
          .replaceAll(' ', '-')
          .replaceAll(':', '');
      final claveRegistro = "${clase["profeid"]}_$horarioParaClave";

      final asistenciaRef = ref
          .child('asistencias')
          .child(fechaActual)
          .child(claveRegistro);

      final datosAsistencia = {
        'estado': estadoAsistencia,
        'profe': clase["profe"],
        'profeid': clase["profeid"],
        'aula': clase["aula"],
        'grupo': clase["grupo"],
        'materia': clase["materia"],
        'horario': clase["horario"],
        'timestamp': ServerValue.timestamp,
      };

      await asistenciaRef.set(datosAsistencia);

      // Actualiza el mapa local
      setState(() {
        _asistenciasRegistradas[claveRegistro] = estadoAsistencia;
      });

      // Vuelve a buscar las clases para refrescar las listas
      buscarClases();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Asistencia registrada'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar asistencia: $e')),
      );
      print('Error al registrar asistencia: $e');
    } finally {
      setState(() {
        _cargando = false;
      });
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
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
        return DropdownMenuItem<String>(value: opcion, child: Text(opcion));
      }).toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmarSalida,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/images/inicio.jpg', fit: BoxFit.cover),
            ),
            SafeArea(
              child: _mostrarPanelFiltros
                  ? _buildPanelFiltrosYResultados()
                  : _buildTablaAulasNoRevisadas(),
            ),
            if (_cargando)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelFiltrosYResultados() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(height: 125),
          Row(
            children: [
              //Configuracion Turno
              SizedBox(
                width: 80,
                child: _buildFiltro(
                  value: _turnoSeleccionado,
                  opciones: _opcionesTurno,
                  hint: 'Turno',
                  onChanged: (value) async {
                    setState(() {
                      _turnoSeleccionado = value;
                      _filtro2Seleccionado = null;
                    });

                    if (_filtro1Seleccionado != null && value != null) {
                      final horasDelEdificio = await _filtrarHorasPorEdificio(
                        _filtro1Seleccionado!,
                      );
                      setState(() {
                        _opcionesFiltro2 = filtrarHorasPorTurno(
                          value,
                          horasDelEdificio,
                        );
                      });
                    } else {
                      setState(() {
                        _opcionesFiltro2 = [];
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),

              //Configuracion Edificio
              SizedBox(
                width: 120,
                child: _buildFiltro(
                  value: _filtro1Seleccionado,
                  opciones: _opcionesFiltro1,
                  hint: 'Edificio',
                  onChanged: (value) async {
                    setState(() {
                      _filtro1Seleccionado = value;
                      _filtro2Seleccionado = null;
                    });

                    if (value != null) {
                      final horasDelEdificio = await _filtrarHorasPorEdificio(
                        value,
                      );
                      setState(() {
                        _opcionesFiltro2 = horasDelEdificio;
                      });
                    } else {
                      setState(() {
                        _opcionesFiltro2 = [];
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
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
              const SizedBox(width: 10),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: buscarClases,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          if (_mostrarMensajeFiltros)
            Padding(
              padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
              child: Text(
                'Por favor seleccione todos los filtros antes de buscar.',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (_pendientes.isNotEmpty ||
              _revisados.isNotEmpty ||
              _noSupervisados.isNotEmpty)
            Expanded(
              child:
                  (_pendientes.isNotEmpty ||
                      _revisados.isNotEmpty ||
                      _noSupervisados.isNotEmpty)
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CustomScrollView(
                        slivers: [
                          if (_pendientes.isNotEmpty) ...[
                            SliverPersistentHeader(
                              pinned: false,
                              delegate: _HeaderDelegate(
                                child: _buildSeccionTitulo(
                                  'Pendientes Por Revisar',
                                ),
                                minHeight: 40,
                                maxHeight: 40,
                              ),
                            ),
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) => _buildClaseCard(
                                  _pendientes[i],
                                  revisado: false,
                                  noSupervisado: false,
                                ),
                                childCount: _pendientes.length,
                              ),
                            ),
                          ],
                          if (_revisados.isNotEmpty) ...[
                            SliverPersistentHeader(
                              pinned: false,
                              delegate: _HeaderDelegate(
                                child: _buildSeccionTitulo('Revisados'),
                                minHeight: 40,
                                maxHeight: 40,
                              ),
                            ),
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) => _buildClaseCard(
                                  _revisados[i],
                                  revisado: true,
                                  noSupervisado: false,
                                ),
                                childCount: _revisados.length,
                              ),
                            ),
                          ],
                          if (_noSupervisados.isNotEmpty) ...[
                            SliverPersistentHeader(
                              pinned: false,
                              delegate: _HeaderDelegate(
                                child: _buildSeccionTitulo('No Supervisados'),
                                minHeight: 40,
                                maxHeight: 40,
                              ),
                            ),
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) => _buildClaseCard(
                                  _noSupervisados[i],
                                  revisado: false,
                                  noSupervisado: true,
                                ),
                                childCount: _noSupervisados.length,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : Center(
                      child: Text(
                        'No hay clases disponibles',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildEdificioIcono(String nombre) {
    return Column(
      children: [
        Icon(Icons.location_city, size: 40, color: Color(0xFF193863)),
        const SizedBox(height: 5),
        Text(
          nombre,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF193863),
          ),
        ),
      ],
    );
  }

  Widget _buildTablaAulasNoRevisadas() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(height: 125),
          Text(
            'Aulas Aun No Revisadas',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF193863),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 15),

          // Tabla vacía
          DataTable(
            columns: const [
              DataColumn(
                label: Text(
                  'Aula',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF193863),
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Estado',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF193863),
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
            rows: const [], // Sin datos por ahora
          ),

          const SizedBox(height: 30),

          // Mapa/diagrama de edificios
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildEdificioIcono('Edificio 1'),
              _buildEdificioIcono('Edificio 2'),
              _buildEdificioIcono('Edificio 3'),
              _buildEdificioIcono('Edificio 4'),
              _buildEdificioIcono('Edificio 5'),
            ],
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _mostrarPanelFiltros = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF193863),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Continuar Revisión',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
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
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 5),
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

  // ======= INICIO BLOQUE 4 =======
  Widget _buildSeccionTitulo(String texto) => Padding(
    padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF193863),
          letterSpacing: 1.1,
        ),
      ),
    ),
  );

  Widget _buildClaseCard(
    Map<dynamic, dynamic> clase, {
    bool revisado = false,
    bool noSupervisado = false,
  }) {
    final horarioParaClave = clase["horario"]
        .toString()
        .replaceAll(' ', '-')
        .replaceAll(':', '');
    final claveRegistro = "${clase["profeid"]}_$horarioParaClave";
    final asistenciaRegistrada = _asistenciasRegistradas[claveRegistro];
    final botonesDeshabilitados = revisado || asistenciaRegistrada != null;

    // --- Lógica de ventana de tiempo ---
    bool fueraDeVentana = false;
    if (!botonesDeshabilitados) {
      final horaInicioStr = _parseHoraInicio(clase["horario"]);
      final now = DateTime.now();
      final hoy = DateTime(now.year, now.month, now.day);

      final partes = horaInicioStr.split(':');
      if (partes.length == 2) {
        final hora = int.tryParse(partes[0]) ?? 0;
        final minuto = int.tryParse(partes[1]) ?? 0;
        final inicioClase = hoy.add(Duration(hours: hora, minutes: minuto));
        final finVentana = inicioClase.add(const Duration(minutes: 15));
        // Si ya pasó la ventana, deshabilita los botones
        fueraDeVentana = now.isAfter(finVentana);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1.0),
      ),
      child: ExpansionTile(
        key: ValueKey(
          '$_expansionTileKey-${clase["profe"]}-${clase["aula"]}-${clase["horario"]}',
        ),
        title: Text(
          clase["profe"],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        collapsedBackgroundColor: Colors.white,
        backgroundColor: Colors.grey[200],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Horario:', clase["horario"]),
                _buildInfoRow('Aula:', clase["aula"]),
                _buildInfoRow('Grupo:', clase["grupo"]),
                _buildInfoRow('Materia:', clase["materia"]),
                const SizedBox(height: 10),

                // Logica para los textos de informacion adicionales
                if (noSupervisado)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No Se Registró Asistencia a Tiempo',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  )
                else if (botonesDeshabilitados)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Asistencia Registrada: ${asistenciaRegistrada == "asistio" ? "Asistió" : "Faltó"}',
                      style: TextStyle(
                        color: asistenciaRegistrada == "asistio"
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  )
                else if (fueraDeVentana)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Fuera De Tiempo Para Registrar Asistencia',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  )
                else
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _registrarAsistencia(clase, "asistio"),
                        icon: const Icon(Icons.check_circle, size: 20),
                        label: const Text(
                          'Asistió',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _registrarAsistencia(clase, "falto"),
                        icon: const Icon(Icons.cancel, size: 20),
                        label: const Text(
                          'Faltó',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }



  // ======= FIN BLOQUE 4 =======
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minHeight;
  final double maxHeight;

  _HeaderDelegate({
    required this.child,
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(covariant _HeaderDelegate oldDelegate) {
    return oldDelegate.child != child ||
        oldDelegate.minHeight != minHeight ||
        oldDelegate.maxHeight != maxHeight;
  }
}
