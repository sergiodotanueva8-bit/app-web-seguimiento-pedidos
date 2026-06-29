class Pedido {
  final String id;
  final DateTime creadoEn;
  final String tiendaId;
  final String tipoEnvio; // 'lima' | 'provincia'

  final String nombreCompleto;
  final String whatsapp;
  final String? dni;

  // Lima
  final String? distrito;
  final String? direccionExacta;
  final bool agregaInstalacion;

  // Provincia
  final String? departamento;
  final String? ciudadDestino;
  final String? sedeShalom;

  final int cantidad;
  final double precioUnitario;
  final double costoInstalacion;
  final double totalPagar;

  final String estadoPago;
  final String estadoEnvio;

  final String? mensajeWhatsappCorto;
  final String? mensajePedidoCompleto;
  final String? notasInternas;

  // Seguimiento automático Shalom (solo aplica a tipoEnvio == 'provincia')
  final String? shalomNumeroOrden;
  final String? shalomCodigoOrden;
  final String? shalomOseId;          // ← ID interno de Shalom (obtenido al activar guía)
  final String? shalomUltimoEstado;
  final DateTime? shalomUltimaVerificacion;
  final bool shalomTrackingActivo;
  final String? shalomOrigen;
  final String? shalomDestino;

  // Soft delete: null = activo, non-null = eliminado (restaurable)
  final DateTime? eliminadoEn;

  Pedido({
    required this.id,
    required this.creadoEn,
    required this.tiendaId,
    required this.tipoEnvio,
    required this.nombreCompleto,
    required this.whatsapp,
    this.dni,
    this.distrito,
    this.direccionExacta,
    this.agregaInstalacion = false,
    this.departamento,
    this.ciudadDestino,
    this.sedeShalom,
    required this.cantidad,
    required this.precioUnitario,
    required this.costoInstalacion,
    required this.totalPagar,
    required this.estadoPago,
    required this.estadoEnvio,
    this.mensajeWhatsappCorto,
    this.mensajePedidoCompleto,
    this.notasInternas,
    this.shalomNumeroOrden,
    this.shalomCodigoOrden,
    this.shalomOseId,
    this.shalomUltimoEstado,
    this.shalomUltimaVerificacion,
    this.shalomTrackingActivo = true,
    this.shalomOrigen,
    this.shalomDestino,
    this.eliminadoEn,
  });

  factory Pedido.fromMap(Map<String, dynamic> map) {
    return Pedido(
      id: map['id'] as String,
      creadoEn: DateTime.parse(map['creado_en'] as String).toLocal(),
      tiendaId: map['tienda_id'] as String,
      tipoEnvio: map['tipo_envio'] as String,
      nombreCompleto: map['nombre_completo'] as String,
      whatsapp: map['whatsapp'] as String,
      dni: map['dni'] as String?,
      distrito: map['distrito'] as String?,
      direccionExacta: map['direccion_exacta'] as String?,
      agregaInstalacion: map['agrega_instalacion'] as bool? ?? false,
      departamento: map['departamento'] as String?,
      ciudadDestino: map['ciudad_destino'] as String?,
      sedeShalom: map['sede_shalom'] as String?,
      cantidad: (map['cantidad'] as num?)?.toInt() ?? 1,
      precioUnitario: (map['precio_unitario'] as num?)?.toDouble() ?? 0,
      costoInstalacion: (map['costo_instalacion'] as num?)?.toDouble() ?? 0,
      totalPagar: (map['total_pagar'] as num?)?.toDouble() ?? 0,
      estadoPago: map['estado_pago'] as String? ?? 'pendiente',
      estadoEnvio: map['estado_envio'] as String? ?? 'nuevo',
      mensajeWhatsappCorto: map['mensaje_whatsapp_corto'] as String?,
      mensajePedidoCompleto: map['mensaje_pedido_completo'] as String?,
      notasInternas: map['notas_internas'] as String?,
      shalomNumeroOrden: map['shalom_numero_orden'] as String?,
      shalomCodigoOrden: map['shalom_codigo_orden'] as String?,
      shalomOseId: map['shalom_ose_id'] as String?,
      shalomUltimoEstado: map['shalom_ultimo_estado'] as String?,
      shalomUltimaVerificacion: map['shalom_ultima_verificacion'] != null
          ? DateTime.parse(map['shalom_ultima_verificacion'] as String).toLocal()
          : null,
      shalomTrackingActivo: map['shalom_tracking_activo'] as bool? ?? true,
      shalomOrigen: map['shalom_origen'] as String?,
      shalomDestino: map['shalom_destino'] as String?,
      eliminadoEn: map['eliminado_en'] != null
          ? DateTime.parse(map['eliminado_en'] as String).toLocal()
          : null,
    );
  }

  bool get estaEliminado => eliminadoEn != null;

  String get whatsappLimpio {
    final soloDigitos = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    if (soloDigitos.length <= 9) return '51$soloDigitos';
    return soloDigitos;
  }

  String get etiquetaDestino => tipoEnvio == 'lima' ? 'Lima' : 'Provincia';

  bool get tieneGuiaShalom =>
      tipoEnvio == 'provincia' &&
          (shalomNumeroOrden?.isNotEmpty ?? false) &&
          (shalomCodigoOrden?.isNotEmpty ?? false);
}
