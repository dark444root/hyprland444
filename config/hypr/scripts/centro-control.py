#!/usr/bin/env python3
"""
Centro de Control estilo iPhone para Hyprland.
  centro-control.py          -> panel principal
  centro-control.py wifi     -> directo a la lista de redes
  centro-control.py bt       -> directo a Bluetooth
  centro-control.py escritorio -> fijo en el escritorio como widget (abajo a la derecha)
Modo normal: pantalla oscurecida; tocar fuera del panel o Esc lo cierra.
"""
import gi, os, sys, math, subprocess, threading

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("PangoCairo", "1.0")
from gi.repository import Gtk, Gdk, GLib, Pango, PangoCairo
import cairo

try:
    gi.require_version("GtkLayerShell", "0.1")
    from gi.repository import GtkLayerShell
    CAPA = True
except Exception:
    CAPA = False

FA = "Font Awesome 6 Free, Font Awesome 5 Free, FontAwesome"
G = {"wifi": "", "bt": "", "avion": "", "luna": "", "sol": "",
     "vol": "", "vol0": "", "candado": "", "ok": "", "atras": "",
     "flecha": "", "musica": "", "ant": "", "play": "", "pausa": "",
     "sig": "", "audif": "", "teclado": "", "mouse": "", "cel": "",
     "buscar": "", "engrane": "", "power": "", "salir": "", "reiniciar": ""}

# Los comandos se ejecutan en inglés para leer bien sus respuestas (el sistema está en español)
ENV_C = dict(os.environ, LC_ALL="C.UTF-8", LANG="C.UTF-8")

def sh(cmd, t=12):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=t, env=ENV_C).stdout.strip()
    except Exception:
        return ""

def fondo(fn, listo=None):
    """Ejecuta fn en otro hilo y llama listo(resultado) en la interfaz."""
    def h():
        r = fn()
        if listo:
            GLib.idle_add(listo, r)
    threading.Thread(target=h, daemon=True).start()

def glifo(nombre, tam=18, color=None):
    c = f" foreground='{color}'" if color else ""
    return f"<span font_family='{FA}' font_weight='900' size='{tam * 1024}'{c}>{G[nombre]}</span>"

def avisar_widgets():
    sh("pkill -RTMIN+11 widgetbar; pkill -RTMIN+12 widgetbar")

# ------------------------------------------------------------------ estado del sistema
def wifi_on():  return sh("nmcli -t -f WIFI g") == "enabled"
def wifi_red(): return sh("nmcli -t -f IN-USE,SSID dev wifi list --rescan no | grep '^\\*:' | head -1 | cut -d: -f2-").replace("\\:", ":")
def bt_on():    return "Powered: yes" in sh("bluetoothctl show")
def bt_dev():
    c = sh("bluetoothctl devices Connected")
    return c.splitlines()[0].split(" ", 2)[2] if c else ""
def dnd_on():   return "do-not-disturb" in sh("makoctl mode", 2)
def brillo():
    m = sh("brightnessctl -m").split(",")
    try: return int(m[3].rstrip("%")) / 100
    except Exception: return 0.5
def volumen():
    v = sh("wpctl get-volume @DEFAULT_AUDIO_SINK@")
    try: return min(1.0, float(v.split()[1])), "MUTED" in v
    except Exception: return 0.5, False

def asegurar_modo_dnd():
    conf = os.path.expanduser("~/.config/mako/config")
    try:
        t = open(conf).read()
        if "[mode=do-not-disturb]" not in t:
            open(conf, "a").write("\n[mode=do-not-disturb]\ninvisible=1\n")
            sh("makoctl reload", 2)
    except Exception:
        pass

def mako_vivo():
    """Si el programa de notificaciones no responde, lo reinicia."""
    if subprocess.run("timeout 2 makoctl mode", shell=True, capture_output=True).returncode != 0:
        sh("pkill -x mako; sleep 0.3; setsid mako >/dev/null 2>&1 &", 4)
        sh("sleep 0.6", 2)

def cambiar_dnd(activar):
    asegurar_modo_dnd()
    mako_vivo()
    r = subprocess.run(f"timeout 2 makoctl mode {'-a' if activar else '-r'} do-not-disturb",
                       shell=True, capture_output=True)
    return r.returncode == 0

