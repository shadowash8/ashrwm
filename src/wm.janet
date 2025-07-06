(import wayland :as wl)

(import ./window)
(import ./output)
(import ./seat)

(defn- manage [wm]
  (update wm :outputs |(keep output/manage-start $))
  (update wm :seats |(keep seat/manage-start $))
  (update wm :windows |(keep window/manage-start $))

  (map |(output/manage $ wm) (wm :outputs))
  (map |(seat/manage $ wm) (wm :seats))
  (map |(window/manage $ wm) (wm :windows))

  (map (fn [window]
         (:propose-dimensions (window :obj) 500 500)) (wm :windows))

  (map output/manage-finish (wm :outputs))
  (map seat/manage-finish (wm :seats))
  (map window/manage-finish (wm :windows))

  (:manage-finish ((wm :registry) :rwm)))

(defn- render [wm]
  (map |(window/render $ wm) (wm :windows))
  (:render-finish ((wm :registry) :rwm)))

(defn- handle-event [obj event wm]
  (match event
    [:unavailable] (do
                     (print "another window manager is already running")
                     (os/exit 1))
    [:finished] (error "unreachable")
    [:manage-start] (manage wm)
    [:render-start] (render wm)
    [:output obj] (array/push (wm :outputs) (output/create obj (wm :registry)))
    [:seat obj] (array/push (wm :seats) (seat/create obj))
    [:window obj] (array/push (wm :windows) (window/create obj))))

(defn init [wm registry]
  (put wm :registry registry)
  (put wm :outputs @[])
  (put wm :seats @[])
  (put wm :windows @[])
  (:set-listener (registry :rwm) handle-event wm))
