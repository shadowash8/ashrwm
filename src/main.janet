(import wayland)

(import ./wm)

(use ./registry)

(def interfaces
  (wayland/scan
    :system-protocols ["stable/viewporter/viewporter.xml"
                       "staging/single-pixel-buffer/single-pixel-buffer-v1.xml"]
    :custom-protocols ["../river/protocol/river-window-management-v1.xml"]))

(defn main [&]
  (def display (wayland/connect interfaces))

  (:init registry display)

  (wm/create)

  (forever (:dispatch display)))
