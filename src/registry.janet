(import wayland :as wl)

(defn- handle-event [obj event registry]
  (match event
    [:global name interface version]
    (case interface
      "wl_compositor" (put registry :compositor (:bind obj name interface 1))
      "wp_viewporter" (put registry :viewporter (:bind obj name interface 1))
      "wp_single_pixel_buffer_manager_v1" (put registry :single-pixel (:bind obj name interface 1))
      "river_window_manager_v1" (put registry :wm (:bind obj name interface 1)))))

(defn- init [registry display]
  (def wl-registry (:get-registry display))
  (:set-listener wl-registry handle-event registry)

  (:roundtrip display)

  (assert (registry :compositor))
  (assert (registry :viewporter))
  (assert (registry :single-pixel))
  (assert (registry :wm)))

(def registry
  @{:init init})
