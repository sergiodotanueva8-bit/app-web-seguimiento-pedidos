/// Define los flujos de estado de envío, diferenciados por tipo
/// (lima vs provincia), y los estados de pago (compartidos).
/// Si más adelante necesitas un estado nuevo, agrégalo aquí y
/// se refleja en toda la app automáticamente.
class EstadosPedido {
  EstadosPedido._();

  // ---------------- Estado de pago (independiente del envío) ----------------
  // 'cancelado' está disponible en pago Y en envío. Al elegir 'cancelado'
  // en cualquiera de los dos, Supabase sincroniza el otro campo
  // automáticamente (ver trigger trg_sincronizar_cancelado).
  static const List<String> estadosPago = ['pendiente', 'pagado', 'no_cobrado', 'cancelado'];

  static String labelEstadoPago(String estado) {
    switch (estado) {
      case 'pagado':
        return 'Pagado';
      case 'no_cobrado':
        return 'No cobrado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return 'Pendiente de pago';
    }
  }

  // ---------------- Estado de envío: Lima (3 pasos + cancelado) ----------------
  static const List<String> flujoLima = ['nuevo', 'en_camino', 'entregado', 'cancelado'];

  // ---------------- Estado de envío: Provincia (4 pasos + cancelado) ----------------
  static const List<String> flujoProvincia = ['nuevo', 'en_origen', 'en_transito', 'en_destino', 'cancelado'];

  /// Devuelve el flujo de estados válido según el tipo de envío.
  /// 'archivado' siempre se puede aplicar manualmente pero no aparece
  /// en el flujo normal de selección rápida.
  static List<String> flujoSegunTipo(String tipoEnvio) {
    return tipoEnvio == 'lima' ? flujoLima : flujoProvincia;
  }

  static String labelEstadoEnvio(String estado) {
    switch (estado) {
      case 'nuevo':
        return 'Aún no despachado';
      case 'en_camino':
        return 'En camino';
      case 'entregado':
        return 'Entregado';
      case 'en_origen':
        return 'En origen';
      case 'en_transito':
        return 'En tránsito';
      case 'en_destino':
        return 'Llegó a destino';
      case 'archivado':
        return 'Archivado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return estado;
    }
  }
}