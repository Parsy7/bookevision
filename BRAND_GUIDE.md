# bookevision — Guía de Marca (Flutter · piel «Galerada»)

---

## ⚠️ Reglas de uso — Lectura obligatoria

Esta guía es **la única fuente de verdad** para cualquier decisión de diseño en bookevision.
Sigue la misma filosofía que la guía de Anotto: tokens para todo, cero valores a mano, un solo
widget por componente.

> **Qué está aquí y qué no.** Aquí van los **criterios**: qué token existe, qué valor tiene y
> cuándo usarlo. El **código** (tokens y widgets) vive en `lib/galerada/theme/` y
> `lib/galerada/widgets/`, y esta guía no lo duplica: una copia del Dart aquí se pudre en silencio
> en cuanto alguien toca el original. La API de cada widget se documenta con `///` (dartdoc) sobre
> la clase y sobre cada parámetro, en su propio archivo.

> El nombre de la app es **bookevision**, siempre en minúsculas (en mono sale en mayúsculas porque
> `GMono` las pone él, no porque se escriba así).

### Mobile first — PRIORITARIO
La app se usa desde el móvil:
- Diseño base pensado para anchos ~360-430 logical pixels (dp).
- Lo que pueda estirarse en tablet lleva tope de ancho (p. ej. el panel de la IA,
  `GSpacing.aiPanelMax`).
- Área táctil mínima y tamaño mínimo de texto interactivo: **pendiente de decisión** (ver
  «Pendiente»). Mientras tanto, los elementos nuevos que se toquen deben tener al menos 44dp de
  área táctil.

### Normas estrictas

1. **Ninguna pantalla, componente o modificación puede saltarse esta guía.** Todo widget nuevo
   deriva sus valores de los tokens (`GColors`, `GText`, `GSpacing`), sin excepción.
2. **Prohibido hardcodear valores.** Ningún número literal con implicación visual se escribe
   directamente en un widget:
   - Colores → `GColors` (nunca `Color(0x...)` ni `Colors.*` salvo `Colors.transparent`). Única
     excepción: el degradado de la IA, que vive en `GAiColors` (ver «Excepción: la IA»).
   - **Texto → siempre un estilo de `GText`.** Nunca `fontSize:` suelto ni
     `copyWith(fontSize: …)`; si hace falta un tamaño que no existe, se sigue el «Proceso para
     añadir algo nuevo».
   - Espaciado, padding, alturas y grosores → `GSpacing`.

   Regla mnemotécnica: **si es un número y se ve en pantalla, tiene que venir de un token.**
3. **Sin sombras.** Nunca `BoxShadow`, ni `elevation` distinto de `0`. La única excepción es el
   halo de la IA (ver más abajo).
4. **Sin radios.** Galerada es una prueba de imprenta: todo es rectangular, radio 0. La única
   excepción es la IA (píldora, burbuja, nube de «pensando»).
5. **Siempre `Row`/`Column`/`Flex`.** No usar `Stack` salvo en los casos aprobados de la tabla
   «`Stack` permitido».
6. **Reutilización obligatoria.** Antes de crear un widget, comprueba la tabla «Widgets base».
7. **Un solo lugar por componente.** Cada widget base se define una vez y se importa donde haga
   falta. Nunca copiar y pegar su implementación (ni «una versión casi igual» privada en una
   pantalla).

### Proceso para añadir algo nuevo

Si hace falta un valor nuevo (color, estilo de texto, medida…):
1. No añadirlo directamente al código.
2. Notificarlo a la propietaria con la justificación.
3. Si se aprueba, añadirlo primero aquí y luego como token, y solo entonces usarlo.

---

## Colores

Papel y tinta: un fondo cálido de papel, tinta casi negra para texto, bordes y rellenos, y un
único acento. La profundidad no viene de sombras sino de bordes de tinta de 1px.

Código: `lib/galerada/theme/g_colors.dart`. **Los valores no están en el código**: salen del tema
que el autor elige en «Mi perfil», guardado en la tabla `temas` de la base de datos (añadir un tema
es un `INSERT`, sin tocar Dart). `GColors` expone siempre el tema activo. Los hex de abajo son los
del tema «Clásico», el de por defecto.

