(import wayland :as wl)

(defn- update-windowing-start [seat]
  (if (seat :removed)
    (:destroy (seat :obj))
    seat))

(defn- update-windowing [seat wm]
  # TODO create bindings
  (if (or (seat :new) (not (seat :focused-output)))
    (put seat :focused-output (first (wm :outputs))))

  (if-let [window (find |($ :new) (wm :windows))]
    (:focus seat window))
  (if-let [window (seat :window-interaction)]
    (:focus seat window))
  (if-let [window (seat :focused)]
    (if (window :closed)
      (:focus seat nil))))

(defn- update-windowing-finish [seat]
  (put seat :new nil)
  (put seat :window-interaction nil)
  (put seat :pointer-activity nil))

(defn- focus [seat window]
  (if window
    (:focus-window (seat :obj) (window :obj))
    (:clear-focus (seat :obj)))
  (put seat :focused window))

(def- seat-proto @{:update-windowing update-windowing
                   :update-windowing-start update-windowing-start
                   :update-windowing-finish update-windowing-finish
                   :focus focus})

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
  (def seat @{:obj obj
              :new true})
  (:set-listener obj handle-event seat)
  (table/setproto seat seat-proto))
