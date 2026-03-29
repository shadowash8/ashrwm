(import protocols)
(import wayland)
(import spork/netrepl)
(import xkbcommon)

(def interfaces
  (wayland/scan
    :wayland-xml protocols/wayland-xml
    :system-protocols-dir protocols/wayland-protocols
    :system-protocols ["stable/viewporter/viewporter.xml"
                       "staging/single-pixel-buffer/single-pixel-buffer-v1.xml"]
    :custom-protocols (map |(string protocols/river-protocols $)
                           ["/river-window-management-v1.xml"
                            "/river-layer-shell-v1.xml"
                            "/river-xkb-bindings-v1.xml"])))

(def required-interfaces
  @{"wl_compositor" 4
    "wp_viewporter" 1
    "wp_single_pixel_buffer_manager_v1" 1
    "river_window_manager_v1" 4
    "river_layer_shell_v1" 1
    "river_xkb_bindings_v1" 1})

# https://protesilaos.com/emacs/modus-themes-colors
(def light @{:background 0xffffff
             :border-normal 0x9f9f9f
             :border-focused 0x000000})

(def dark @{:background 0x000000
            :border-normal 0x646464
            :border-focused 0xffffff})

(def config @{:border-width 2
              :outer-padding 4
              :inner-padding 4
              :main-ratio 0.60
              :xkb-bindings @[]
              :pointer-bindings @[]})
(merge-into config dark)

(def wm @{:config config
          :outputs @[]
          :seats @[]
          :windows @[]
          # Windows in rendering order rather than window management order.
          # The last window in the array is rendered on top.
          :render-order @[]})

(def registry @{})

(defn rgb-to-u32-rgba [rgb]
  [(* (band 0xff (brushift rgb 16)) (/ 0xffff_ffff 0xff))
   (* (band 0xff (brushift rgb 8)) (/ 0xffff_ffff 0xff))
   (* (band 0xff rgb) (/ 0xffff_ffff 0xff))
   0xffff_ffff])

(defn bg/manage [bg output]
  (when ((wm :config) :background)
    (:sync-next-commit (bg :shell-surface))
    (:place-bottom (bg :node))
    (:set-position (bg :node) (output :x) (output :y))
    (def buffer (:create-u32-rgba-buffer
                  (registry "wp_single_pixel_buffer_manager_v1")
                  ;(rgb-to-u32-rgba ((wm :config) :background))))
    (:attach (bg :surface) buffer 0 0)
    (:damage-buffer (bg :surface) 0 0 0x7fff_ffff 0x7fff_ffff)
    (:set-destination (bg :viewport) (output :w) (output :h))
    (:commit (bg :surface))
    (:destroy buffer)))

(defn bg/destroy [bg]
  (:destroy (bg :viewport))
  (:destroy (bg :shell-surface))
  (:destroy (bg :surface))
  (:destroy (bg :node)))

(defn bg/create []
  (def surface (:create-surface (registry "wl_compositor")))
  (def viewport (:get-viewport (registry "wp_viewporter") surface))
  (def shell-surface (:get-shell-surface (registry "river_window_manager_v1") surface))
  @{:surface surface
    :viewport viewport
    :shell-surface shell-surface
    :node (:get-node shell-surface)})

(defn output/visible [output windows]
  (let [tags (output :tags)]
    (filter |(tags ($ :tag)) windows)))

(defn output/usable-area [output]
  (if-let [[x y w h] (output :non-exclusive-area)]
    {:x x :y y :w w :h h}
    {:x (output :x) :y (output :y) :w (output :w) :h (output :h)}))

(defn output/manage-start [output]
  (if (output :removed)
    (do
      (:destroy (output :obj))
      (bg/destroy (output :bg)))
    output))

(defn output/manage [output]
  (bg/manage (output :bg) output)
  (when (output :new)
    (let [unused (find (fn [tag] (not (find |(($ :tags) tag) (wm :outputs)))) (range 1 10))]
      (put (output :tags) unused true))))

(defn output/manage-finish [output]
  (put output :new nil))

