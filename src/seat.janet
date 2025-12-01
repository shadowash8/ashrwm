(import ./output)
(import ./window)
(import ./xkb-binding)
(import ./pointer-binding)

(defn- focus-output [seat output]
  (unless (= output (seat :focused-output))
    (put seat :focused-output output)
    (:set-default (output :layer-shell))))

(defn- focus [seat wm window]
  (defn focus-window [window]
    (unless (= (seat :focused) window)
      (:focus-window (seat :obj) (window :obj))
      (put seat :focused window)
      (if-let [i (find-index |(= $ window) (wm :render-order))]
        (array/remove (wm :render-order) i))
      (array/push (wm :render-order) window)
      (:place-top (window :node))))

  (defn clear-focus []
    (when (seat :focused)
      (:clear-focus (seat :obj))
      (put seat :focused nil)))

  (defn focus-non-layer []
    (when window
      (when-let [output (window/output window wm)]
        (focus-output seat output)))
    (when-let [output (seat :focused-output)]
      (def visible (output/visible output (wm :render-order)))
      (cond
        (def fullscreen (last (filter |($ :fullscreen) visible)))
        (focus-window fullscreen)

        (and window ((output :tags) (window :tag))) (focus-window window)

        (def top-visible (last visible)) (focus-window top-visible)

        (clear-focus))))

  (case (seat :layer-focus)
    :exclusive (put seat :focused nil)
    :non-exclusive (if window
                     (do
                       (put seat :layer-focus :none)
                       (focus-non-layer))
                     (put seat :focused nil))
    :none (focus-non-layer)))

(defn- pointer-move [seat wm window]
  (unless (seat :op)
    (focus seat wm window)
    (window/set-float window true)
    (:op-start-pointer (seat :obj))
    (put seat :op @{:type :move
                    :window window
                    :start-x (window :x) :start-y (window :y)
                    :dx 0 :dy 0})))

(defn- pointer-resize [seat wm window edges]
  (unless (seat :op)
    (focus seat wm window)
    (window/set-float window true)
    (:op-start-pointer (seat :obj))
    (put seat :op @{:type :resize
                    :window window
                    :edges edges
                    :start-x (window :x) :start-y (window :y)
                    :start-w (window :w) :start-h (window :h)
                    :dx 0 :dy 0})))

(defn- action/target [wm seat dir]
  (when-let [window (seat :focused)
             output (window/output window wm)
             visible (output/visible output (wm :windows))
             i (assert (index-of window visible))]
    (case dir
      :next (get visible (+ i 1) (first visible))
      :prev (get visible (- i 1) (last visible))
      (error "invalid dir"))))

(defn- action/spawn [command]
  (fn [wm seat binding]
    (ev/spawn
      (os/proc-wait (os/spawn command :p)))))

(defn- action/close []
  (fn [wm seat binding]
    (if-let [window (seat :focused)]
      (:close (window :obj)))))

(defn- action/zoom []
  (fn [wm seat binding]
    (when-let [focused (seat :focused)
               output (window/output focused wm)
               visible (output/visible output (wm :windows))
               target (if (= focused (first visible)) (get visible 1) focused)
               i (assert (index-of target (wm :windows)))]
      (array/remove (wm :windows) i)
      (array/insert (wm :windows) 0 target))))

(defn- action/focus [dir]
  (fn [wm seat binding]
    (focus seat wm (action/target wm seat dir))))

(defn- action/focus-output []
  (fn [wm seat binding]
    (when-let [focused (seat :focused-output)
               i (assert (index-of focused (wm :outputs)))
               target (or (get (wm :outputs) (+ i 1))
                          (first (wm :outputs)))]
      (focus-output seat target)
      (focus seat wm nil))))

(defn- action/float []
  (fn [wm seat binding]
    (if-let [window (seat :focused)]
      (window/set-float window (not (window :float))))))

(defn- action/fullscreen []
  (fn [wm seat binding]
    (if-let [window (seat :focused)]
      (if (window :fullscreen)
        (window/set-fullscreen window nil)
        (window/set-fullscreen window (window/output window wm))))))

(defn- action/set-tag [tag]
  (fn [wm seat binding]
    (if-let [window (seat :focused)]
      (put window :tag tag))))

(defn- fallback-tags [outputs]
  (for tag 1 10
    (unless (find |(($ :tags) tag) outputs)
      (when-let [output (find |(empty? ($ :tags)) outputs)]
        (put (output :tags) tag true)))))

(defn- action/focus-tag [tag]
  (fn [wm seat binding]
    (when-let [output (seat :focused-output)]
      (map |(put ($ :tags) tag nil) (wm :outputs))
      (put output :tags @{tag true})
      (fallback-tags (wm :outputs)))))

(defn- action/toggle-tag [tag]
  (fn [wm seat binding]
    (when-let [output (seat :focused-output)]
      (if ((output :tags) tag)
        (put (output :tags) tag nil)
        (do
          (map |(put ($ :tags) tag nil) (wm :outputs))
          (put (output :tags) tag true)))
      (fallback-tags (wm :outputs)))))

(defn- action/focus-all-tags []
  (fn [wm seat binding]
    (when-let [output (seat :focused-output)]
      (map |(put $ :tags @{}) (wm :outputs))
      (put output :tags (table ;(mapcat |[$ true] (range 1 10)))))))

(defn- action/pointer-move []
  (fn [wm seat binding]
    (when-let [window (seat :pointer-target)]
      (:pointer-move seat wm window))))

