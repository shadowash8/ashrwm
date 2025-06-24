(import wayland :as wl)

(use ./registry)

(import ./window)
(import ./output)
(import ./seat)

(defn- update-windowing [wm]
  (->> (wm :windows)
       (map (fn [window]
              (:propose-dimensions (window :obj) 200 200)
              (:set-borders (window :obj) {:top true :bottom true} 8
                            (- (math/pow 2 32) 1) 0 0 (- (math/pow 2 32) 1)))))
  (:update-windowing-finish (registry :wm)))

(defn- update-rendering [wm]
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
    [:seat obj]) (array/push (wm :seats) (seat/create obj)))

(defn- init [wm]
  (:set-listener (registry :wm) handle-event wm))

(def wm @{:windows @[]
          :outputs @[]
          :seats @[]
          :init init})