# ------------------------------------------------------------------ dibujos
class IconoWifi(Gtk.DrawingArea):
    """Abanico de Wi-Fi estilo iOS; se rellenan los arcos según la señal (0-3)."""
    def __init__(self, nivel=3, tam=26, color=(1, 1, 1)):
        super().__init__()
        self.nivel, self.color = nivel, color
        self.set_size_request(tam + 6, tam)
        self.connect("draw", self.dibujar)

    def dibujar(self, w, cr):
        a, h = w.get_allocated_width(), w.get_allocated_height()
        cx, cy = a / 2, h * 0.92
        R = min(a / 2, h) * 0.98
        for i in range(4):                      # 0 = punto, 1-3 = arcos
            r_ext = R * (i + 1) / 4
            r_int = 0 if i == 0 else r_ext - R * 0.17
            alfa = 1.0 if (self.nivel >= i) else 0.28
            cr.set_source_rgba(*self.color, alfa)
            cr.new_path()
            cr.arc(cx, cy, r_ext, math.radians(-135), math.radians(-45))
            if r_int > 0:
                cr.arc_negative(cx, cy, r_int, math.radians(-45), math.radians(-135))
            else:
                cr.line_to(cx, cy)
            cr.close_path()
            cr.fill()

class Deslizador(Gtk.DrawingArea):
    """Deslizador vertical grande estilo iPhone (brillo / volumen)."""
    def __init__(self, icono, valor, al_cambiar):
        super().__init__()
        self.icono, self.valor, self.al_cambiar = icono, valor, al_cambiar
        self.set_size_request(140, 300)
        self.add_events(Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK |
                        Gdk.EventMask.POINTER_MOTION_MASK | Gdk.EventMask.SCROLL_MASK)
        self.arrastrando = False
        self._pendiente = None
        self.radio, self.tam_icono = 36, 26
        self.connect("draw", self.dibujar)
        self.connect("button-press-event", self.pulsar)
        self.connect("button-release-event", lambda *a: setattr(self, "arrastrando", False) or True)
        self.connect("motion-notify-event", self.mover)
        self.connect("scroll-event", self.rueda)

    def fijar(self, v):
        self.valor = max(0.0, min(1.0, v))
        self.queue_draw()
        if self._pendiente:
            GLib.source_remove(self._pendiente)
        self._pendiente = GLib.timeout_add(40, self._aplicar)

    def _aplicar(self):
        self._pendiente = None
        fondo(lambda: self.al_cambiar(self.valor))
        return False

    def pulsar(self, w, e):
        self.arrastrando = True
        self.fijar(1 - e.y / self.get_allocated_height())
        return True

    def mover(self, w, e):
        if self.arrastrando:
            self.fijar(1 - e.y / self.get_allocated_height())
        return True

    def rueda(self, w, e):
        d = 0.05 if e.direction == Gdk.ScrollDirection.UP else -0.05 if e.direction == Gdk.ScrollDirection.DOWN else 0
        self.fijar(self.valor + d)
        return True

    def dibujar(self, w, cr):
        a, h = w.get_allocated_width(), w.get_allocated_height()
        r = self.radio
        cr.new_path()
        cr.arc(r, r, r, math.pi, 1.5 * math.pi); cr.arc(a - r, r, r, 1.5 * math.pi, 0)
        cr.arc(a - r, h - r, r, 0, 0.5 * math.pi); cr.arc(r, h - r, r, 0.5 * math.pi, math.pi)
        cr.close_path(); cr.clip()
        cr.set_source_rgba(1, 1, 1, 0.13); cr.paint()
        llenado = h * self.valor
        cr.set_source_rgba(1, 1, 1, 0.96); cr.rectangle(0, h - llenado, a, llenado); cr.fill()
        # icono abajo: oscuro si queda sobre la parte blanca
        capa = PangoCairo.create_layout(cr)
        capa.set_markup(f"<span font_family='{FA}' font_weight='900' size='{self.tam_icono * 1024}'>{G[self.icono]}</span>", -1)
        iw, ih = capa.get_pixel_size()
        y = h - int(self.radio * 0.95) - ih
        sobre_blanco = (h - llenado) < y + ih / 2
        cr.set_source_rgba(*(0.15, 0.15, 0.17) if sobre_blanco else (1, 1, 1), 1)
        cr.move_to((a - iw) / 2, y)
        PangoCairo.show_layout(cr, capa)

