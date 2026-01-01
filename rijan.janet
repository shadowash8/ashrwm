(import protocols)
(import wayland)
(import spork/netrepl)

(import ./src/wm)

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

(def wm @{:config config})

(def registry @{:outputs @{}
                :seats @{}})

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

  (wm/init wm registry)

  # Do a roundtrip to give the compositor the chance to send the
  # :unavailable event before creating the repl server and potentially
  # overwriting the repl socket of an already running rijan instance.
  (:roundtrip display)

  (def repl-server (repl-server-create))

  (defer (:close repl-server)
    (forever (:dispatch display))))
