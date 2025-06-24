(import wayland :as wl)

(defn- handle-event [obj event seat]
  (match event
    [:removed] (put seat :removed true)
    [:pointer-enter window] (put seat :pointer-target (:get-user-data window))
    [:pointer-leave] (put seat :pointer-target nil)
    [:pointer-activity] (put seat :pointer-activity true)
    [:window-interaction window] (put seat :window-interaction (:get-user-data window))
    [:op-delta dx dy] (do (put seat :op-dx dx) (put seat :op-dy dy))

    (printf "Ignoring event %p" event)))

(defn create [obj]
  (def seat @{:obj obj})
  (:set-listener obj handle-event seat)
  seat)
