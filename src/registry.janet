(defn- handle-event [obj event registry]
  (match event
    [:global name interface version]
    (case interface
      "wl_compositor" (put registry :compositor (:bind obj name interface 4)) # need 4 for attach-buffer
      "wp_viewporter" (put registry :viewporter (:bind obj name interface 1))
      "wp_single_pixel_buffer_manager_v1" (put registry :single-pixel (:bind obj name interface 1))
      # XXX check advertised version
      "wl_output" (put (registry :outputs) name (:bind obj name interface 4)) # need 4 for release
      "wl_seat" (put (registry :seats) name (:bind obj name interface 5)) # need 5 for release
      "river_window_manager_v1" (put registry :rwm (:bind obj name interface 1)))

    [:global-remove name]
    (do
      # XXX remove from wm outputs and seats arrays
      (if-let [output ((registry :outputs) name)]
        (:release output))
      (if-let [seat ((registry :seats) name)]
        (:release seat)))))

(defn create [display]
  (def registry @{:outputs @{}
                  :seats @{}})
  (def wl-registry (:get-registry display))
  (:set-listener wl-registry handle-event registry)

  (:roundtrip display)

  (assert (registry :compositor))
  (assert (registry :viewporter))
  (assert (registry :single-pixel))
  (assert (registry :rwm))

  registry)
