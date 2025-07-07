(import xkbcommon)

(defn- handle-event [obj event binding]
  (match event
    [:pressed] (put (binding :seat) :pending-action (binding :action))))

(defn create [seat keysym mods action]
  (def binding @{:obj (:get-xkb-binding (seat :obj) (xkbcommon/keysym keysym) mods)
                 :seat seat
                 :action action})
  (:set-listener (binding :obj) handle-event binding)
  (:enable (binding :obj)))
