(import wayland :as wl)

(defn- handle-event [obj event output]
  (match event
    [:removed] (put output :removed true)
    [:position x y] (do (put output :x x) (put output :y y))
    [:dimensions w h] (do (put output :w w) (put output :h h))

    (printf "Ignoring event %p" event)))

(defn create [obj]
  (def output @{:obj obj})
  (:set-listener obj handle-event output)
  output)