| Token | Clásico | Uso |
|---|---|---|
| `GColors.paper` | `#F3F0E8` | Fondo de página |
| `GColors.sheet` | `#FBFAF6` | Tarjetas, diálogos, menús, panel de la IA |
| `GColors.white` | `#FFFFFF` | Bloque de la propuesta, fondo del editor y de los campos |
| `GColors.ink` | `#141414` | Texto, **todos** los bordes, rellenos y estado activo |
| `GColors.red` | `#E4401C` | Acento del tema: CTA principal, pendiente, borrar, palabra clave |
| `GColors.blue` | `#2449D8` | «Escribir yo», borde del editor, cursor, citas de la IA |
| `GColors.grey1` | `#5E594F` | Cursivas: motivo de la sugerencia, subtítulos |
| `GColors.grey2` | `#6B665E` | Metadatos en mono, texto de contexto |
| `GColors.strike` | `#6D675D` | Texto tachado |
| `GColors.grey3` | `#8A847A` | Números de párrafo, deshabilitado, placeholders |
| `GColors.scrim` | tinta al 55% | Velo detrás de diálogos, hojas y el panel de la IA |
| `GColors.press` | tinta al 6% | Estado pulsado |
| `GColors.onInk` / `onRed` / `onBlue` | — | Texto sobre un relleno de ese color |

> `red` se llama así por herencia, pero es «el acento del tema»: en «Marino y dorado» es dorado.
> Úsalo por su papel (acento), no por su color.

---

## Tipografía

### Fuentes
Tres familias con papeles que **no se mezclan**:
- **Instrument Serif** — titulares: hero, barra superior, tarjetas, botones, números grandes.
- **Newsreader** — todo lo que se lee de corrido: prosa, bloques, motivos, chat, menús.
- **JetBrains Mono** (en mayúsculas) — etiquetas, metadatos, estados y sellos.

Vía `google_fonts`. Los estilos van **cerrados** (`inherit: false`): así un `Text` y un
`TextField` con el mismo estilo miden igual, que es lo que permite que la prosa se vuelva editable
sin recomponerse bajo el dedo.

### Estilos

Galerada no tiene una escala numérica suelta como Anotto: cada estilo es un **papel**. Usa siempre
el estilo entero (`GText.rowTitle`); si necesitas otro color, `copyWith(color: GColors.…)`, nunca
otro tamaño.

Código: `lib/galerada/theme/g_text.dart`

| Estilo | Fuente | Tamaño | Uso |
|---|---|---|---|
| `GText.hero` | Instrument Serif | 64 | Titular de una portada (libro, capítulo) |
| `GText.heroSm` | Instrument Serif | 48 | Titular de «Mis libros» |
| `GText.cardTitle` / `cardTitleEm` | Instrument Serif | 28 | Título de tarjeta / su palabra clave en rojo cursiva |
| `GText.appBar` | Instrument Serif | 26 | Título de la barra superior |
| `GText.footButton` | Instrument Serif | 22 | CTA de la barra inferior |
| `GText.rowTitle` | Instrument Serif | 22 | Título de una fila de portada |
| `GText.chatTitle` | Instrument Serif | 21 | Títulos dentro de una respuesta de la IA |
| `GText.button` | Instrument Serif | 20 | Botones de pantalla y FAB |
| `GText.bigNumber` | Instrument Serif | 40 | Número de capítulo/fila y recuentos |
| `GText.statLabel` | Instrument Serif | 18 | Etiqueta de un recuento |
| `GText.prose` | Newsreader | 17 | Prosa del capítulo |
| `GText.block` | Newsreader | 16 | Bloques dentro de una tarjeta |
| `GText.heroSub` | Newsreader cursiva | 16 | Subtítulo del hero |
| `GText.menu` | Newsreader | 16 | Filas de menú y de hoja de opciones |
| `GText.context` | Newsreader | 15 | Contexto de una inserción, «Sobre: …» de la IA |
| `GText.dialog` | Newsreader | 15 | Cuerpo de un diálogo |
| `GText.chat` | Newsreader | 14,5 | Mensajes del chat con la IA |
| `GText.action` | Newsreader 500 | 14 | Rótulo de la rejilla de acciones |
| `GText.reason` | Newsreader cursiva | 14 | Motivo de la sugerencia, textos de apoyo |
| `GText.statNote` | Newsreader cursiva | 13 | Explicación de un recuento |
| `GText.field` | JetBrains Mono | 13 | Campos de texto (JSON, chat) |
| `GText.mono` | JetBrains Mono 600 | 10,5 | Etiquetas, metadatos, estados (vía `GMono`) |
| `GText.monoSm` | JetBrains Mono 600 | 10 | Teclas de acción, sellos de estado |
| `GText.paragraphNo` | JetBrains Mono | 10 | Número de párrafo en el margen |

