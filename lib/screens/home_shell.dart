import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'pedidos_list_screen.dart';

class HomeShell extends StatefulWidget {
  final String nombreTienda;

  const HomeShell({super.key, required this.nombreTienda});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _indice = 0;

  Future<void> _cerrarSesion() async {
    await AuthService.cerrarSesion();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final paginas = [
      PedidosListScreen(nombreTienda: widget.nombreTienda),
      const DashboardScreen(),
    ];

    return Scaffold(
      body: paginas[_indice],
      floatingActionButton: _indice == 0
          ? FloatingActionButton.small(
              onPressed: _cerrarSesion,
              backgroundColor: AppTheme.textoSecundario,
              tooltip: 'Cerrar sesión',
              child: const Icon(Icons.logout, color: Colors.white),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Pedidos'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Dashboard'),
        ],
      ),
    );
  }
}
