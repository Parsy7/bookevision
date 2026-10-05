import 'package:flutter/material.dart';
import '../theme/g_colors.dart';
import '../theme/g_marca.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import 'g_bits.dart';
import 'g_button.dart';
import 'g_foot.dart';

/// Cabecera de una portada (Mis libros, un libro, un capítulo): marca en
/// mono, titular grande, subtítulo en cursiva y una raya de tinta debajo.
class GHero extends StatelessWidget {
  final String titulo;

  /// Segunda parte del titular, en cursiva y con el acento de texto (el
  /// juego de «Página en blanco», «Mis *libros*»).
  final String? tituloEm;
  final String subtitulo;

  /// Titular un punto más pequeño ([GText.heroSm]).
  final bool compacto;

  /// Con esto, el mismo botón de atrás de [GAppBar] a la izquierda.
  final VoidCallback? onVolver;

  final bool? logo;

  /// A la derecha: un enlace ([accion] + [onAccion]) o, si no, un dato en
  /// mono apagado ([meta]).
  final String? accion;
  final VoidCallback? onAccion;
  final String? meta;

  const GHero({
    super.key,
    required this.titulo,
    required this.subtitulo,
    this.tituloEm,
    this.compacto = false,
    this.onVolver,
    this.logo = true,
    this.accion,
    this.onAccion,
    this.meta,
  });

  @override
  Widget build(BuildContext context) {
    final estilo = compacto ? GText.heroSm : GText.hero;
    final onVolver = this.onVolver;
    final onAccion = this.onAccion;
    final meta = this.meta;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          GSpacing.page, GSpacing.heroTop, GSpacing.page, GSpacing.gap),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: GSpacing.gapSm,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (onVolver != null) ...[
                    GIconButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Volver',
                      outlined: true,
                      onPressed: onVolver,
                    ),
                    const SizedBox(width: GSpacing.gap),
                  ],
                  if (logo == true) ...[
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: GColors.ink, width: GSpacing.border),
                      ),
                      child: Image.asset(
                        GMarca.logo,
                        width: GSpacing.logoMarca,
                        height: GSpacing.logoMarca,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const SizedBox(width: GSpacing.gapSm),
                    const GMono('bookevision'),
                  ],
                ],
              ),
              if (accion != null && onAccion != null)
                _BotonAccion(label: accion!, onTap: onAccion)
              else if (meta != null)
                GMono.muted(meta),
            ],
          ),
          const SizedBox(height: GSpacing.barTop),
          Text.rich(
            TextSpan(
              style: estilo,
              children: [
                TextSpan(text: titulo),
                if (tituloEm != null)
                  TextSpan(
                      text: tituloEm,
                      style: estilo.copyWith(
                          color: GColors.accentText,
                          fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const SizedBox(height: GSpacing.gapSm),
          Text(subtitulo, style: GText.heroSub),
        ],
      ),
    );
  }
}

/// Enlace de la cabecera («Mi perfil»): mono en mayúsculas dentro de una
/// caja de tinta, a la altura del logo.
class _BotonAccion extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BotonAccion({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          height: GSpacing.iconBtn,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: GColors.ink, width: GSpacing.border),
          ),
          child: GMono(label),
        ),
      );
}

/// Fila de una portada: número grande (opcional) | título, metadatos en mono
/// y lo que vaya [debajo] (el medidor) | lo que vaya a la [derecha] (sello o
/// flecha). Con [onBorrar], deslizar a la izquierda pide borrarla.
class GFila extends StatelessWidget {
  /// Identifica la fila para el gesto de deslizar.
  final String id;
  final int? numero;
  final String titulo;
  final String meta;
  final Widget? debajo;
  final Widget? derecha;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onBorrar;

  const GFila({
    super.key,
    required this.id,
    required this.titulo,
    required this.meta,
    required this.onTap,
    this.numero,
    this.debajo,
    this.derecha,
    this.onLongPress,
    this.onBorrar,
  });

