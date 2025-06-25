(import wayland :as wl)

(defn- update-windowing-start [output]
  (if (output :removed)
    (:destroy (output :obj))
    output))

(defn- update-windowing [output wm])

(defn- update-windowing-finish [output]
  (put output :new nil))

(def- output-proto @{:update-windowing-start update-windowing-start
                     :update-windowing update-windowing
                     :update-windowing-finish update-windowing-finish})

(defn- handle-event [obj event output]
  (match event
    [:removed] (put output :removed true)
    [:position x y] (do (put output :x x) (put output :y y))
    [:dimensions w h] (do (put output :w w) (put output :h h))

    (printf "Ignoring event %p" event)))

(defn create [obj]
  (def output @{:obj obj
                :new nil})
  (:set-listener obj handle-event output)
  (table/setproto output output-proto))
