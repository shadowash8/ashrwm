(import ./background)

(defn- manage-start [output]
  (if (output :removed)
    (:destroy (output :obj))
    output))

(defn- manage [output wm]
  (background/manage (output :background) output wm))

(defn- manage-finish [output]
  (put output :new nil))

(def- output-proto @{:manage-start manage-start
                     :manage manage
                     :manage-finish manage-finish})

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
  (table/setproto output output-proto))
