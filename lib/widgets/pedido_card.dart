import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/estados_pedido.dart';
import '../core/theme.dart';
import '../models/pedido.dart';
import 'estado_badge.dart';

class PedidoCard extends StatelessWidget {
  final Pedido pedido;
  final VoidCallback onTap;

  const PedidoCard({super.key, required this.pedido, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final formatoMoneda = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final formatoFecha = DateFormat('dd/MM/yyyy hh:mm a');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pedido.nombreCompleto,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primario.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      pedido.etiquetaDestino,
                      style: const TextStyle(
                        color: AppTheme.primario,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                formatoFecha.format(pedido.creadoEn),
                style: const TextStyle(color: AppTheme.textoSecundario, fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    formatoMoneda.format(pedido.totalPagar),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Spacer(),
                  EstadoBadge(
                    texto: EstadosPedido.labelEstadoPago(pedido.estadoPago),
                    color: AppTheme.colorEstadoPago(pedido.estadoPago),
                  ),
                  const SizedBox(width: 6),
                  EstadoBadge(
                    texto: EstadosPedido.labelEstadoEnvio(pedido.estadoEnvio),
                    color: AppTheme.colorEstadoEnvio(pedido.estadoEnvio),
                  ),
                ],
              ),
              if (pedido.tieneGuiaShalom) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: EstadoBadge(
                    texto: '🚚 Shalom: ${pedido.shalomUltimoEstado != null ? EstadosPedido.labelEstadoEnvio(pedido.shalomUltimoEstado!) : 'verificando...'}',
                    color: AppTheme.colorEstadoEnvio(pedido.shalomUltimoEstado ?? 'nuevo'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}