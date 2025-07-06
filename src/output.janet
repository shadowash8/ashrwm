(import ./background)

(defn manage-start [output]
  (if (output :removed)
    (do
      (:destroy (output :obj))
      (background/destroy (output :background)))
    output))

(defn manage [output wm]
  (background/manage (output :background) output wm))

(defn manage-finish [output]
  (put output :new nil))

(defn- handle-event [obj event output]
  (match event
    [:removed] (put output :removed true)
    [:wl-output wl-output] (put output :wl-output wl-output)
    [:position x y] (do (put output :x x) (put output :y y))
    [:dimensions w h] (do (put output :w w) (put output :h h))
    (printf "Ignoring event %p" event)))

(defn create [obj registry]
  (def output @{:obj obj
                :background (background/create registry)
                :new true})
  (:set-listener obj handle-event output)
  output)