(defn output/create [obj]
  (def output @{:obj obj
                :bg (bg/create)
                :layer-shell (:get-output (registry "river_layer_shell_v1") obj)
                :new true
                :tags @{}})
  (defn output/handle-event [event]
    (match event
      [:removed] (put output :removed true)
      [:position x y] (do (put output :x x) (put output :y y))
      [:dimensions w h] (do (put output :w w) (put output :h h))))
  (defn output/handle-layer-shell-event [event]
    (match event
      [:non-exclusive-area x y w h] (put output :non-exclusive-area [x y w h])))
  (:set-user-data obj output)
  (:set-handler obj output/handle-event)
  (:set-handler (output :layer-shell) output/handle-layer-shell-event)
  output)

(defn window/set-position
  "Set position, adjusting for border width"
  [window x y]
  (let [border-width ((wm :config) :border-width)
        x (+ x border-width)
        y (+ y border-width)]
    (put window :x x)
    (put window :y y)
    (:set-position (window :node) x y)))

(defn window/propose-dimensions
  "Propose dimensions, adjusting for border width"
  [window w h]
  (def border-width ((wm :config) :border-width))
  (:propose-dimensions (window :obj)
                       (max 1 (- w (* 2 border-width)))
                       (max 1 (- h (* 2 border-width)))))

(defn window/set-float [window float]
  (if float
    (:set-tiled (window :obj) {})
    (:set-tiled (window :obj) {:left true :bottom :true :top :true :right true}))
  (put window :float float))

(defn window/set-fullscreen [window fullscreen-output]
  (if-let [output fullscreen-output]
    (do
      (put window :fullscreen true)
      (:inform-fullscreen (window :obj))
      (:fullscreen (window :obj) (output :obj)))
    (do
      (put window :fullscreen false)
      (:inform-not-fullscreen (window :obj))
      (:exit-fullscreen (window :obj)))))

(defn window/tag-output [window]
  (find |(($ :tags) (window :tag)) (wm :outputs)))

(defn window/max-overlap-output [window]
  (var max-overlap 0)
  (var max-overlap-output nil)
  (each output (wm :outputs)
    (def overlap-w (- (min (+ (window :x) (window :w))
                           (+ (output :x) (output :w)))
                      (max (window :x) (output :x))))
    (def overlap-h (- (min (+ (window :y) (window :h))
                           (+ (output :y) (output :h)))
                      (max (window :y) (output :y))))
    (when (and (> overlap-w 0) (> overlap-h 0))
      (def overlap (* overlap-w overlap-h))
      (when (> overlap max-overlap)
        (set max-overlap overlap)
        (set max-overlap-output output))))
  max-overlap-output)

(defn window/update-tag [window]
  (when-let [output (window/max-overlap-output window)]
    (unless (= output (window/tag-output window))
      (put window :tag (or (min-of (keys (output :tags))) 1)))))

(defn window/create [obj]
  (def window @{:obj obj
                :node (:get-node obj)
                :new true
                :tag 1})
  (defn window/handle-event [event]
    (match event
      [:closed] (put window :closed true)
      [:dimensions-hint min-w min-h max-w max-h] (do
                                                   (put window :min-w min-w)
                                                   (put window :min-h min-h)
                                                   (put window :max-w max-w)
                                                   (put window :max-h max-h))
      [:dimensions w h] (do (put window :w w) (put window :h h))
      [:app-id app-id] (put window :app-id app-id)
      [:title title] (put window :title title)
      [:parent parent] (put window :parent (if parent (:get-user-data parent)))
      [:decoration-hint hint] (put window :decoration-hint hint)
      [:pointer-move-requested seat] (put window :pointer-move-requested
                                          {:seat (:get-user-data seat)})
      [:pointer-resize-requested seat edges] (put window :pointer-resize-requested
                                                  {:seat (:get-user-data seat)
                                                   :edges edges})
      [:fullscreen-requested output] (put window :fullscreen-requested
                                          [:enter (if output (:get-user-data output))])
      [:exit-fullscreen-requested] (put window :fullscreen-requested [:exit])))
  (:set-handler obj window/handle-event)
  (:set-user-data obj window)
  window)

(defn pointer-binding/create [seat button mods action]
  # From /usr/include/linux/input-event-codes.h
  (def button-code {:left 0x110
                    :right 0x111
                    :middle 0x112})
  (def binding @{:obj (:get-pointer-binding (seat :obj) (button-code button) mods)})
  (defn handle-event [event]
    (match event
      [:pressed] (put seat :pending-action [binding action])))
  (:set-handler (binding :obj) handle-event)
  (:enable (binding :obj))
  (array/push (seat :pointer-bindings) binding))