# ------------------------------------------------------------------ ventana
CSS = b"""
* { font-family: "Inter", "Cantarell", "Noto Sans", sans-serif; color: #f5f5f7; }
window.cc, window.escritorio { background-color: transparent; }
.tarjeta { background-color: rgba(28, 28, 32, 0.82); border-radius: 36px; }
.redondo, .pastilla, .plano, .boton-claro, entry { background-image: none; text-shadow: none; -gtk-icon-shadow: none; }
button, button:hover, button:active, button:focus, button:checked {
    outline: none; outline-width: 0; border: none; box-shadow: none; text-shadow: none;
    -gtk-outline-radius: 0; transition: none; }
*:focus { outline: none; outline-width: 0; }
.redondo { border: none;
           background: rgba(255, 255, 255, 0.13); box-shadow: none; padding: 0; }
.redondo:hover { background: rgba(255, 255, 255, 0.2); }
.redondo.activo { background: rgba(255, 255, 255, 0.92); }
.redondo.activo label { color: #141416; }
.pastilla { background-color: rgba(28, 28, 32, 0.82); border-radius: 36px; border: none;
            box-shadow: none; padding: 0 22px; }
.pastilla:hover, .pastilla:active { background-color: rgba(48, 48, 54, 0.9); }
.circulo { background: rgba(255, 255, 255, 0.13); }
.circulo.activo { background: rgba(255, 255, 255, 0.92); }
.circulo.activo label { color: #141416; }
.titulo { font-size: 17px; font-weight: 700; }
.sub { font-size: 14px; color: rgba(245, 245, 247, 0.6); }
.encabezado { font-size: 24px; font-weight: 800; }
.plano { background: none; border: none; box-shadow: none; padding: 6px 10px; border-radius: 14px; }
.plano:hover { background: rgba(255, 255, 255, 0.10); }
list, row { background: transparent; }
row.fila { padding: 12px 18px; border-radius: 18px; }
row.fila:hover { background: rgba(255, 255, 255, 0.08); }
.seccion { font-size: 13px; font-weight: 700; color: rgba(245, 245, 247, 0.5); margin: 14px 18px 4px 18px; }
entry { background: rgba(255, 255, 255, 0.10); border: none; border-radius: 12px; padding: 10px 14px;
        color: #f5f5f7; box-shadow: none; }
.boton-claro { background: rgba(255, 255, 255, 0.92); border-radius: 12px; border: none; box-shadow: none; }
.boton-claro label { color: #141416; font-weight: 700; }
switch { border-radius: 16px; background: rgba(255, 255, 255, 0.18); border: none; }
switch:checked { background: #e9e9ee; }
switch slider { border-radius: 14px; background: #ffffff; min-width: 26px; min-height: 26px; border: none; }
switch:checked slider { background: #141416; }
"""

