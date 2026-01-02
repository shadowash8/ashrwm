(import protocols)
(import wayland)
(import spork/netrepl)

(import ./src/window)
(import ./src/output)
(import ./src/seat)

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
              :main-ratio 0.60})
(merge-into config light)

(def wm @{:config config
          :outputs @[]
          :seats @[]
          :windows @[]
          # Windows in rendering order rather than window management order.
          # The last window in the array is rendered on top.
          :render-order @[]})

(def registry @{:outputs @{}
                :seats @{}})

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
              (window/set-position window wm ;(slice box 0 2))
              (window/propose-dimensions window wm ;(slice box 2 4)))
            windows)))

(defn wm/manage []
  (update wm :render-order |(->> $ (filter (fn [window] (not (window :closed))))))

  (update wm :outputs |(keep output/manage-start $))
  (update wm :windows |(keep window/manage-start $))
  (update wm :seats |(keep seat/manage-start $))

  (map |(output/manage $ wm) (wm :outputs))
  (map |(window/manage $ wm) (wm :windows))
  (map |(seat/manage $ wm) (wm :seats))

  (map wm/layout (wm :outputs))
  (wm/show-hide)

  (map output/manage-finish (wm :outputs))
  (map window/manage-finish (wm :windows))
  (map seat/manage-finish (wm :seats))

  (:manage-finish (registry :rwm)))

(defn wm/render []
  (map |(window/render $ wm) (wm :windows))
  (map |(seat/render $ wm) (wm :seats))
  (:render-finish (registry :rwm)))

(defn wm/handle-event [event]
  (match event
    [:unavailable] (do
                     (print "another window manager is already running")
                     (os/exit 1))
    [:finished] (os/exit 0)
    [:manage-start] (wm/manage)
    [:render-start] (wm/render)
    [:output obj] (array/push (wm :outputs) (output/create obj registry))
    [:seat obj] (array/push (wm :seats) (seat/create obj registry))
    [:window obj] (array/insert (wm :windows) 0 (window/create obj))))

(defn registry/handle-event [event]
  (def obj (registry :obj))
  (match event
    # XXX check advertised versions
    [:global name interface version]
    (case interface
      # need 4 for attach-buffer
      "wl_compositor" (put registry :compositor (:bind obj name interface 4))
      "wp_viewporter" (put registry :viewporter (:bind obj name interface 1))
      "wp_single_pixel_buffer_manager_v1" (put registry :single-pixel (:bind obj name interface 1))
      "river_window_manager_v1" (put registry :rwm (:bind obj name interface 2))
      "river_layer_shell_v1" (put registry :layer-shell (:bind obj name interface 1))
      "river_xkb_bindings_v1" (put registry :xkb-bindings (:bind obj name interface 1))
      # need 4 for release
      "wl_output" (put (registry :outputs) name (:bind obj name interface 4))
      # need 5 for release
      "wl_seat" (put (registry :seats) name (:bind obj name interface 5)))
    # XXX remove from wm outputs and seats arrays
    [:global-remove name]
    (do
      (if-let [output ((registry :outputs) name)]
        (:release output))
      (if-let [seat ((registry :seats) name)]
        (:release seat)))))

# Only main is marshaled when building a standalone executable,
# so we must capture the REPL environment outside of main.
(def repl-env (curenv))
(defn repl-server-create []
  (def path (string/format "%s/rijan-%s"
                           (assert (os/getenv "XDG_RUNTIME_DIR"))
                           (assert (os/getenv "WAYLAND_DISPLAY"))))
  (protect (os/rm path))
  (netrepl/server :unix path repl-env))

(defn main [&]
  (def display (wayland/connect interfaces))

  # Avoid passing WAYLAND_DEBUG on to our children.
  # It only matters if it's set when the display is created.
  (os/setenv "WAYLAND_DEBUG" nil)

  (put registry :obj (:get-registry display))
  (:set-handler (registry :obj) registry/handle-event)
  (:roundtrip display)

  (:set-handler (registry :rwm) wm/handle-event)

  # Do a roundtrip to give the compositor the chance to send the
  # :unavailable event before creating the repl server and potentially
  # overwriting the repl socket of an already running rijan instance.
  (:roundtrip display)

  (def repl-server (repl-server-create))

  (defer (:close repl-server)
    (forever (:dispatch display))))
