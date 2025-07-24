//Pantalla de inicio

import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Variables para los filtros
  String? _filtro1Seleccionado;
  String? _filtro2Seleccionado;

  // Opciones para los Dropdowns
  final List<String> _opcionesFiltro1 = ['Edificio 1', 'Edificio 2', 'Edificio 3'];
  final List<String> _opcionesFiltro2 = ['7:00 am - 7:50 am', '7:50 am - 8:40 am', '8:40 am - 9:30 am', '9:30 am - 10:20 am', '10:20 am - 11:10 am'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo con imagen
          Positioned.fill(
            child: Image.asset(
              'assets/images/inicio.jpg',  // Cambia por tu imagen
              fit: BoxFit.cover,
            ),
          ),

          // Filtros y botón
          Positioned(
            bottom: 650,  // Distancia desde abajo
            left: 20,
            right: 20,
            child: Row(  // Fila horizontal
              children: [
                // Edificio
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

                SizedBox(width: 10),  // Espacio entre filtros

                // Hora
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

                // Espacio entre filtro y botón
                SizedBox(width: 10),

                // BOTÓN DE BÚSQUEDA
                Container(
                  width: 50,  // Ancho fijo para el botón
                  height: 50, // Altura igual a los Dropdowns
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.search, color: Colors.white),
                    onPressed: () {
                      print('Buscar: Edificio=$_filtro1Seleccionado, Piso=$_filtro2Seleccionado');
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget reutilizable para cada filtro (Dropdown)
  Widget _buildFiltro({
    required String? value,
    required List<String> opciones,
    required String hint,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButton<String>(
        isExpanded: true,
        hint: Text(hint),
        value: value,
        items: opciones.map((String opcion) {
          return DropdownMenuItem<String>(
            value: opcion,
            child: Text(opcion),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}