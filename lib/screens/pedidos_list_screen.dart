import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/pedido.dart';
import '../services/pedidos_service.dart';
import '../widgets/pedido_card.dart';
import 'pedido_detalle_screen.dart';

class PedidosListScreen extends StatefulWidget {
  final String nombreTienda;

  const PedidosListScreen({super.key, required this.nombreTienda});

  @override
  State<PedidosListScreen> createState() => _PedidosListScreenState();
}

enum FiltroDestino { todos, lima, provincia }

enum FiltroPago { todos, pendiente, pagado, noCobrado, cancelado }

class _PedidosListScreenState extends State<PedidosListScreen> {
  late Stream<List<Pedido>> _stream;
  FiltroDestino _filtroDestino = FiltroDestino.todos;
  FiltroPago _filtroPago = FiltroPago.todos;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _stream = PedidosService.streamPedidos();
  }

  /// La lista ya es en tiempo real (Supabase Realtime), pero al deslizar
  /// hacia abajo forzamos una resuscripción inmediata del stream. Esto
  /// ayuda en redes lentas o cuando el socket de realtime se demoró en
  /// recibir el último cambio, dándole al usuario un "refresh" manual
  /// que se siente instantáneo en vez de esperar al socket.
  Future<void> _refrescar() async {
    setState(() {
      _stream = PedidosService.streamPedidos();
    });
    // Pequeña espera para que el RefreshIndicator no desaparezca
    // antes de que el nuevo stream entregue su primer dato.
    await Future.delayed(const Duration(milliseconds: 600));
  }

  List<Pedido> _aplicarFiltros(List<Pedido> pedidos) {
    return pedidos.where((p) {
      if (_filtroDestino == FiltroDestino.lima && p.tipoEnvio != 'lima') return false;
      if (_filtroDestino == FiltroDestino.provincia && p.tipoEnvio != 'provincia') return false;

      if (_filtroPago == FiltroPago.pendiente && p.estadoPago != 'pendiente') return false;
      if (_filtroPago == FiltroPago.pagado && p.estadoPago != 'pagado') return false;
      if (_filtroPago == FiltroPago.noCobrado && p.estadoPago != 'no_cobrado') return false;
      if (_filtroPago == FiltroPago.cancelado && p.estadoPago != 'cancelado') return false;

      if (_busqueda.isNotEmpty) {
        final q = _busqueda.toLowerCase();
        if (!p.nombreCompleto.toLowerCase().contains(q) && !p.whatsapp.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.nombreTienda)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o WhatsApp...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _chipDestino('Todos', FiltroDestino.todos),
                _chipDestino('Lima', FiltroDestino.lima),
                _chipDestino('Provincia', FiltroDestino.provincia),
                const SizedBox(width: 10),
                _chipPago('Pend. pago', FiltroPago.pendiente),
                _chipPago('Pagado', FiltroPago.pagado),
                _chipPago('No cobrado', FiltroPago.noCobrado),
                _chipPago('Cancelado', FiltroPago.cancelado),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refrescar,
              child: StreamBuilder<List<Pedido>>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final pedidos = _aplicarFiltros(snapshot.data ?? []);
                  if (pedidos.isEmpty) {
                    return ListView(
                      // Lista vacía pero scrollable, necesaria para que
                      // RefreshIndicator funcione (si no, el gesto de
                      // deslizar hacia abajo no se detecta sin contenido).
                      children: const [
                        SizedBox(height: 140),
                        Center(
                          child: Text(
                            'No hay pedidos con estos filtros',
                            style: TextStyle(color: AppTheme.textoSecundario),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 20, top: 4),
                    itemCount: pedidos.length,
                    itemBuilder: (context, i) {
                      final pedido = pedidos[i];
                      return PedidoCard(
                        pedido: pedido,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PedidoDetalleScreen(pedido: pedido)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipDestino(String texto, FiltroDestino valor) {
    final seleccionado = _filtroDestino == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(texto),
        selected: seleccionado,
        onSelected: (_) => setState(() => _filtroDestino = valor),
        selectedColor: AppTheme.primario,
        labelStyle: TextStyle(color: seleccionado ? Colors.white : AppTheme.primario, fontSize: 12.5),
      ),
    );
  }

  Widget _chipPago(String texto, FiltroPago valor) {
    final seleccionado = _filtroPago == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(texto),
        selected: seleccionado,
        onSelected: (_) => setState(
              () => _filtroPago = seleccionado && valor == _filtroPago ? FiltroPago.todos : valor,
        ),
        selectedColor: AppTheme.acento,
        labelStyle: TextStyle(color: seleccionado ? Colors.white : AppTheme.primario, fontSize: 12.5),
      ),
    );
  }
}