(defn- action/pointer-resize []
  (fn [wm seat binding]
    (when-let [window (seat :pointer-target)]
      (:pointer-resize seat wm window {:bottom true :left true}))))

(defn- action/passthrough []
  (fn [wm seat binding]
    (put binding :passthrough (not (binding :passthrough)))
    (def request (if (binding :passthrough) :disable :enable))
    (each other (seat :xkb-bindings)
      (unless (= other binding)
        (request (other :obj))))
    (each other (seat :pointer-bindings)
      (unless (= other binding)
        (request (other :obj))))))

(defn manage-start [seat]
  (if (seat :removed)
    (:destroy (seat :obj))
    seat))

(defn manage [seat wm]
  (when (seat :new)
    (xkb-binding/create wm seat :space {:mod4 true :mod1 true} (action/spawn ["footclient"]))
    (xkb-binding/create wm seat :l {:mod4 true} (action/spawn ["fuzzel"]))
    (xkb-binding/create wm seat :u {:mod4 true :mod1 true} (action/close))
    (xkb-binding/create wm seat :space {:mod4 true} (action/zoom))
    (xkb-binding/create wm seat :e {:mod4 true} (action/focus :prev))
    (xkb-binding/create wm seat :a {:mod4 true} (action/focus :next))
    (xkb-binding/create wm seat :h {:mod4 true} (action/focus-output))
    (xkb-binding/create wm seat :i {:mod4 true} (action/focus-output))
    (xkb-binding/create wm seat :t {:mod4 true} (action/fullscreen))
    (xkb-binding/create wm seat :t {:mod4 true :mod1 true} (action/float))
    (xkb-binding/create wm seat :p {:mod4 true} (action/spawn ["sh" "-c" "grim -g \"$(slurp)\" - | wl-copy"]))
    (xkb-binding/create wm seat :Escape {:mod4 true :mod1 true :shift true :ctrl true} (action/passthrough))
    (pointer-binding/create seat :left {:mod4 :true} (action/pointer-move))
    (pointer-binding/create seat :right {:mod4 :true} (action/pointer-resize))
    (for i 1 10
      (def keysym (keyword i))
      (xkb-binding/create wm seat keysym {:mod4 true} (action/focus-tag i))
      (xkb-binding/create wm seat keysym {:mod4 true :mod1 true} (action/set-tag i))
      (xkb-binding/create wm seat keysym {:mod4 true :mod1 true :shift true} (action/toggle-tag i)))
    (xkb-binding/create wm seat :0 {:mod4 true} (action/focus-all-tags)))

  (if (or (not (seat :focused-output))
          ((seat :focused-output) :removed))
    (focus-output seat (first (wm :outputs))))

  (focus seat wm nil)
  (each window (wm :windows)
    (when (window :new)
      (focus seat wm window)))
  (if-let [window (seat :window-interaction)]
    (focus seat wm window))

  (when-let [[binding action] (seat :pending-action)]
    (action wm seat binding))

  # Ensure focus is consistent after action (e.g. may have switched tags)
  (focus seat wm nil)

  (when-let [op (seat :op)]
    (when (= :resize (op :type))
      # Resize from bottom right corner
      (window/propose-dimensions (op :window) wm
                                 (max 1 (+ (op :start-w) (op :dx)))
                                 (max 1 (+ (op :start-h) (op :dy))))))
  (when (and (seat :op-release) (seat :op))
    (:op-end (seat :obj))
    (window/update-output ((seat :op) :window) wm)
    (put seat :op nil)))

(defn manage-finish [seat]
  (put seat :new nil)
  (put seat :window-interaction nil)
  (put seat :pointer-activity nil)
  (put seat :pending-action nil)
  (put seat :op-release nil))

(defn render [seat wm]
  (when-let [op (seat :op)]
    (when (= :move (op :type))
      (window/set-position (op :window) wm
                           (+ (op :start-x) (op :dx))
                           (+ (op :start-y) (op :dy))))))

(def proto @{:pointer-move pointer-move
             :pointer-resize pointer-resize})

(defn create [obj registry]
  (def seat @{:obj obj
              :layer-shell (:get-seat (registry :layer-shell) obj)
              :layer-focus :none
              :xkb-bindings @[]
              :pointer-bindings @[]
              :new true})

  (defn handle-event [event]
    (match event
      [:removed] (put seat :removed true)
      [:wl-seat wl-seat] (put seat :wl-seat wl-seat)
      [:pointer-enter window] (put seat :pointer-target (:get-user-data window))
      [:pointer-leave] (put seat :pointer-target nil)
      [:pointer-activity] (put seat :pointer-activity true)
      [:window-interaction window] (put seat :window-interaction (:get-user-data window))
      [:shell-surface-interaction shell_surface] (do)
      [:op-delta dx dy] (do (put (seat :op) :dx dx) (put (seat :op) :dy dy))
      [:op-release] (put seat :op-release true)
      (error "unreachable")))
  (:set-handler obj handle-event)
  (:set-user-data obj seat)

  (defn handle-layer-shell-event [event]
    (match event
      [:focus-exclusive] (put seat :layer-focus :exclusive)
      [:focus-non-exclusive] (put seat :layer-focus :non-exclusive)
      [:focus-none] (put seat :layer-focus :none)
      (error "unreachable")))
  (:set-handler (seat :layer-shell) handle-layer-shell-event)

  (table/setproto seat proto))