(defn xkb-binding/create [seat keysym mods action]
  (def binding @{:obj (:get-xkb-binding (registry "river_xkb_bindings_v1")
                                        (seat :obj) (xkbcommon/keysym keysym) mods)})
  (defn handle-event [event]
    (match event
      [:pressed] (put seat :pending-action [binding action])))
  (:set-handler (binding :obj) handle-event)
  (:enable (binding :obj))
  (array/push (seat :xkb-bindings) binding))

(defn seat/focus-output [seat output]
  (unless (= output (seat :focused-output))
    (put seat :focused-output output)
    (when output (:set-default (output :layer-shell)))))

(defn seat/focus [seat window]
  (defn focus-window [window]
    (unless (= (seat :focused) window)
      (:focus-window (seat :obj) (window :obj))
      (put seat :focused window)
      (if-let [i (find-index |(= $ window) (wm :render-order))]
        (array/remove (wm :render-order) i))
      (array/push (wm :render-order) window)
      (:place-top (window :node))))
  (defn clear-focus []
    (when (seat :focused)
      (:clear-focus (seat :obj))
      (put seat :focused nil)))
  (defn focus-non-layer []
    (when window
      (when-let [output (window/tag-output window)]
        (seat/focus-output seat output)))
    (when-let [output (seat :focused-output)]
      (defn visible? [w] (and w ((output :tags) (w :tag))))
      (def visible (output/visible output (wm :render-order)))
      (cond
        # The top fullscreen window always grabs focus when present.
        (def fullscreen (last (filter |($ :fullscreen) visible)))
        (focus-window fullscreen)
        # If there is a visible explict target window, focus it.
        (visible? window) (focus-window window)
        # Otherwise, don't change focus if the current focus is visible.
        (visible? (seat :focused)) (do)
        # When no visible window is focused, focus the top one, if any.
        (def top-visible (last visible)) (focus-window top-visible)
        # When no windows are visible, clear focus.
        (clear-focus))))
  (case (seat :layer-focus)
    :exclusive (put seat :focused nil)
    :non-exclusive (if window
                     (do
                       (put seat :layer-focus :none)
                       (focus-non-layer))
                     (put seat :focused nil))
    :none (focus-non-layer)))

(defn seat/pointer-move [seat window]
  (unless (seat :op)
    (seat/focus seat window)
    (window/set-float window true)
    (:op-start-pointer (seat :obj))
    (put seat :op @{:type :move
                    :window window
                    :start-x (window :x) :start-y (window :y)
                    :dx 0 :dy 0})))

(defn seat/pointer-resize [seat window edges]
  (unless (seat :op)
    (seat/focus seat window)
    (window/set-float window true)
    (:op-start-pointer (seat :obj))
    (put seat :op @{:type :resize
                    :window window
                    :edges edges
                    :start-x (window :x) :start-y (window :y)
                    :start-w (window :w) :start-h (window :h)
                    :dx 0 :dy 0})))

(defn window/manage-start [window]
  (if (window :closed)
    (do
      (:destroy (window :obj))
      (:destroy (window :node)))
    window))

(defn window/manage [window]
  (when (window :new)
    (:use-ssd (window :obj))
    (if-let [parent (window :parent)]
      (do
        (window/set-float window true)
        (put window :tag (parent :tag))
        (:propose-dimensions (window :obj) 0 0))
      (do
        (window/set-float window false)
        (when-let [seat (first (wm :seats))
                   output (seat :focused-output)]
          (put window :tag (or (min-of (keys (output :tags))) 1))))))
  (match (window :fullscreen-requested)
    [:enter] (if-let [seat (first (wm :seats))
                      output (seat :focused-output)]
               (window/set-fullscreen window output))
    [:enter output] (window/set-fullscreen window output)
    [:exit] (window/set-fullscreen window nil))
  (when-let [move (window :pointer-move-requested)]
    (seat/pointer-move (move :seat) window))
  (when-let [resize (window :pointer-resize-requested)]
    (seat/pointer-resize (resize :seat) window (resize :edges))))

(defn window/manage-finish [window]
  (put window :new nil)
  (put window :pointer-move-requested nil)
  (put window :pointer-resize-requested nil)
  (put window :fullscreen-requested nil))

(defn- set-borders [window status config]
  (def rgb (case status
             :normal (config :border-normal)
             :focused (config :border-focused)))
  (:set-borders (window :obj)
                {:left true :bottom :true :top :true :right true}
                (config :border-width)
                ;(rgb-to-u32-rgba rgb)))

