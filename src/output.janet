(import ./background)

(defn visible [output windows]
  (let [tags (output :tags)]
    (filter |(tags ($ :tag)) windows)))

(defn usable-area [output]
  (if-let [[x y w h] (output :non-exclusive-area)]
    {:x (+ x (output :x)) :y (+ y (output :y)) :w w :h h}
    {:x (output :x) :y (output :y) :w (output :w) :h (output :h)}))

(defn manage-start [output]
  (if (output :removed)
    (do
      (:destroy (output :obj))
      (background/destroy (output :background)))
    output))

(defn manage [output wm]
  (background/manage (output :background) output wm)
  (when (output :new)
    (let [unused (find (fn [tag] (not (find |(($ :tags) tag) (wm :outputs)))) (range 1 10))]
      (put (output :tags) unused true))))

(defn manage-finish [output]
  (put output :new nil))

(defn create [obj registry]
  (def output @{:obj obj
                :background (background/create registry)
                :layer-shell (:get-output (registry :layer-shell) obj)
                :new true
                :tags @{}
                :usable {:x 0 :y 0}})

  (defn handle-event [event]
    (match event
      [:removed] (put output :removed true)
      [:wl-output name] (put output :wl-output ((registry :outputs) name))
      [:position x y] (do (put output :x x) (put output :y y))
      [:dimensions w h] (do (put output :w w) (put output :h h))
      (error "unreachable")))

  (:set-handler obj handle-event)
  (:set-user-data obj output)

  (defn handle-layer-shell-event [event]
    (match event
      [:non-exclusive-area x y w h] (put output :non-exclusive-area [x y w h])
      (error "unreachable")))

  (:set-handler (output :layer-shell) handle-layer-shell-event)

  output)