  @override
  Widget build(BuildContext context) {
    final debajo = this.debajo;
    final derecha = this.derecha;
    final fila = InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: GSpacing.page, vertical: GSpacing.gap),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: GColors.ink, width: GSpacing.border)),
        ),
        child: Row(
          crossAxisAlignment: numero == null
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            if (numero != null) ...[
              SizedBox(
                width: GSpacing.rowNumber,
                child: Text(numero.toString().padLeft(2, '0'),
                    style: GText.bigNumber),
              ),
              const SizedBox(width: GSpacing.blockV),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: GText.rowTitle),
                  const SizedBox(height: GSpacing.gapSm),
                  GMono.muted(meta),
                  if (debajo != null) ...[
                    const SizedBox(height: GSpacing.barTop),
                    debajo,
                  ],
                ],
              ),
            ),
            if (derecha != null) ...[
              const SizedBox(width: GSpacing.blockV),
              derecha,
            ],
          ],
        ),
      ),
    );

    final onBorrar = this.onBorrar;
    if (onBorrar == null) return fila;
    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onBorrar();
        return false; // el borrado lo confirma el diálogo, no el gesto
      },
      background: Container(
        color: GColors.danger,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: GSpacing.page),
        child: GMono('Borrar', color: GColors.onDanger),
      ),
      child: fila,
    );
  }
}

/// Portada con lista: espera a [future], y pinta el error, el estado vacío
/// ([vacia]) o la lista con su [hero] arriba, tirar para recargar y la barra
/// inferior con la acción principal, en el acento.
class GPantallaLista<T> extends StatelessWidget {
  final Future<List<T>> future;
  final Future<void> Function() onRefresh;
  final Widget Function(List<T> items) hero;
  final Widget Function(T item, int indice) fila;
  final Widget vacia;
  final String pieLabel;
  final IconData pieIcon;
  final VoidCallback onPie;

  const GPantallaLista({
    super.key,
    required this.future,
    required this.onRefresh,
    required this.hero,
    required this.fila,
    required this.vacia,
    required this.pieLabel,
    required this.pieIcon,
    required this.onPie,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<T>>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CircularProgressIndicator(color: GColors.ink));
            }
            if (snap.hasError)
              return _Error(error: snap.error!, onRetry: onRefresh);
            final items = snap.data ?? const [];
            if (items.isEmpty) return vacia;

            return Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    color: GColors.ink,
                    backgroundColor: GColors.sheet,
                    onRefresh: onRefresh,
                    child: ListView.builder(
                      itemCount: items.length + 1,
                      itemBuilder: (_, i) =>
                          i == 0 ? hero(items) : fila(items[i - 1], i - 1),
                    ),
                  ),
                ),
                // La barra reserva ella misma el hueco de la barra de
                // navegación del sistema.
                GFoot.unica(
                  label: pieLabel,
                  icon: pieIcon,
                  fill: GFootFill.red,
                  onTap: onPie,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Portada sin nada todavía: el [hero], una explicación y el botón para
/// empezar; [pie] opcional pegado abajo.
class GListaVacia extends StatelessWidget {
  final Widget hero;
  final String texto;
  final String boton;
  final VoidCallback onBoton;
  final Widget? pie;

  const GListaVacia({
    super.key,
    required this.hero,
    required this.texto,
    required this.boton,
    required this.onBoton,
    this.pie,
  });

  @override
  Widget build(BuildContext context) {
    final pie = this.pie;
    return Column(
      children: [
        hero,
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: GSpacing.page),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(texto, style: GText.prose),
                const SizedBox(height: GSpacing.page),
                GButton(
                    label: boton,
                    icon: Icons.add,
                    fill: GFill.ink,
                    onPressed: onBoton),
              ],
            ),
          ),
        ),
        if (pie != null) pie,
      ],
    );
  }
}

class _Error extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const _Error({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(GSpacing.page),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GMono.red('✕ No se pudo cargar'),
          const SizedBox(height: GSpacing.gapSm),
          Text('$error', style: GText.reason),
          const SizedBox(height: GSpacing.page),
          GButton(
              label: 'Reintentar', fill: GFill.ink, onPressed: () => onRetry()),
        ],
      ),
    );
  }
}