(defn window/render [window]
  (when (and (not (window :x)) (window :w))
    # Windows that start with a parent have nil x/y until rijan receives
    # a dimensions event and a render sequence is completed.
    (if-let [output (window/max-overlap-output (window :parent))]
      (window/set-position window
                           (+ (output :x) (div (- (output :w) (window :w)) 2))
                           (+ (output :y) (div (- (output :h) (window :h)) 2)))
      (window/set-position window 0 0)))
  (if (find |(= ($ :focused) window) (wm :seats))
    (set-borders window :focused (wm :config))
    (set-borders window :normal (wm :config))))

(defn seat/manage-start [seat]
  (if (seat :removed)
    (:destroy (seat :obj))
    seat))

(defn seat/manage [seat]
  (when (seat :new)
    (each binding (config :xkb-bindings)
      (xkb-binding/create seat ;binding))
    (each binding (config :pointer-bindings)
      (pointer-binding/create seat ;binding)))
  (when-let [window (seat :focused)]
    (when (window :closed)
      (put seat :focused nil)))
  (when-let [op (seat :op)]
    (when ((op :window) :closed)
      (put seat :op nil)))
  (if (or (not (seat :focused-output))
          ((seat :focused-output) :removed))
    (seat/focus-output seat (first (wm :outputs))))

  (seat/focus seat nil)
  (each window (wm :windows)
    (when (window :new)
      (seat/focus seat window)))
  (if-let [window (seat :window-interaction)]
    (seat/focus seat window))

  (when-let [[binding action] (seat :pending-action)]
    (action seat binding))

  # Ensure focus is consistent after action (e.g. may have switched tags)
  (seat/focus seat nil)

  (when-let [op (seat :op)]
    (when (= :resize (op :type))
      # Resize from bottom right corner
      (window/propose-dimensions (op :window)
                                 (max 1 (+ (op :start-w) (op :dx)))
                                 (max 1 (+ (op :start-h) (op :dy))))))
  (when (and (seat :op-release) (seat :op))
    (:op-end (seat :obj))
    (window/update-tag ((seat :op) :window))
    # TODO why do I need this focus-output call here??
    (seat/focus-output seat (window/tag-output ((seat :op) :window)))
    (put seat :op nil)))

(defn seat/manage-finish [seat]
  (put seat :new nil)
  (put seat :window-interaction nil)
  (put seat :pending-action nil)
  (put seat :op-release nil))

(defn seat/render [seat]
  (when-let [op (seat :op)]
    (when (= :move (op :type))
      (window/set-position (op :window)
                           (+ (op :start-x) (op :dx))
                           (+ (op :start-y) (op :dy))))))

(defn seat/create [obj]
  (def seat @{:obj obj
              :layer-shell (:get-seat (registry "river_layer_shell_v1") obj)
              :layer-focus :none
              :xkb-bindings @[]
              :pointer-bindings @[]
              :new true})
  (defn seat/handle-event [event]
    (match event
      [:removed] (put seat :removed true)
      [:pointer-enter window] (put seat :pointer-target (:get-user-data window))
      [:pointer-leave] (put seat :pointer-target nil)
      [:window-interaction window] (put seat :window-interaction (:get-user-data window))
      [:shell-surface-interaction shell_surface] (do)
      [:op-delta dx dy] (do (put (seat :op) :dx dx) (put (seat :op) :dy dy))
      [:op-release] (put seat :op-release true)))
  (defn seat/handle-layer-shell-event [event]
    (match event
      [:focus-exclusive] (put seat :layer-focus :exclusive)
      [:focus-non-exclusive] (put seat :layer-focus :non-exclusive)
      [:focus-none] (put seat :layer-focus :none)))
  (:set-handler obj seat/handle-event)
  (:set-handler (seat :layer-shell) seat/handle-layer-shell-event)
  (:set-user-data obj seat)
  (:set-xcursor-theme obj "Adwaita" 24)
  seat)

(defn wm/show-hide []
  (def all-tags @{})
  (each output (wm :outputs)
    (merge-into all-tags (output :tags))
    # Ensure the output on which windows are fullscreen is updated
    # if they become visible on a different output.
    (each window (wm :windows)
      (when (and (window :fullscreen)
                 ((output :tags) (window :tag)))
        (:fullscreen (window :obj) (output :obj)))))
  (each window (wm :windows)
    (if (all-tags (window :tag))
      (:show (window :obj))
      (:hide (window :obj)))))

