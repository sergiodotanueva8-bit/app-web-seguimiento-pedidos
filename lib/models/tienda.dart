class Tienda {
  final String id;
  final String slug;
  final String nombre;
  final String producto;
  final String whatsapp;

  Tienda({
    required this.id,
    required this.slug,
    required this.nombre,
    required this.producto,
    required this.whatsapp,
  });

  factory Tienda.fromMap(Map<String, dynamic> map) {
    return Tienda(
      id: map['id'] as String,
      slug: map['slug'] as String,
      nombre: map['nombre'] as String,
      producto: map['producto'] as String,
      whatsapp: map['whatsapp'] as String,
    );
  }
}

class ResumenDashboard {
  final int pedidosPendientesPago;
  final double montoPendienteCobro;
  final int pedidosPagados;
  final double montoCobrado;
  final int pedidosCancelados;
  final int totalLima;
  final int totalProvincia;
  final int totalPedidos;

  ResumenDashboard({
    required this.pedidosPendientesPago,
    required this.montoPendienteCobro,
    required this.pedidosPagados,
    required this.montoCobrado,
    required this.pedidosCancelados,
    required this.totalLima,
    required this.totalProvincia,
    required this.totalPedidos,
  });

  factory ResumenDashboard.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return ResumenDashboard(
        pedidosPendientesPago: 0,
        montoPendienteCobro: 0,
        pedidosPagados: 0,
        montoCobrado: 0,
        pedidosCancelados: 0,
        totalLima: 0,
        totalProvincia: 0,
        totalPedidos: 0,
      );
    }
    return ResumenDashboard(
      pedidosPendientesPago: (map['pedidos_pendientes_pago'] as num?)?.toInt() ?? 0,
      montoPendienteCobro: (map['monto_pendiente_cobro'] as num?)?.toDouble() ?? 0,
      pedidosPagados: (map['pedidos_pagados'] as num?)?.toInt() ?? 0,
      montoCobrado: (map['monto_cobrado'] as num?)?.toDouble() ?? 0,
      pedidosCancelados: (map['pedidos_cancelados'] as num?)?.toInt() ?? 0,
      totalLima: (map['total_lima'] as num?)?.toInt() ?? 0,
      totalProvincia: (map['total_provincia'] as num?)?.toInt() ?? 0,
      totalPedidos: (map['total_pedidos'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Resumen de ventas para un rango de fechas (semana, quincena, mes
/// o un rango personalizado elegido por el usuario en el dashboard).
class VentasPeriodo {
  final int totalPedidos;
  final int pedidosPagados;
  final int pedidosPendientes;
  final int pedidosNoCobrados;
  final int pedidosCancelados;
  final double montoVendido;
  final double montoCobrado;
  final double montoPendiente;

  VentasPeriodo({
    required this.totalPedidos,
    required this.pedidosPagados,
    required this.pedidosPendientes,
    required this.pedidosNoCobrados,
    required this.pedidosCancelados,
    required this.montoVendido,
    required this.montoCobrado,
    required this.montoPendiente,
  });

  factory VentasPeriodo.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return VentasPeriodo(
        totalPedidos: 0,
        pedidosPagados: 0,
        pedidosPendientes: 0,
        pedidosNoCobrados: 0,
        pedidosCancelados: 0,
        montoVendido: 0,
        montoCobrado: 0,
        montoPendiente: 0,
      );
    }
    return VentasPeriodo(
      totalPedidos: (map['total_pedidos'] as num?)?.toInt() ?? 0,
      pedidosPagados: (map['pedidos_pagados'] as num?)?.toInt() ?? 0,
      pedidosPendientes: (map['pedidos_pendientes'] as num?)?.toInt() ?? 0,
      pedidosNoCobrados: (map['pedidos_no_cobrados'] as num?)?.toInt() ?? 0,
      pedidosCancelados: (map['pedidos_cancelados'] as num?)?.toInt() ?? 0,
      montoVendido: (map['monto_vendido'] as num?)?.toDouble() ?? 0,
      montoCobrado: (map['monto_cobrado'] as num?)?.toDouble() ?? 0,
      montoPendiente: (map['monto_pendiente'] as num?)?.toDouble() ?? 0,
    );
  }
}