> La mono pequeña (10–10,5) es la firma de Galerada para lo que **se lee**: sellos, metadatos,
> cabeceras de tarjeta. Si se usa en algo que **se toca** depende de la decisión pendiente sobre
> tamaños táctiles.

---

## Espaciado

Código: `lib/galerada/theme/g_spacing.dart` (cada token lleva su dartdoc). Los principales:

| Token | Valor (dp) | Uso |
|---|---|---|
| `GSpacing.page` | 18 | Padding de página y laterales de la barra superior |
| `GSpacing.gap` | 16 | Hueco entre bloques del cuerpo |
| `GSpacing.card` | 14 | Padding interior de tarjetas |
| `GSpacing.blockV` | 12 | Padding vertical de bloques dentro de una tarjeta |
| `GSpacing.barTop` / `barBottom` | 10 / 14 | Barras |
| `GSpacing.gapSm` / `gapXs` | 8 / 4 | Huecos pequeños |
| `GSpacing.heroTop` | 22 | Aire sobre la marca en el hero |
| `GSpacing.rowNumber` | 44 | Columna del número en las filas |
| `GSpacing.chipH` / `chipV` / `chipGap` | 7 / 5 / 6 | Chips |
| `GSpacing.proseIndent` | 30 | Sangrado de la prosa (número de párrafo) |
| `GSpacing.stripe` | 3 | Franja de un bloque editado y de las citas de la IA |
| `GSpacing.border` | 1 | **Todos** los bordes |
| `GSpacing.caret` / `caretGutter` | 2 / 3 | Cursor y el hueco que reserva |

Alturas fijas: `iconBtn` 40, `actionBtn` 52, `fab` 56, `foot` 64. Medidas del asistente de IA: la
sección «Asistente de IA» de `g_spacing.dart` (`aiEdge`, `aiPanelMax`, `aiBubble`, `aiPill`…).

---

## Bordes y radios

```dart
Border.all(color: GColors.ink, width: GSpacing.border)
```

> ⚠️ **Sin sombras y sin radios.** Las superficies se distinguen por su borde de tinta y su fondo,
> nunca por `elevation`, `boxShadow` ni esquinas redondeadas.

---

## Excepción: la IA

Todo lo que es «la IA» se pinta aparte del papel impreso, **a propósito** (decisión pedida
expresamente por la propietaria), para que se lea como un elemento que no es parte del texto:

- **Degradado** índigo → fucsia → rosa: `GAiColors` (`lib/galerada/widgets/g_ai_visuals.dart`).
  Es el único sitio con colores fuera de `GColors`.
- **Halo difuminado** (`GAiGlow`): la **única sombra** permitida en la app.
- **Formas redondeadas**: píldora «Preguntar a la IA», burbuja, nube de «pensando».

La excepción vale **solo** para los widgets de IA (`g_ai_visuals.dart`, `g_ai_assistant_overlay.dart`).
El panel del chat en sí sigue siendo Galerada: rectangular, borde de tinta, sin sombra.

---

## `Stack` permitido