(defn wm/layout [output]
  (def windows (filter |(not ($ :float)) (output/visible output (wm :windows))))
  (def side-count (- (length windows) 1))
  (def usable (output/usable-area output))
  (def total-w (max 0 (- (usable :w) (* 2 ((wm :config) :outer-padding)))))
  (def total-h (max 0 (- (usable :h) (* 2 ((wm :config) :outer-padding)))))
  (def main-w (if (= 0 side-count) total-w (math/round (* total-w ((wm :config) :main-ratio)))))
  (def side-w (- total-w main-w))
  (def side-h (div total-h side-count))
  (def side-h-rem (% total-h side-count))
  (->> (range (length windows))
       (map (fn [i]
              (case i
                0 [0 0 main-w total-h]
                1 [main-w 0 side-w (+ side-h side-h-rem)]
                [main-w (+ side-h-rem (* side-h (- i 1)))
                 side-w side-h])))
       (map (fn [[x y w h]]
              (def outer ((wm :config) :outer-padding))
              (def inner ((wm :config) :inner-padding))
              [(+ x outer inner) (+ y outer inner)
               (- w (* 2 inner)) (- h (* 2 inner))]))
       (map (fn [[x y w h]]
              [(+ x (usable :x)) (+ y (usable :y)) w h]))
       (map (fn [window box]
              (window/set-position window ;(slice box 0 2))
              (window/propose-dimensions window ;(slice box 2 4)))
            windows)))

(defn wm/manage []
  (update wm :render-order |(->> $ (filter (fn [window] (not (window :closed))))))

  (update wm :outputs |(keep output/manage-start $))
  (update wm :windows |(keep window/manage-start $))
  (update wm :seats |(keep seat/manage-start $))

  (map output/manage (wm :outputs))
  (map window/manage (wm :windows))
  (map seat/manage (wm :seats))

  (map wm/layout (wm :outputs))
  (wm/show-hide)

  (map output/manage-finish (wm :outputs))
  (map window/manage-finish (wm :windows))
  (map seat/manage-finish (wm :seats))

  (:manage-finish (registry "river_window_manager_v1")))

(defn wm/render []
  (map window/render (wm :windows))
  (map seat/render (wm :seats))
  (:render-finish (registry "river_window_manager_v1")))

(defn wm/handle-event [event]
  (match event
    [:unavailable] (do
                     (print "another window manager is already running")
                     (os/exit 1))
    [:finished] (os/exit 0)
    [:manage-start] (wm/manage)
    [:render-start] (wm/render)
    [:output obj] (array/push (wm :outputs) (output/create obj))
    [:seat obj] (array/push (wm :seats) (seat/create obj))
    [:window obj] (array/insert (wm :windows) 0 (window/create obj))))

(defn registry/handle-event [event]
  (def obj (registry :obj))
  (match event
    [:global name interface version]
    (when-let [required-version (get required-interfaces interface)]
      (when (< version required-version)
        (errorf "wayland compositor supported %s version too old (need %d, got %d)"
                interface required-version version))
      (put registry interface (:bind (registry :obj) name interface required-version)))))

(defn action/target [seat dir]
  (when-let [window (seat :focused)
             output (window/tag-output window)
             visible (output/visible output (wm :windows))
             i (assert (index-of window visible))]
    (case dir
      :next (get visible (+ i 1) (first visible))
      :prev (get visible (- i 1) (last visible))
      (error "invalid dir"))))

(defn action/spawn [command]
  (fn [seat binding]
    (ev/spawn
      (os/proc-wait (os/spawn command :p)))))

(defn action/close []
  (fn [seat binding]
    (if-let [window (seat :focused)]
      (:close (window :obj)))))

(defn action/zoom []
  (fn [seat binding]
    (when-let [focused (seat :focused)
               output (window/tag-output focused)
               visible (output/visible output (wm :windows))
               target (if (= focused (first visible)) (get visible 1) focused)
               i (assert (index-of target (wm :windows)))]
      (array/remove (wm :windows) i)
      (array/insert (wm :windows) 0 target)
      (seat/focus seat (first (wm :windows))))))

