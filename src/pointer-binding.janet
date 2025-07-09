# From /usr/include/linux/input-event-codes.h
(def- button-code {:left 0x110
                   :right 0x111
                   :middle 0x112})

(defn create [seat button mods action &opt release-action]
  (def binding @{:obj (:get-pointer-binding (seat :obj) (button-code button) mods)
                 :seat seat
                 :action action
                 :release-action release-action})

  (defn handle-event [event]
    (match event
      [:pressed] (put (binding :seat) :pending-action (binding :action))
      [:released] (put (binding :seat) :pending-action (binding :release-action))))

  (:set-handler (binding :obj) handle-event)
  (:enable (binding :obj)))
