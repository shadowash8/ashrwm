(import wayland :as wl)

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

  (:update-windowing-finish ((wm :registry) :rwm)))

(defn- update-rendering [wm]
  (map |(:update-rendering $ wm) (wm :windows))
  (:update-rendering-finish ((wm :registry) :rwm)))

(defn- handle-event [obj event wm]
  (match event
    [:unavailable] (do
                     (print "another window manager is already running")
                     (os/exit 1))
    [:finished] (error "unreachable")
    [:update-windowing-start] (update-windowing wm)
    [:update-rendering-start] (update-rendering wm)
    [:output obj] (array/push (wm :outputs) (output/create obj))
    [:seat obj] (array/push (wm :seats) (seat/create obj))
    [:window obj] (array/push (wm :windows) (window/create obj))))


(defn init [wm registry]
  (put wm :registry registry)
  (put wm :outputs @[])
  (put wm :seats @[])
  (put wm :windows @[])
  (:set-listener (registry :rwm) handle-event wm))