| Dónde | Por qué |
|---|---|
| Número de párrafo en el margen (`GProse`, `GProseBlock`) | Va fuera de la caja del texto, en el sangrado |
| Botón flotante sobre una lista (`GPantallaLista`) | Flota sobre el scroll |
| Asistente de IA y botón «Preguntar a la IA» (`GAiConAsistente`) | Flotan sobre toda la pantalla |
| Punto de «respuesta nueva» sobre la burbuja | Badge superpuesto |
| Icono de copiar en una respuesta de la IA | Esquina de la burbuja |

---

## Widgets base

Antes de crear un widget nuevo, comprueba si ya existe. La API está en su dartdoc; esta tabla solo
dice **cuál buscar**.

| Necesitas | Widget | Archivo |
|---|---|---|
| Etiqueta en mono (normal, apagada, roja) | `GMono` | `g_bits.dart` |
| Sello de estado (Listo, En curso…) | `GStamp` | `g_bits.dart` |
| Medidor de progreso de una fila / de un recuento | `GMeter` / `GTicks` | `g_bits.dart` |
| Chip de acción (Ver original, Reintentar…) | `GChip` | `g_bits.dart` |
| Raya de tinta | `GRule` | `g_bits.dart` |
| Botón de pantalla / de icono / flotante | `GButton` / `GIconButton` / `GFab` | `g_button.dart` |
| Rejilla de acciones con tecla | `GActions` + `GAction` | `g_actions.dart` |
| Tarjeta y sus partes | `GCard`, `GCardTop`, `GCardTitle`, `GBlock`, `GSegmented`, `GWarn` | `g_card.dart` |
| Barra superior | `GAppBar` | `g_app_bar.dart` |
| Barra inferior (CTA, navegación, partida) | `GFoot` | `g_foot.dart` |
| Campo de texto con etiqueta | `GField` | `g_field.dart` |
| Confirmación destructiva | `GDialog.confirmar` | `g_dialog.dart` |
| Menú ⋯ / hoja de opciones al mantener pulsado | `GMenu` / `GMenu.hoja` | `g_dialog.dart` |
| Portada con lista (hero, filas, vacía, error, FAB) | `GPantallaLista`, `GHero`, `GFila`, `GListaVacia` | `g_lista.dart` |
| Prosa de lectura / editable | `GProseFlow` / `GProseBlock` | `g_prose.dart` |
| Tarjeta de sugerencia | `GSuggestionCard` | `g_suggestion_card.dart` |
| Asistente de IA en una pantalla | `GAiConAsistente` (mixin) | `g_ai_assistant_overlay.dart` |
| Respuesta de la IA en Markdown | `GAiMarkdown` | `g_ai_markdown.dart` |

**Hojas desde abajo:** `GMenu.hoja` — fondo `sheet`, borde superior de tinta, velo `scrim`, sin
radio.

---

## ThemeData global

`lib/galerada/theme/g_theme.dart` define `buildGaleradaTheme()`, para que los widgets nativos
(`Scaffold`, diálogos, menús, `SnackBar`…) hereden la paleta sin envolverlo todo. Se reconstruye al
cambiar de tema.

---

## Pendiente

- [ ] **Tamaños táctiles.** Decidir si se aplica la regla de Anotto (44dp de área táctil y nada
      de texto interactivo por debajo de 14px) a chips, selector Antes/Entre/Después, enlaces
      «Volver»/«Mi perfil», copiar de la IA, rótulo de «Preguntar a la IA» y botones de icono.
- [ ] **Token de iconos** (`GIcon`, como el `AppIcon` de Anotto). Hoy los tamaños de icono van a
      mano (20 en botones y menús, 16 el sparkle, 11 copiar).
- [ ] **Literales heredados** que aún no salen de un token: alto mínimo del editor de «Escribir
      yo» (90), icono y hueco de `GButton`/`GFab` (20, 10), padding del FAB (20), ancho del
      `GMenu` (230), `insetPadding` de `GDialog` (28).
- [x] Paleta en base de datos con temas elegibles
- [x] Excepción de la IA documentada
