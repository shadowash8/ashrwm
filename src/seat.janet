(import wayland :as wl)

(import ./window)
(import ./xkb-binding)
(import ./pointer-binding)

(defn- focus [seat window]
  (if window
    (do
      (:place-top (window :node))
      (:focus-window (seat :obj) (window :obj)))
    (:clear-focus (seat :obj)))
  (put seat :focused window))

(defn- action/target [wm seat dir]
  (if-let [window (seat :focused)
           i (assert (index-of window (wm :windows)))]
    (case dir
      :next (get (wm :windows) (+ i 1) (first (wm :windows)))
      :prev (get (wm :windows) (- i 1) (last (wm :windows)))
      (error "invalid dir"))
    (first (wm :windows))))

(defn- action/spawn [command]
  (fn [wm seat]
    (ev/spawn
      (os/proc-wait (os/spawn command :p)))))

(defn- action/close []
  (fn [wm seat]
    (if-let [window (seat :focused)]
      (:close (window :obj)))))

(defn- action/focus [dir]
  (fn [wm seat]
    (focus seat (action/target wm seat dir))))

(defn- action/float []
  (fn [wm seat]
    (if-let [window (seat :focused)]
      (window/set-float window (not (window :float))))))

(defn- action/move-start []
  (fn [wm seat]
    (unless (seat :op)
      (when-let [window (seat :pointer-target)]
        (focus seat window)
        (window/set-float window true)
        (:op-start-pointer (seat :obj))
        (put seat :op @{:type :move
                        :window window
                        :start-x (window :x) :start-y (window :y)
                        :dx 0 :dy 0})))))

(defn- action/resize-start []
  (fn [wm seat]
    (unless (seat :op)
      (when-let [window (seat :pointer-target)]
        (focus seat window)
        (window/set-float window true)
        (:op-start-pointer (seat :obj))
        (put seat :op @{:type :resize
                        :window window
                        :start-x (window :x) :start-y (window :y)
                        :start-w (window :w) :start-h (window :h)
                        :dx 0 :dy 0})))))

(defn- action/op-end []
  (fn [wm seat]
    (when-let [op (seat :op)]
      (:op-end (seat :obj))
      (put seat :op nil))))

(defn manage-start [seat]
  (if (seat :removed)
    (:destroy (seat :obj))
    seat))

(defn manage [seat wm]
  (when (seat :new)
    (xkb-binding/create seat :space {:mod4 true :mod1 true} (action/spawn ["foot"]))
    (xkb-binding/create seat :u {:mod4 true :mod1 true} (action/close))
    (xkb-binding/create seat :e {:mod4 true} (action/focus :prev))
    (xkb-binding/create seat :a {:mod4 true} (action/focus :next))
    (xkb-binding/create seat :t {:mod4 true :mod1 true} (action/float))
    (pointer-binding/create seat :left {:mod4 :true} (action/move-start) (action/op-end))
    (pointer-binding/create seat :right {:mod4 :true} (action/resize-start) (action/op-end)))

  (if (or (seat :new) (not (seat :focused-output)))
    (put seat :focused-output (first (wm :outputs))))

  (if-let [window (find |($ :new) (wm :windows))]
    (focus seat window))
  (if-let [window (seat :window-interaction)]
    (focus seat window))
  (if-let [window (seat :focused)]
    (if (window :closed)
      (focus seat nil)))
  (if (not (seat :focused))
    (focus seat (first (wm :windows))))

  (if-let [f (seat :pending-action)]
    (f wm seat))

  (when-let [op (seat :op)]
    (when (= :resize (op :type))
      # Resize from bottom right corner
      (window/propose-dimensions (op :window) wm
                                 (max 1 (+ (op :start-w) (op :dx)))
                                 (max 1 (+ (op :start-h) (op :dy)))))))

(defn manage-finish [seat]
  (put seat :new nil)
  (put seat :window-interaction nil)
  (put seat :pointer-activity nil)
  (put seat :pending-action nil))

(defn render [seat wm]
  (when-let [op (seat :op)]
    (when (= :move (op :type))
      (window/set-position (op :window) wm
                           (+ (op :start-x) (op :dx))
                           (+ (op :start-y) (op :dy))))))

(defn create [obj]
  (def seat @{:obj obj
              :new true})

  (defn handle-event [event]
    (match event
      [:removed] (put seat :removed true)
      [:wl-seat wl-seat] (put seat :wl-seat wl-seat)
      [:pointer-enter window] (put seat :pointer-target (:get-user-data window))
      [:pointer-leave] (put seat :pointer-target nil)
      [:pointer-activity] (put seat :pointer-activity true)
      [:window-interaction window] (put seat :window-interaction (:get-user-data window))
      [:op-delta dx dy] (do (put (seat :op) :dx dx) (put (seat :op) :dy dy))))

  (:set-handler obj handle-event)
  seat)