(defn action/focus [dir]
  (fn [seat binding]
    (seat/focus seat (action/target seat dir))))

(defn action/focus-output []
  (fn [seat binding]
    (when-let [focused (seat :focused-output)
               i (assert (index-of focused (wm :outputs)))
               target (or (get (wm :outputs) (+ i 1))
                          (first (wm :outputs)))]
      (seat/focus-output seat target)
      (seat/focus seat nil))))

(defn action/float []
  (fn [seat binding]
    (if-let [window (seat :focused)]
      (window/set-float window (not (window :float))))))

(defn action/fullscreen []
  (fn [seat binding]
    (if-let [window (seat :focused)]
      (if (window :fullscreen)
        (window/set-fullscreen window nil)
        (window/set-fullscreen window (window/tag-output window))))))

(defn action/set-tag [tag]
  (fn [seat binding]
    (if-let [window (seat :focused)]
      (put window :tag tag))))

(defn fallback-tags [outputs]
  (for tag 1 10
    (unless (find |(($ :tags) tag) outputs)
      (when-let [output (find |(empty? ($ :tags)) outputs)]
        (put (output :tags) tag true)))))

(defn action/focus-tag [tag]
  (fn [seat binding]
    (when-let [output (seat :focused-output)]
      (map |(put ($ :tags) tag nil) (wm :outputs))
      (put output :tags @{tag true})
      (fallback-tags (wm :outputs)))))

(defn action/toggle-tag [tag]
  (fn [seat binding]
    (when-let [output (seat :focused-output)]
      (if ((output :tags) tag)
        (put (output :tags) tag nil)
        (do
          (map |(put ($ :tags) tag nil) (wm :outputs))
          (put (output :tags) tag true)))
      (fallback-tags (wm :outputs)))))

(defn action/focus-all-tags []
  (fn [seat binding]
    (when-let [output (seat :focused-output)]
      (map |(put $ :tags @{}) (wm :outputs))
      (put output :tags (table ;(mapcat |[$ true] (range 1 10)))))))

(defn action/pointer-move []
  (fn [seat binding]
    (when-let [window (seat :pointer-target)]
      (seat/pointer-move seat window))))

(defn action/pointer-resize []
  (fn [seat binding]
    (when-let [window (seat :pointer-target)]
      (seat/pointer-resize seat window {:bottom true :left true}))))

(defn action/passthrough []
  (fn [seat binding]
    (put binding :passthrough (not (binding :passthrough)))
    (def request (if (binding :passthrough) :disable :enable))
    (each other (seat :xkb-bindings)
      (unless (= other binding)
        (request (other :obj))))
    (each other (seat :pointer-bindings)
      (unless (= other binding)
        (request (other :obj))))))

(defn action/exit-session []
  (fn [seat binding]
    (:exit-session (registry "river_window_manager_v1"))))

# Only main is marshaled when building a standalone executable,
# so we must capture the REPL environment outside of main.
(def repl-env (curenv))
(defn repl-server-create []
  (def path (string/format "%s/rijan-%s"
                           (assert (os/getenv "XDG_RUNTIME_DIR"))
                           (assert (os/getenv "WAYLAND_DISPLAY"))))
  (protect (os/rm path))
  (netrepl/server :unix path repl-env))

(defn main [& args]
  (def display (wayland/connect interfaces))

  # Avoid passing WAYLAND_DEBUG on to our children.
  # It only matters if it's set when the display is created.
  (os/setenv "WAYLAND_DEBUG" nil)

  (def config-dir (or (os/getenv "XDG_CONFIG_HOME")
                      (string (os/getenv "HOME") "/.config")))
  (def init-path (get 1 args (string config-dir "/rijan/init.janet")))
  (when-let [init (file/open init-path :r)]
    (dofile init :env repl-env)
    (file/close init))

  (put registry :obj (:get-registry display))
  (:set-handler (registry :obj) registry/handle-event)
  (:roundtrip display)
  (eachk i required-interfaces
    (unless (get registry i)
      (errorf "wayland compositor does not support %s" i)))

  (:set-handler (registry "river_window_manager_v1") wm/handle-event)

  # Do a roundtrip to give the compositor the chance to send the
  # :unavailable event before creating the repl server and potentially
  # overwriting the repl socket of an already running rijan instance.
  (:roundtrip display)

  (def repl-server (repl-server-create))

  (defer (:close repl-server)
    (forever (:dispatch display))))
