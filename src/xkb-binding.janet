(import xkbcommon)

(defn create [wm seat keysym mods action]
  (def obj (:get-xkb-binding ((wm :registry) :xkb-bindings)
                             (seat :obj) (xkbcommon/keysym keysym) mods))
  (def binding @{:obj obj
                 :seat seat
                 :action action})

  (defn handle-event [event]
    (match event
      [:pressed] (put (binding :seat) :pending-action (binding :action))
      [:released] (do)
      (error "unreachable")))

  (:set-handler (binding :obj) handle-event)
  (:enable (binding :obj)))
