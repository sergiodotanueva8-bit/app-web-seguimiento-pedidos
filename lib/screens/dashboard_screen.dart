import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/pedido.dart';
import '../models/tienda.dart';
import '../services/pedidos_service.dart';
import 'pedido_detalle_screen.dart';

enum _Periodo { semana, quincena, mes, personalizado }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<ResumenDashboard> _futuroResumen;
  late Future<VentasPeriodo> _futuroVentas;

  _Periodo _periodo = _Periodo.semana;
  DateTimeRange? _rangoPersonalizado;
  bool _mostrarEliminados = false;

  @override
  void initState() {
    super.initState();
    _futuroResumen = PedidosService.obtenerResumen();
    _futuroVentas = _cargarVentasDelPeriodo();
  }

  (DateTime, DateTime) _rangoDe(_Periodo periodo) {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final manana = hoy.add(const Duration(days: 1));
    switch (periodo) {
      case _Periodo.semana:
        final desde = hoy.subtract(Duration(days: hoy.weekday - 1));
        return (desde, manana);
      case _Periodo.quincena:
        final desde = ahora.day <= 15
            ? DateTime(ahora.year, ahora.month, 1)
            : DateTime(ahora.year, ahora.month, 16);
        return (desde, manana);
      case _Periodo.mes:
        final desde = DateTime(ahora.year, ahora.month, 1);
        return (desde, manana);
      case _Periodo.personalizado:
        if (_rangoPersonalizado == null) return (hoy, manana);
        final desde = DateTime(_rangoPersonalizado!.start.year,
            _rangoPersonalizado!.start.month, _rangoPersonalizado!.start.day);
        final hasta = DateTime(_rangoPersonalizado!.end.year,
                _rangoPersonalizado!.end.month, _rangoPersonalizado!.end.day)
            .add(const Duration(days: 1));
        return (desde, hasta);
    }
  }

  Future<VentasPeriodo> _cargarVentasDelPeriodo() {
    final (desde, hasta) = _rangoDe(_periodo);
    return PedidosService.obtenerResumenVentas(desde: desde, hasta: hasta);
  }

  Future<void> _elegirPeriodo(_Periodo periodo) async {
    if (periodo == _Periodo.personalizado) {
      final ahora = DateTime.now();
      final rango = await showDateRangePicker(
        context: context,
        firstDate: DateTime(ahora.year - 2),
        lastDate: ahora,
        initialDateRange: _rangoPersonalizado ??
            DateTimeRange(
                start: ahora.subtract(const Duration(days: 7)), end: ahora),
        locale: const Locale('es', 'PE'),
      );
      if (rango == null) return;
      setState(() {
        _rangoPersonalizado = rango;
        _periodo = periodo;
        _futuroVentas = _cargarVentasDelPeriodo();
      });
      return;
    }
    setState(() {
      _periodo = periodo;
      _futuroVentas = _cargarVentasDelPeriodo();
    });
  }

  Future<void> _recargar() async {
    setState(() {
      _futuroResumen = PedidosService.obtenerResumen();
      _futuroVentas = _cargarVentasDelPeriodo();
    });
  }

  Future<void> _restaurarPedido(Pedido pedido) async {
    try {
      await PedidosService.restaurarPedido(pedido.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pedido de ${pedido.nombreCompleto} restaurado ✓'),
            action: SnackBarAction(
              label: 'Ver',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PedidoDetalleScreen(pedido: pedido),
                  ),
                );
              },
            ),
          ),
        );
        setState(() {}); // Fuerza re-render del StreamBuilder de eliminados
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('No se pudo restaurar: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatoMoneda = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final formatoFecha = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: _recargar,
        child: FutureBuilder<ResumenDashboard>(
          future: _futuroResumen,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final r = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ---- Métricas principales ----
                Row(
                  children: [
                    Expanded(
                      child: _tarjetaMetrica(
                        'Por cobrar',
                        formatoMoneda.format(r.montoPendienteCobro),
                        '${r.pedidosPendientesPago} pedidos',
                        AppTheme.advertencia,
                        Icons.hourglass_bottom,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _tarjetaMetrica(
                        'Cobrado',
                        formatoMoneda.format(r.montoCobrado),
                        '${r.pedidosPagados} pedidos',
                        AppTheme.exito,
                        Icons.check_circle_outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _tarjetaMetrica(
                        'Cancelados',
                        '${r.pedidosCancelados}',
                        'no suman a tus ventas',
                        AppTheme.peligro,
                        Icons.cancel_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _tarjetaMetrica(
                        'Total pedidos',
                        '${r.totalPedidos}',
                        'histórico completo',
                        AppTheme.primario,
                        Icons.list_alt,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ---- Ventas por periodo ----
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ventas por periodo',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _chipPeriodo('Semana', _Periodo.semana),
                            _chipPeriodo('Quincena', _Periodo.quincena),
                            _chipPeriodo('Mes', _Periodo.mes),
                            _chipPeriodo('Personalizado', _Periodo.personalizado),
                          ],
                        ),
                        if (_periodo == _Periodo.personalizado &&
                            _rangoPersonalizado != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${formatoFecha.format(_rangoPersonalizado!.start)} '
                            '— ${formatoFecha.format(_rangoPersonalizado!.end)}',
                            style: const TextStyle(
                                color: AppTheme.textoSecundario, fontSize: 12.5),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FutureBuilder<VentasPeriodo>(
                          future: _futuroVentas,
                          builder: (context, snapVentas) {
                            if (snapVentas.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            if (snapVentas.hasError) {
                              return Text('Error: ${snapVentas.error}');
                            }
                            final v = snapVentas.data!;
                            return Column(
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: _filaVentaDato(
                                        'Vendido (no cancelado)',
                                        formatoMoneda.format(v.montoVendido)),
                                  ),
                                ]),
                                const Divider(height: 22),
                                Row(children: [
                                  Expanded(child: _miniDato('Pedidos', '${v.totalPedidos}', AppTheme.primario)),
                                  Expanded(child: _miniDato('Pagados', '${v.pedidosPagados}', AppTheme.exito)),
                                  Expanded(child: _miniDato('Pendientes', '${v.pedidosPendientes}', AppTheme.advertencia)),
                                  Expanded(child: _miniDato('Cancelados', '${v.pedidosCancelados}', AppTheme.peligro)),
                                ]),
                                const SizedBox(height: 10),
                                Row(children: [
                                  Expanded(child: _filaVentaDato('Cobrado', formatoMoneda.format(v.montoCobrado))),
                                  Expanded(child: _filaVentaDato('Por cobrar', formatoMoneda.format(v.montoPendiente))),
                                ]),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ---- Lima vs Provincia ----
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Lima vs Provincia',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 180,
                          child: r.totalPedidos == 0
                              ? const Center(
                                  child: Text('Aún no hay pedidos',
                                      style: TextStyle(color: AppTheme.textoSecundario)))
                              : PieChart(
                                  PieChartData(
                                    sectionsSpace: 3,
                                    centerSpaceRadius: 36,
                                    sections: [
                                      PieChartSectionData(
                                        value: r.totalLima.toDouble(),
                                        title: '${r.totalLima}',
                                        color: AppTheme.primario,
                                        radius: 50,
                                        titleStyle: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      PieChartSectionData(
                                        value: r.totalProvincia.toDouble(),
                                        title: '${r.totalProvincia}',
                                        color: AppTheme.acento,
                                        radius: 50,
                                        titleStyle: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _leyenda(AppTheme.primario, 'Lima'),
                            const SizedBox(width: 20),
                            _leyenda(AppTheme.acento, 'Provincia'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ---- Cobranza ----
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Estado de cobranza',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 160,
                          child: BarChart(
                            BarChartData(
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      const labels = ['Pendiente', 'Pagado'];
                                      final i = value.toInt();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                            i < labels.length ? labels[i] : '',
                                            style: const TextStyle(fontSize: 11)),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              barGroups: [
                                BarChartGroupData(x: 0, barRods: [
                                  BarChartRodData(
                                      toY: r.montoPendienteCobro,
                                      color: AppTheme.advertencia,
                                      width: 34,
                                      borderRadius: BorderRadius.circular(6)),
                                ]),
                                BarChartGroupData(x: 1, barRods: [
                                  BarChartRodData(
                                      toY: r.montoCobrado,
                                      color: AppTheme.exito,
                                      width: 34,
                                      borderRadius: BorderRadius.circular(6)),
                                ]),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ---- Pedidos eliminados (restaurar) ----
                StreamBuilder<List<Pedido>>(
                  stream: PedidosService.streamPedidosEliminados(),
                  builder: (context, snap) {
                    final eliminados = snap.data ?? [];
                    if (eliminados.isEmpty) return const SizedBox.shrink();

                    return Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () =>
                                  setState(() => _mostrarEliminados = !_mostrarEliminados),
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline,
                                      color: AppTheme.peligro, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pedidos eliminados (${eliminados.length})',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.peligro),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    _mostrarEliminados
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: AppTheme.peligro,
                                  ),
                                ],
                              ),
                            ),
                            if (_mostrarEliminados) ...[
                              const SizedBox(height: 10),
                              const Text(
                                'Toca "Restaurar" para devolver un pedido a la lista activa.',
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.textoSecundario),
                              ),
                              const SizedBox(height: 8),
                              ...eliminados.map((p) => _filaEliminado(p, formatoFecha)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _filaEliminado(Pedido pedido, DateFormat formatoFecha) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pedido.nombreCompleto,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                  'Eliminado el ${formatoFecha.format(pedido.eliminadoEn!)}',
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textoSecundario),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _restaurarPedido(pedido),
            icon: const Icon(Icons.restore, size: 16),
            label: const Text('Restaurar'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.exito),
          ),
        ],
      ),
    );
  }

  Widget _chipPeriodo(String texto, _Periodo valor) {
    final seleccionado = _periodo == valor;
    return ChoiceChip(
      label: Text(texto),
      selected: seleccionado,
      onSelected: (_) => _elegirPeriodo(valor),
      selectedColor: AppTheme.primario,
      labelStyle: TextStyle(
          color: seleccionado ? Colors.white : AppTheme.primario, fontSize: 12.5),
    );
  }

  Widget _filaVentaDato(String titulo, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(fontSize: 12, color: AppTheme.textoSecundario)),
        const SizedBox(height: 2),
        Text(valor,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _miniDato(String titulo, String valor, Color color) {
    return Column(
      children: [
        Text(valor,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(titulo,
            style: const TextStyle(
                fontSize: 10.5, color: AppTheme.textoSecundario),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _tarjetaMetrica(
      String titulo, String valor, String subtitulo, Color color, IconData icono) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: color, size: 20),
                const SizedBox(width: 6),
                Text(titulo,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppTheme.textoSecundario)),
              ],
            ),
            const SizedBox(height: 8),
            Text(valor,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(subtitulo,
                style: const TextStyle(
                    fontSize: 11.5, color: AppTheme.textoSecundario)),
          ],
        ),
      ),
    );
  }

  Widget _leyenda(Color color, String texto) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(fontSize: 12.5)),
      ],
    );
  }
}
