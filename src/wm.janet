(import wayland :as wl)

(import ./window)
(import ./output)
(import ./seat)

(defn- manage [wm]
  (update wm :outputs |(keep :manage-start $))
  (update wm :seats |(keep :manage-start $))
  (update wm :windows |(keep :manage-start $))

  (map |(:manage $ wm) (wm :outputs))
  (map |(:manage $ wm) (wm :seats))
  (map |(:manage $ wm) (wm :windows))

  (map (fn [window]
         (:propose-dimensions (window :obj) 200 200)) (wm :windows))

  (map :manage-finish (wm :outputs))
  (map :manage-finish (wm :seats))
  (map :manage-finish (wm :windows))

  (:manage-finish ((wm :registry) :rwm)))

(defn- render [wm]
  (map |(:render $ wm) (wm :windows))
  (:render-finish ((wm :registry) :rwm)))

(defn- handle-event [obj event wm]
  (match event
    [:unavailable] (do
                     (print "another window manager is already running")
                     (os/exit 1))
    [:finished] (error "unreachable")
    [:manage-start] (manage wm)
    [:render-start] (render wm)
    [:output obj] (array/push (wm :outputs) (output/create obj))
    [:seat obj] (array/push (wm :seats) (seat/create obj))
    [:window obj] (array/push (wm :windows) (window/create obj))))


(defn init [wm registry]
  (put wm :registry registry)
  (put wm :outputs @[])
  (put wm :seats @[])
  (put wm :windows @[])
  (:set-listener (registry :rwm) handle-event wm))
