# From /usr/include/linux/input-event-codes.h
(def- button-code {:left 0x110
                   :right 0x111
                   :middle 0x112})

(defn create [seat button mods action]
  (def binding @{:obj (:get-pointer-binding (seat :obj) (button-code button) mods)})

  (defn handle-event [event]
    (match event
      [:pressed] (put seat :pending-action [binding action])
      [:released] (do)
      (error "unreachable")))

  (:set-handler (binding :obj) handle-event)
  (:enable (binding :obj))

  (array/push (seat :pointer-bindings) binding))