class Centro(Gtk.Window):
    ANCHO = 620

    def __init__(self, vista, escritorio=False, posicion=None):
        super().__init__()
        self.escritorio = escritorio
        # Monitor (por su posición "x,y") y escala: compacto en pantallas chicas
        pantalla = Gdk.Display.get_default()
        mons = [pantalla.get_monitor(i) for i in range(pantalla.get_n_monitors())]
        self.monitor = None
        if posicion:
            px, py = (int(v) for v in posicion.split(","))
            self.monitor = next((m for m in mons if (m.get_geometry().x, m.get_geometry().y) == (px, py)), None)
        if self.monitor is None and mons:
            self.monitor = max(mons, key=lambda m: m.get_geometry().height)
        alto = self.monitor.get_geometry().height if self.monitor else 1000
        self.f = 0.72 if (escritorio and alto < 800) else 1.0
        self.ANCHO = int(620 * self.f)
        self.get_style_context().add_class("escritorio" if escritorio else "cc")
        vis = self.get_screen().get_rgba_visual()
        if vis:
            self.set_visual(vis)
        self.connect("draw", self.limpiar_fondo)
        f = self.f
        extra = (f".redondo {{ min-width: {int(110*f)}px; min-height: {int(110*f)}px; border-radius: {int(55*f)}px; }}"
                 f".circulo {{ min-width: {int(64*f)}px; min-height: {int(64*f)}px; border-radius: {int(32*f)}px; }}"
                 f".tarjeta, .pastilla {{ border-radius: {int(36*f)}px; }}"
                 f".titulo {{ font-size: {int(17*f) + (1 if f < 1 else 0)}px; }} .sub {{ font-size: {int(14*f) + 1}px; }}").encode()
        prov = Gtk.CssProvider(); prov.load_from_data(CSS + extra)
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), prov, 800)

        if escritorio:
            # Widget fijo: capa de fondo (debajo de las ventanas), abajo a la derecha del monitor más grande
            GtkLayerShell.init_for_window(self)
            GtkLayerShell.set_namespace(self, "centro-control")
            GtkLayerShell.set_layer(self, GtkLayerShell.Layer.BOTTOM)
            GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
            GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)
            GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, 68)
            GtkLayerShell.set_margin(self, GtkLayerShell.Edge.BOTTOM, 132)
            GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)
            if self.monitor:
                GtkLayerShell.set_monitor(self, self.monitor)
            if self.f < 1:
                GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, 40)
                GtkLayerShell.set_margin(self, GtkLayerShell.Edge.BOTTOM, 96)
        elif CAPA:
            GtkLayerShell.init_for_window(self)
            GtkLayerShell.set_namespace(self, "centro-control")
            GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
            for b in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM, GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT):
                GtkLayerShell.set_anchor(self, b, True)
            GtkLayerShell.set_exclusive_zone(self, -1)
            GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.EXCLUSIVE)
        else:
            self.set_decorated(False)
            self.fullscreen()

        self.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        if not escritorio:
            self.connect("button-press-event", lambda *a: self.cerrar())
        self.connect("key-press-event", self.tecla)
        self.connect("destroy", Gtk.main_quit)

        # Panel central (los clics dentro no cierran)
        caja = Gtk.EventBox(); caja.set_halign(Gtk.Align.CENTER); caja.set_valign(Gtk.Align.CENTER)
        caja.connect("button-press-event", lambda *a: True)
        self.pila = Gtk.Stack(); self.pila.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.pila.set_transition_duration(180)
        self.pila.set_homogeneous(False)
        caja.add(self.pila); self.add(caja)

        self.pila.add_named(self.vista_principal(), "principal")
        self.pila.add_named(self.vista_wifi(), "wifi")
        self.pila.add_named(self.vista_bt(), "bt")
        self.pila.add_named(self.vista_energia(), "energia")
        self.show_all()
        # En pantallas con escala fraccionaria (1.25, 1.6…) redibujar solo un pedazo deja restos:
        # cualquier cambio (pasar el mouse, clic, cambio de vista) redibuja todo el widget.
        self.conectar_redibujo(self)
        self.pila.connect("notify::visible-child", lambda *a: self.queue_draw())
        self.ir(vista)
        GLib.timeout_add_seconds(3, self.refrescar)

    # ---------------- utilidades
    def conectar_redibujo(self, w):
        if isinstance(w, (Gtk.Button, Gtk.Switch, Gtk.Entry)):
            w.connect("state-flags-changed", lambda *a: self.queue_draw())
        if isinstance(w, Gtk.Container):
            w.forall(self.conectar_redibujo)

    def limpiar_fondo(self, w, cr):
        """Borra lo dibujado antes (ventana transparente) para que nada quede encimado."""
        cr.save()
        cr.set_operator(cairo.OPERATOR_SOURCE)
        if self.escritorio:
            cr.set_source_rgba(0, 0, 0, 0)
        else:
            cr.set_source_rgba(0, 0, 0, 0.55)
        cr.paint()
        cr.restore()
        return False

    def cerrar(self):
        if self.escritorio:
            self.ir("principal"); return True
        avisar_widgets(); Gtk.main_quit(); return True

    def tecla(self, w, e):
        if e.keyval == Gdk.KEY_Escape:
            if self.pila.get_visible_child_name() != "principal":
                self.ir("principal")
            else:
                self.cerrar()
            return True
        return False

    def ir(self, vista):
        self.pila.set_visible_child_name(vista)
        if vista == "wifi": self.cargar_redes(rescan=False); self.cargar_redes(rescan=True)
        if vista == "bt": self.cargar_bt()

    def etiqueta(self, markup, clase=None, xalign=0):
        l = Gtk.Label(); l.set_markup(markup); l.set_xalign(xalign)
        l.set_ellipsize(Pango.EllipsizeMode.END)
        if clase: l.get_style_context().add_class(clase)
        return l

    def boton_redondo(self, icono, al_pulsar):
        b = Gtk.Button(); b.get_style_context().add_class("redondo"); b.set_can_focus(False)
        b.add(self.etiqueta(glifo(icono, int(30 * self.f)), xalign=0.5))
        b.connect("clicked", lambda *_: al_pulsar())
        return b

    def marcar(self, w, activo):
        ctx = w.get_style_context()
        (ctx.add_class if activo else ctx.remove_class)("activo")

    # ---------------- vista principal
    def vista_principal(self):
        f = self.f; esp = int(20 * f)
        col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=esp)
        # Fila 1: bloque de conectividad 2x2 + deslizadores de brillo y volumen
        f1 = Gtk.Box(spacing=esp)
        bloque = Gtk.Grid(column_spacing=int(24 * f), row_spacing=int(24 * f), margin=int(28 * f))
        self.b_avion = self.boton_redondo("avion", self.t_avion)
        self.b_wifi = self.boton_redondo("wifi", self.t_wifi)
        self.b_bt = self.boton_redondo("bt", self.t_bt)
        self.b_power = self.boton_redondo("power", lambda: self.ir("energia"))
        bloque.attach(self.b_avion, 0, 0, 1, 1); bloque.attach(self.b_wifi, 1, 0, 1, 1)
        bloque.attach(self.b_bt, 0, 1, 1, 1);    bloque.attach(self.b_power, 1, 1, 1, 1)
        t = Gtk.Box(); t.get_style_context().add_class("tarjeta"); t.add(bloque)
        f1.pack_start(t, False, False, 0)
        self.s_brillo = Deslizador("sol", brillo(), lambda v: sh(f"brightnessctl -q s {max(1, int(v * 100))}%"))
        v, mudo = volumen()
        self.s_vol = Deslizador("vol0" if mudo else "vol", v,
                                lambda v: sh(f"wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ {v:.2f}"))
        for d in (self.s_brillo, self.s_vol):
            d.set_size_request(int(140 * f), int(300 * f)); d.radio = int(36 * f); d.tam_icono = int(26 * f)
            f1.pack_start(d, False, False, 0)
        col.pack_start(f1, False, False, 0)
        # Fila 2: pastillas Wi-Fi / Bluetooth
        f2 = Gtk.Box(spacing=esp, homogeneous=True)
        self.p_wifi, self.c_wifi, self.l_wifi = self.pastilla("wifi", "Wi-Fi", lambda: self.ir("wifi"))
        self.p_bt, self.c_bt, self.l_bt = self.pastilla("bt", "Bluetooth", lambda: self.ir("bt"))
        f2.pack_start(self.p_wifi, True, True, 0); f2.pack_start(self.p_bt, True, True, 0)
        col.pack_start(f2, False, False, 0)
        # Fila 3: música (solo si hay algo sonando o pausado)
        self.t_musica = self.tarjeta_musica()
        col.pack_start(self.t_musica, False, False, 0)
        self.t_musica.set_no_show_all(f < 1)          # en compacto no se muestra la música
        col.set_size_request(self.ANCHO, -1)
        self.refrescar()
        return col

    def pastilla(self, icono, titulo, al_pulsar):
        b = Gtk.Button(); b.set_can_focus(False); b.get_style_context().add_class("pastilla"); b.set_size_request(int(300 * self.f), int(116 * self.f))
        b.set_hexpand(False)
        fila = Gtk.Box(spacing=16)
        circ = Gtk.Box(); circ.get_style_context().add_class("circulo")
        circ.set_valign(Gtk.Align.CENTER)
        ic = self.etiqueta(glifo(icono, int(20 * self.f)), xalign=0.5); ic.set_hexpand(True); circ.add(ic)
        textos = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, valign=Gtk.Align.CENTER)
        textos.add(self.etiqueta(titulo, "titulo"))
        sub = self.etiqueta("", "sub"); sub.set_max_width_chars(14); textos.add(sub)
        fila.pack_start(circ, False, False, 0); fila.pack_start(textos, True, True, 0)
        fila.pack_end(self.etiqueta(glifo("flecha", 13, "#8e8e93")), False, False, 0)
        b.add(fila); b.connect("clicked", lambda *_: al_pulsar())
        return b, circ, sub

    def tarjeta_musica(self):
        t = Gtk.Box(spacing=18, margin=0); t.get_style_context().add_class("tarjeta"); 
        interior = Gtk.Box(spacing=18, margin=24)
        interior.pack_start(self.etiqueta(glifo("musica", 30, "#8e8e93")), False, False, 6)
        info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, valign=Gtk.Align.CENTER)
        self.m_titulo = self.etiqueta("", "titulo"); self.m_artista = self.etiqueta("", "sub")
        info.add(self.m_titulo); info.add(self.m_artista)
        interior.pack_start(info, True, True, 0)
        controles = Gtk.Box(spacing=6)
        for ic, cmd in (("ant", "previous"), ("play", "play-pause"), ("sig", "next")):
            b = Gtk.Button(); b.set_can_focus(False); b.get_style_context().add_class("plano")
            l = self.etiqueta(glifo(ic, 20), xalign=0.5); b.add(l)
            if ic == "play": self.m_play = l
            b.connect("clicked", lambda _b, c=cmd: fondo(lambda: sh(f"playerctl {c}"), lambda r: self.refrescar()))
            controles.add(b)
        interior.pack_end(controles, False, False, 0)
        t.pack_start(interior, True, True, 0)
        return t

    def refrescar(self):
        if getattr(self, "_leyendo", False):
            return True
        self._leyendo = True
        def leer():
            return dict(wifi=wifi_on(), red=wifi_red(), bt=bt_on(), dev=bt_dev(),
                        musica=sh("playerctl metadata --format '{{title}}\t{{artist}}\t{{status}}' 2>/dev/null"),
                        brillo=brillo(), vol=volumen()[0])
        def pintar(e):
            self._leyendo = False
            self.marcar(self.b_wifi, e["wifi"]); self.marcar(self.b_bt, e["bt"])

            self.marcar(self.b_avion, not e["wifi"] and not e["bt"])
            self.marcar(self.c_wifi, e["wifi"]); self.marcar(self.c_bt, e["bt"])
            self.l_wifi.set_text(e["red"] or ("Sin conexión" if e["wifi"] else "Apagado"))
            self.l_bt.set_text(e["dev"] or ("Encendido" if e["bt"] else "Apagado"))
            partes = e["musica"].split("\t")
            if len(partes) == 3 and partes[0] and self.f == 1.0:
                self.t_musica.show(); self.m_titulo.set_text(partes[0]); self.m_artista.set_text(partes[1])
                self.m_play.set_markup(glifo("pausa" if partes[2] == "Playing" else "play", 20))
            else:
                self.t_musica.hide()
            for d, v in ((self.s_brillo, e["brillo"]), (self.s_vol, e["vol"])):
                if not d.arrastrando and d._pendiente is None and abs(d.valor - v) > 0.02:
                    d.valor = v; d.queue_draw()
            self.queue_draw()
            if hasattr(self, "sw_wifi"):
                self.bloqueo = True
                self.sw_wifi.set_active(e["wifi"]); self.sw_bt.set_active(e["bt"])
                self.bloqueo = False
        fondo(leer, pintar)
        return True

    # ---------------- acciones rápidas
    def t_wifi(self):
        fondo(lambda: sh("nmcli radio wifi " + ("off" if wifi_on() else "on")), lambda r: (self.refrescar(), avisar_widgets()))
    def t_bt(self):
        fondo(lambda: sh("bluetoothctl power off" if bt_on() else "rfkill unblock bluetooth; bluetoothctl power on"),
              lambda r: (self.refrescar(), avisar_widgets()))
    def t_avion(self):
        def h():
            if wifi_on() or bt_on():
                sh("nmcli radio wifi off; bluetoothctl power off")
            else:
                sh("nmcli radio wifi on; rfkill unblock bluetooth; bluetoothctl power on")
        fondo(h, lambda r: (self.refrescar(), avisar_widgets()))
    def t_dnd(self):
        activar = not self.b_dnd.get_style_context().has_class("activo")
        self.marcar(self.b_dnd, activar)                     # respuesta inmediata
        self.dnd_pendiente = True
        def fin(ok):
            self.dnd_pendiente = False
            if not ok:
                self.marcar(self.b_dnd, not activar)
        fondo(lambda: cambiar_dnd(activar), fin)

    # ---------------- vistas de lista (Wi-Fi / Bluetooth)
    def armazon(self, titulo, al_switch):
        caja = Gtk.Box(orientation=Gtk.Orientation.VERTICAL); caja.get_style_context().add_class("tarjeta")
        caja.set_size_request(self.ANCHO, (int(400 * self.f) + 100) if self.escritorio else 640)
        cab = Gtk.Box(spacing=10, margin=20)
        atras = Gtk.Button(); atras.set_can_focus(False); atras.get_style_context().add_class("plano")
        atras.add(self.etiqueta(glifo("atras", 18), xalign=0.5)); atras.connect("clicked", lambda *_: self.ir("principal"))
        cab.pack_start(atras, False, False, 0)
        cab.pack_start(self.etiqueta(titulo, "encabezado"), True, True, 0)
        sw = Gtk.Switch(); sw.set_valign(Gtk.Align.CENTER)
        sw.connect("notify::active", lambda s, _p: None if getattr(self, "bloqueo", False) else al_switch(s.get_active()))
        cab.pack_end(sw, False, False, 0)
        caja.pack_start(cab, False, False, 0)
        scroll = Gtk.ScrolledWindow(); scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)
        lista = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, margin_bottom=16, margin_start=8, margin_end=8)
        scroll.add(lista); caja.pack_start(scroll, True, True, 0)
        return caja, sw, lista

    def limpiar(self, caja):
        for h in caja.get_children():
            caja.remove(h)

    def fila(self, izq, texto, der=None, sub=None, al_pulsar=None):
        b = Gtk.Button(); b.set_can_focus(False); b.get_style_context().add_class("plano")
        fila = Gtk.Box(spacing=16, margin=8)
        fila.pack_start(izq, False, False, 0)
        tx = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, valign=Gtk.Align.CENTER)
        tx.add(self.etiqueta(GLib.markup_escape_text(texto), "titulo"))
        if sub: tx.add(self.etiqueta(sub, "sub"))
        fila.pack_start(tx, True, True, 0)
        if der: fila.pack_end(der, False, False, 0)
        b.add(fila)
        if al_pulsar: b.connect("clicked", lambda *_: al_pulsar())
        return b

    # Wi-Fi
    def vista_wifi(self):
        caja, self.sw_wifi, self.lista_wifi = self.armazon("Wi-Fi", lambda on: fondo(
            lambda: sh(f"nmcli radio wifi {'on' if on else 'off'}"),
            lambda r: (self.cargar_redes(rescan=True), self.refrescar(), avisar_widgets())))
        return caja

    def cargar_redes(self, rescan):
        def leer():
            if not wifi_on():
                return None
            out = sh(f"nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan {'yes' if rescan else 'no'}", 20)
            vistos, redes = set(), []
            for l in out.splitlines():
                p = l.replace("\\:", "\x00").split(":")
                if len(p) < 4: continue
                uso, ssid, senal, seg = [x.replace("\x00", ":") for x in p[:4]]
                if not ssid or ssid in vistos: continue
                vistos.add(ssid)
                redes.append((uso == "*", ssid, int(senal or 0), seg not in ("", "--")))
            conocidas = set(sh("nmcli -t -f NAME con show").splitlines())
            return sorted(redes, key=lambda r: (not r[0], -r[2])), conocidas
        fondo(leer, self.pintar_redes)

    def pintar_redes(self, datos):
        self.limpiar(self.lista_wifi)
        if datos is None:
            self.lista_wifi.add(self.etiqueta("El Wi-Fi está apagado", "seccion"))
        else:
            redes, conocidas = datos
            act = [r for r in redes if r[0]]; otras = [r for r in redes if not r[0]]
            if act:
                self.lista_wifi.add(self.etiqueta("CONECTADO", "seccion"))
                for r in act: self.lista_wifi.add(self.fila_red(r, conocidas))
            self.lista_wifi.add(self.etiqueta("REDES DISPONIBLES", "seccion"))
            for r in otras: self.lista_wifi.add(self.fila_red(r, conocidas))
            if not redes:
                self.lista_wifi.add(self.etiqueta("Buscando redes…", "sub"))
        conf = self.fila(self.etiqueta(glifo("engrane", 18, "#8e8e93"), xalign=0.5), "Configuración de red…",
                         al_pulsar=lambda: (subprocess.Popen("nm-connection-editor || kitty -e nmtui", shell=True), self.cerrar()))
        self.lista_wifi.add(conf)
        self.lista_wifi.show_all(); self.conectar_redibujo(self.lista_wifi); self.queue_draw()

    def fila_red(self, r, conocidas):
        conectada, ssid, senal, segura = r
        nivel = 3 if senal >= 70 else 2 if senal >= 45 else 1 if senal >= 20 else 0
        der = Gtk.Box(spacing=10)
        if segura: der.add(self.etiqueta(glifo("candado", 12, "#8e8e93")))
        if conectada: der.add(self.etiqueta(glifo("ok", 14)))
        contenedor = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        revelar = Gtk.Revealer()
        def pulsar():
            if conectada:
                return
            if ssid in conocidas or not segura:
                self.conectar(ssid, None, contenedor)
            else:
                revelar.set_reveal_child(not revelar.get_reveal_child())
                GLib.idle_add(clave.grab_focus)
        contenedor.add(self.fila(IconoWifi(nivel), ssid, der, None, pulsar))
        caja_clave = Gtk.Box(spacing=10, margin_start=60, margin_end=16, margin_bottom=10)
        clave = Gtk.Entry(); clave.set_visibility(False); clave.set_placeholder_text("Contraseña"); clave.set_hexpand(True)
        unir = Gtk.Button(label="Unirse"); unir.get_style_context().add_class("boton-claro")
        unir.connect("clicked", lambda *_: self.conectar(ssid, clave.get_text(), contenedor))
        clave.connect("activate", lambda *_: self.conectar(ssid, clave.get_text(), contenedor))
        caja_clave.pack_start(clave, True, True, 0); caja_clave.pack_start(unir, False, False, 0)
        revelar.add(caja_clave); contenedor.add(revelar)
        return contenedor

    def conectar(self, ssid, clave, contenedor):
        aviso = self.etiqueta(f"  Conectando a {GLib.markup_escape_text(ssid)}…", "sub")
        contenedor.add(aviso); aviso.show()
        def h():
            if clave is None and ssid in sh("nmcli -t -f NAME con show").splitlines():
                return subprocess.run(["nmcli", "con", "up", "id", ssid], capture_output=True, env=ENV_C).returncode == 0
            cmd = ["nmcli", "dev", "wifi", "connect", ssid] + (["password", clave] if clave else [])
            return subprocess.run(cmd, capture_output=True, env=ENV_C).returncode == 0
        def fin(ok):
            sh(f"notify-send -a Wi-Fi '{'Conectado a' if ok else 'No se pudo conectar a'} {ssid}'")
            self.cargar_redes(rescan=False); self.refrescar(); avisar_widgets()
        fondo(h, fin)

    # Bluetooth
    def vista_bt(self):
        caja, self.sw_bt, self.lista_bt = self.armazon("Bluetooth", lambda on: fondo(
            lambda: sh("rfkill unblock bluetooth; bluetoothctl power on" if on else "bluetoothctl power off"),
            lambda r: (self.cargar_bt(), self.refrescar(), avisar_widgets())))
        return caja

    def vista_energia(self):
        caja, sw, lista = self.armazon("Energía", lambda on: None)
        sw.set_no_show_all(True); sw.hide()
        opciones = [("candado", "Bloquear", "hyprlock"),
                    ("luna", "Suspender", "systemctl suspend"),
                    ("salir", "Cerrar sesión", "hyprctl dispatch exit"),
                    ("reiniciar", "Reiniciar", "systemctl reboot"),
                    ("power", "Apagar", "systemctl poweroff")]
        for ic, texto, cmd in opciones:
            lista.add(self.fila(self.etiqueta(glifo(ic, 18), xalign=0.5), texto,
                                al_pulsar=lambda c=cmd: self.energia(c)))
        return caja

    def energia(self, cmd):
        self.ir("principal")
        subprocess.Popen(f"sleep 0.2; {cmd}", shell=True, start_new_session=True)
        if not self.escritorio:
            self.cerrar()

    def icono_dispositivo(self, tipo):
        t = (tipo or "").lower()
        n = "audif" if "audio" in t or "head" in t else "teclado" if "keyboard" in t else \
            "mouse" if "mouse" in t else "cel" if "phone" in t else "bt"
        return self.etiqueta(glifo(n, 18), xalign=0.5)

    def cargar_bt(self, buscar=False):
        def leer():
            if not bt_on():
                return None
            if buscar:
                sh("bluetoothctl --timeout 9 scan on", 15)
            disp = []
            for l in sh("bluetoothctl devices").splitlines():
                p = l.split(" ", 2)
                if len(p) < 3: continue
                info = sh(f"bluetoothctl info {p[1]}")
                g = lambda k: next((x.split(": ", 1)[1] for x in info.splitlines() if x.strip().startswith(k + ":")), "")
                bat = next((x.split("(")[1].rstrip(")") for x in info.splitlines() if "Battery Percentage" in x and "(" in x), "")
                disp.append(dict(mac=p[1], nombre=p[2], par=g("Paired") == "yes", con=g("Connected") == "yes",
                                 icono=g("Icon"), bat=bat))
            return disp
        fondo(leer, lambda d: self.pintar_bt(d, buscar))

    def pintar_bt(self, disp, buscando):
        self.limpiar(self.lista_bt)
        if disp is None:
            self.lista_bt.add(self.etiqueta("El Bluetooth está apagado", "seccion"))
        else:
            self.lista_bt.add(self.etiqueta("MIS DISPOSITIVOS", "seccion"))
            for d in [x for x in disp if x["par"]]:
                sub = ("Conectado" + (f" · {d['bat']}%" if d["bat"] else "")) if d["con"] else "No conectado"
                self.lista_bt.add(self.fila(self.icono_dispositivo(d["icono"]), d["nombre"], None, sub,
                                            lambda d=d: self.bt_accion(d)))
            otros = [x for x in disp if not x["par"] and not x["nombre"].replace("-", ":").count(":") >= 5]
            self.lista_bt.add(self.etiqueta("OTROS DISPOSITIVOS", "seccion"))
            for d in otros:
                self.lista_bt.add(self.fila(self.icono_dispositivo(d["icono"]), d["nombre"], None, "Toca para emparejar",
                                            lambda d=d: self.bt_accion(d)))
            self.lista_bt.add(self.fila(self.etiqueta(glifo("buscar", 16, "#8e8e93"), xalign=0.5),
                                        "Buscando…" if buscando else "Buscar dispositivos",
                                        al_pulsar=lambda: self.cargar_bt(buscar=True)))
        self.lista_bt.add(self.fila(self.etiqueta(glifo("engrane", 18, "#8e8e93"), xalign=0.5), "Configuración de Bluetooth…",
                                    al_pulsar=lambda: (subprocess.Popen("blueman-manager", shell=True), self.cerrar())))
        self.lista_bt.show_all(); self.conectar_redibujo(self.lista_bt); self.queue_draw()

    def bt_accion(self, d):
        def h():
            m = d["mac"]
            if d["con"]: return sh(f"bluetoothctl disconnect {m}"), "Desconectado de"
            if d["par"]: return sh(f"bluetoothctl connect {m}", 20), "Conectado a"
            return sh(f"bluetoothctl pair {m} && bluetoothctl trust {m} && bluetoothctl connect {m}", 40), "Emparejado con"
        def fin(r):
            sh(f"notify-send -a Bluetooth '{r[1]} {d['nombre']}'")
            self.cargar_bt(); self.refrescar(); avisar_widgets()
        fondo(h, fin)


if __name__ == "__main__":
    escritorio = len(sys.argv) > 1 and sys.argv[1] == "escritorio"
    posicion = sys.argv[2] if escritorio and len(sys.argv) > 2 else None
    nombre = f"centro-control-escritorio-{posicion or 'x'}.pid" if escritorio else "centro-control.pid"
    PID = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), nombre)
    try:
        viejo = int(open(PID).read())
        if viejo != os.getpid() and "centro-control" in open(f"/proc/{viejo}/cmdline").read():
            os.kill(viejo, 15)
            if not escritorio:
                sys.exit(0)          # modo normal: tocar de nuevo = cerrar
    except (OSError, ValueError):
        pass
    open(PID, "w").write(str(os.getpid()))
    if escritorio and not CAPA:
        sh("notify-send -a 'Centro de Control' 'Falta un paquete' 'sudo apt install gir1.2-gtklayershell-0.1'")
        sys.exit(1)
    if CAPA:
        sh("hyprctl keyword layerrule 'match:namespace centro-control, blur on'")
        sh("hyprctl keyword layerrule 'match:namespace centro-control, ignore_alpha 0.15'")
    vista = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] in ("wifi", "bt") else "principal"
    Centro(vista, escritorio, posicion)
    Gtk.main()
