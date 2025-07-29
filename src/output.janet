(import ./background)

(defn visible [output windows]
  (let [tags (output :tags)]
    (filter |(tags ($ :tag)) windows)))

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

(defn create [obj registry]
  (def output @{:obj obj
                :background (background/create registry)
                :new true
                :tags @{1 true}})

  (defn handle-event [event]
    (match event
      [:removed] (put output :removed true)
      [:wl-output name] (put output :wl-output ((registry :outputs) name))
      [:position x y] (do (put output :x x) (put output :y y))
      [:dimensions w h] (do (put output :w w) (put output :h h))
      (error "unreachable")))

  (:set-handler obj handle-event)
  (:set-user-data obj output)
  output)
