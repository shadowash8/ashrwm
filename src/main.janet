(import wayland)
(import spork/netrepl)

(import ./registry)
(import ./wm)

(def interfaces
  (wayland/scan
    :system-protocols ["stable/viewporter/viewporter.xml"
                       "staging/single-pixel-buffer/single-pixel-buffer-v1.xml"]
    :custom-protocols ["../river/protocol/river-window-management-v1.xml"]))

(def config @{:background 0x002b36
              :border-normal 0x586e75
              :border-focused 0x93a1a1})

(def wm @{:config config})

(defn main [&]
  (def display (wayland/connect interfaces))

  (def registry (registry/create display))

  (wm/init wm registry)

  (def repl-server
    (netrepl/server "127.0.0.1" "9365" (fiber/getenv (fiber/current))))

  (forever (:dispatch display)))
