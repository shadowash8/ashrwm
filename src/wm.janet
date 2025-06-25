(import wayland :as wl)

(use ./registry)

(import ./window)
(import ./output)
(import ./seat)

(defn- update-windowing [wm]
  (update wm :outputs |(keep :update-windowing-start $))
  (update wm :seats |(keep :update-windowing-start $))
  (update wm :windows |(keep :update-windowing-start $))

  (map |(:update-windowing $ wm) (wm :outputs))
  (map |(:update-windowing $ wm) (wm :seats))
  (map |(:update-windowing $ wm) (wm :windows))

  (map (fn [window]
         (:propose-dimensions (window :obj) 200 200)) (wm :windows))

  (map :update-windowing-finish (wm :outputs))
  (map :update-windowing-finish (wm :seats))
  (map :update-windowing-finish (wm :windows))

  (:update-windowing-finish (registry :wm)))

(defn- update-rendering [wm]
  (map |(:update-rendering $ wm) (wm :windows))
  (:update-rendering-finish (registry :wm)))

(defn- handle-event [obj event wm]
  (match event
    [:unavailable] (do
                     (print "another window manager is already running")
                     (os/exit 1))
    [:finished] (error "unreachable")
    [:update-windowing-start] (update-windowing wm)
    [:update-rendering-start] (update-rendering wm)
    [:window obj] (array/push (wm :windows) (window/create obj))
    [:output obj] (array/push (wm :outputs) (output/create obj))
    [:seat obj] (array/push (wm :seats) (seat/create obj))))

(defn create []
  (def wm @{:outputs @[]
            :seats @[]
            :windows @[]})
  (:set-listener (registry :wm) handle-event wm))
