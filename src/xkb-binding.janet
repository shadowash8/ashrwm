(import xkbcommon)

(defn create [wm seat keysym mods action]
  (def binding @{:obj (:get-xkb-binding ((wm :registry) :xkb-bindings)
                                        (seat :obj) (xkbcommon/keysym keysym) mods)})

  (defn handle-event [event]
    (match event
      [:pressed] (put seat :pending-action [binding action])))

  (:set-handler (binding :obj) handle-event)
  (:enable (binding :obj))

  (array/push (seat :xkb-bindings) binding))
