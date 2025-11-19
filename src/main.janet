(import wayland)
(import spork/netrepl)

(import ./registry)
(import ./wm)

(def interfaces
  (wayland/scan
    :system-protocols ["stable/viewporter/viewporter.xml"
                       "staging/single-pixel-buffer/single-pixel-buffer-v1.xml"]
    :custom-protocols ["../river/protocol/river-window-management-v1.xml"
                       "../river/protocol/river-layer-shell-v1.xml"
                       "../river/protocol/river-xkb-bindings-v1.xml"]))

(def config @{:background 0xffffff
              :border-width 2
              :border-normal 0x9f9f9f
              :border-focused 0x000000
              :outer-padding 4
              :inner-padding 4
              :main-ratio 0.60})

(def wm @{:config config})

(defn main [&]
  (def display (wayland/connect interfaces))

  # Avoid passing WAYLAND_DEBUG on to our children.
  # It only matters if it's set when the display is created.
  (os/setenv "WAYLAND_DEBUG" nil)

  (def registry (registry/create display))

  (wm/init wm registry)

  (def repl-server
    (netrepl/server "127.0.0.1" "9365" (fiber/getenv (fiber/current))))

  (forever (:dispatch display)))
