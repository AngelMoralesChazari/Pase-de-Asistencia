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
  bool _busquedaRealizada = false;
  bool _cargando = false;
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

  List<Map<dynamic, dynamic>> _resultados = [];

  // Función para quitar tildes y normalizar texto
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

  void buscarClases() async {
    setState(() {
      _cargando = true;
      _busquedaRealizada = true;
    });

    if (_diaActual == null) {
      setState(() {
        _resultados = [];
        _cargando = false;
        _busquedaKey++;
        _expansionTileKey++;
      });
      return;
    }

    if (_filtro1Seleccionado == null || _turnoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona turno y edificio')),
      );
      setState(() {
        _cargando = false;
      });
      return;
    }

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

      // Filtrar por edificio y turno
      final clasesFiltradas = clasesList.where((clase) {
        if (clase is Map) {
          final aula = clase['A']?.toString() ?? '';
          final hora = clase['B']?.toString() ?? '';
          String edificio = aula.length >= 1
              ? "Edificio ${aula.substring(0, 1)}"
              : '';

          // Filtrar por edificio
          if (edificio != _filtro1Seleccionado) return false;

          // Filtrar por turno
          final partes = hora.split(' a ');
          if (partes.length != 2) return false;
          final horaInicio = partes[0].trim();
          final horaNum = int.tryParse(horaInicio.split(':')[0]) ?? 0;

          if (_turnoSeleccionado == 'AM') {
            if (horaNum >= 12) return false; // Solo hasta 11:59
          }
          if (_turnoSeleccionado == 'PM') {
            if (horaNum < 12) return false; // Desde 12:00 en adelante
          }

          // Filtrar por hora seleccionada
          if (_filtro2Seleccionado != null &&
              horaInicio != _filtro2Seleccionado)
            return false;

          // Filtrar por día con normalización de tildes
          if (_diaActual != null) {
            String diaClase = quitarTildes(
              clase['C']?.toString().trim().toLowerCase() ?? '',
            );
            String diaActual = quitarTildes(_diaActual!.trim().toLowerCase());
            if (diaClase != diaActual) return false;
          }

          return true;
        }
        return false;
      }).toList();

      // Agrupar clases consecutivas
      final clasesAgrupadas = _agruparClasesConsecutivas(clasesFiltradas);

      setState(() {
        _resultados = clasesAgrupadas;
        _cargando = false;
        _busquedaKey++;
        _expansionTileKey++;
      });
    } else {
      setState(() {
        _cargando = false;
      });
    }
  }

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

        // Verificar si es la misma clase (mismo profesor, día, aula, materia)
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
            break; // No son consecutivas, salir del bucle
          }
        } else {
          break; // No es la misma clase, salir del bucle
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
      _cargando = true; // Muestra el indicador de carga
    });

    try {
      final app = Firebase.app();
      final database = FirebaseDatabase.instanceFor(
        app: app,
        databaseURL:
            'https://flutterrealtimeapp-91382-default-rtdb.firebaseio.com',
      );

      final ref = database.ref();

      // 1. Obtener la fecha actual en formato YYYY-MM-DD
      final now = DateTime.now();
      final fechaActual =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // 2. Crear la clave única para el registro de asistencia (¡AGREGA ESTO!)
      final horarioParaClave = clase["horario"]
          .toString()
          .replaceAll(' ', '-')
          .replaceAll(':', '');
      final claveRegistro = "${clase["profeid"]}_$horarioParaClave";

      //Deshabilita los botones de asistencia si ya se registró
      final asistenciaRegistrada = _asistenciasRegistradas[claveRegistro];
      final botonesDeshabilitados = asistenciaRegistrada != null;

      // 3. Definir la ruta donde se guardará la asistencia
      final asistenciaRef = ref
          .child('asistencias')
          .child(fechaActual)
          .child(claveRegistro);

      // 4. Crear el objeto de datos a guardar
      final datosAsistencia = {
        'estado': estadoAsistencia,
        'profe': clase["profe"],
        'profeid': clase["profeid"],
        'aula': clase["aula"],
        'grupo': clase["grupo"],
        'materia': clase["materia"],
        'horario': clase["horario"],
        'timestamp': ServerValue.timestamp,
        // Guarda la hora exacta del servidor de Firebase
      };

      // 5. Guardar los datos en Firebase
      await asistenciaRef.set(datosAsistencia);

      setState(() {
        _asistenciasRegistradas[claveRegistro] = estadoAsistencia;
      });

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Asistencia de ${clase["profe"]} registrada como "$estadoAsistencia"',
          ),
        ),
      );
    } catch (e) {
      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar asistencia: $e')),
      );
      print('Error al registrar asistencia: $e'); // Para depuración
    } finally {
      setState(() {
        _cargando = false; // Oculta el indicador de carga
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
              child: Padding(
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

                              // Si hay edificio seleccionado, actualizar horas por edificio y turno
                              if (_filtro1Seleccionado != null &&
                                  value != null) {
                                final horasDelEdificio =
                                    await _filtrarHorasPorEdificio(
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

                              // Filtrar horas por edificio seleccionado
                              if (value != null) {
                                final horasDelEdificio =
                                    await _filtrarHorasPorEdificio(value);
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

                    // Mostrar el texto solo si hay resultados
                    if (_resultados.isNotEmpty)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: CustomScrollView(
                            slivers: [
                              // El header que se mueve con el scroll
                              SliverPersistentHeader(
                                pinned: false,
                                floating: false,
                                delegate: _HeaderDelegate(
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      left: 4.0,
                                      bottom: 8.0,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Pendientes Por Revisar',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF193863),
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                    ),
                                  ),
                                  minHeight: 40,
                                  maxHeight: 40,
                                ),
                              ),
                              // La lista de resultados
                              SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  if (index < _resultados.length) {
                                    final clase = _resultados[index];
                                    final horarioParaClave = clase["horario"]
                                        .toString()
                                        .replaceAll(' ', '-')
                                        .replaceAll(':', '');
                                    final claveRegistro =
                                        "${clase["profeid"]}_$horarioParaClave";
                                    final asistenciaRegistrada =
                                        _asistenciasRegistradas[claveRegistro];
                                    final botonesDeshabilitados =
                                        asistenciaRegistrada != null;

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 13),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: BorderSide(
                                          color: Colors.grey.withOpacity(0.3),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: ExpansionTile(
                                        key: ValueKey(
                                          '$_expansionTileKey-${clase["profe"]}-${clase["aula"]}-${clase["horario"]}',
                                        ),
                                        title: Text(
                                          clase["profe"],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        collapsedBackgroundColor: Colors.white,
                                        backgroundColor: Colors.grey[200],
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        collapsedShape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildInfoRow(
                                                  'Horario:',
                                                  clase["horario"],
                                                ),
                                                _buildInfoRow(
                                                  'Aula:',
                                                  clase["aula"],
                                                ),
                                                _buildInfoRow(
                                                  'Grupo:',
                                                  clase["grupo"],
                                                ),
                                                _buildInfoRow(
                                                  'Materia:',
                                                  clase["materia"],
                                                ),
                                                const SizedBox(height: 10),
                                                if (botonesDeshabilitados)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 8.0,
                                                        ),
                                                    child: Text(
                                                      'Asistencia Registrada: ${asistenciaRegistrada == "asistio" ? "Asistió" : "Faltó"}',
                                                      style: TextStyle(
                                                        color:
                                                            asistenciaRegistrada ==
                                                                "asistio"
                                                            ? Colors.green
                                                            : Colors.red,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  Wrap(
                                                    alignment:
                                                        WrapAlignment.center,
                                                    spacing: 16,
                                                    runSpacing: 8,
                                                    children: [
                                                      ElevatedButton.icon(
                                                        onPressed:
                                                            botonesDeshabilitados
                                                            ? null
                                                            : () {
                                                                _registrarAsistencia(
                                                                  clase,
                                                                  "asistio",
                                                                );
                                                              },
                                                        icon: const Icon(
                                                          Icons.check_circle,
                                                          color: Colors.white,
                                                          size: 20,
                                                        ),
                                                        label: const Text(
                                                          'Asistió',
                                                          style: TextStyle(
                                                            fontSize: 17,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.green,
                                                          foregroundColor:
                                                              Colors.white,
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 20,
                                                                vertical: 10,
                                                              ),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                      ElevatedButton.icon(
                                                        onPressed:
                                                            botonesDeshabilitados
                                                            ? null
                                                            : () {
                                                                _registrarAsistencia(
                                                                  clase,
                                                                  "falto",
                                                                );
                                                              },
                                                        icon: const Icon(
                                                          Icons.cancel,
                                                          color: Colors.white,
                                                          size: 20,
                                                        ),
                                                        label: const Text(
                                                          'Faltó',
                                                          style: TextStyle(
                                                            fontSize: 17,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.red,
                                                          foregroundColor:
                                                              Colors.white,
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 20,
                                                                vertical: 10,
                                                              ),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
                                                                ),
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
                                  } else if (index == _resultados.length) {
                                    //Texto Revisados
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        left: 4.0,
                                        bottom: 8.0,
                                        top: 4,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Revisados',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF193863),
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                      ),
                                    );
                                  } else if (index == _resultados.length + 1) {
                                    //Texto No Revisados
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        left: 4.0,
                                        bottom: 8.0,
                                        top: 4,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'No Revisados',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF193863),
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return null;
                                }, childCount: _resultados.length + 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
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
