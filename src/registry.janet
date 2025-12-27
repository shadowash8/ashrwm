(defn create [display]
  (def registry @{:outputs @{}
                  :seats @{}})
  (def obj (:get-registry display))

  (defn handle-event [event]
    (match event
      # XXX check advertised versions
      [:global name interface version]
      (case interface
        "wl_compositor"
        # need 4 for attach-buffer
        (put registry :compositor (:bind obj name interface 4))

        "wp_viewporter"
        (put registry :viewporter (:bind obj name interface 1))

        "wp_single_pixel_buffer_manager_v1"
        (put registry :single-pixel (:bind obj name interface 1))

        "river_window_manager_v1"
        (put registry :rwm (:bind obj name interface 2))

        "river_layer_shell_v1"
        (put registry :layer-shell (:bind obj name interface 1))

        "river_xkb_bindings_v1"
        (put registry :xkb-bindings (:bind obj name interface 1))

        "wl_output"
        # need 4 for release
        (put (registry :outputs) name (:bind obj name interface 4))

        "wl_seat"
        # need 5 for release
        (put (registry :seats) name (:bind obj name interface 5)))

      # XXX remove from wm outputs and seats arrays
      [:global-remove name]
      (do
        (if-let [output ((registry :outputs) name)]
          (:release output))
        (if-let [seat ((registry :seats) name)]
          (:release seat)))))

  (:set-handler obj handle-event)
  (:roundtrip display)

  (assert (registry :compositor))
  (assert (registry :viewporter))
  (assert (registry :single-pixel))
  (assert (registry :rwm))

  registry)
