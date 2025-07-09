(import xkbcommon)

(defn create [seat keysym mods action]
  (def binding @{:obj (:get-xkb-binding (seat :obj) (xkbcommon/keysym keysym) mods)
                 :seat seat
                 :action action})

  (defn handle-event [event]
    (match event
      [:pressed] (put (binding :seat) :pending-action (binding :action))))

  (:set-handler (binding :obj) handle-event)
  (:enable (binding :obj)))
