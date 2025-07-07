(import wayland :as wl)

(import ./color)

(defn set-position
  "Set position, adjusting for border width"
  [window wm x y]
  (def border-width ((wm :config) :border-width))
  (:set-position (window :node) (+ x border-width) (+ y border-width)))

(defn propose-dimensions
  "Propose dimensions, adjusting for border width"
  [window wm w h]
  (def border-width ((wm :config) :border-width))
  (:propose-dimensions (window :obj)
                       (max 1 (- w (* 2 border-width)))
                       (max 1 (- h (* 2 border-width)))))

(defn manage-start [window]
  (if (window :closed)
    (:destroy (window :obj))
    window))

(defn manage [window wm]
  (if (window :new)
    (:use-ssd (window :obj))))

(defn manage-finish [window]
  (put window :new nil)
  (put window :move-requested nil)
  (put window :resize-requested nil)
  (put window :fullscreen-requested nil))

(defn- set-borders [window status config]
  (def rgb (case status
             :normal (config :border-normal)
             :focused (config :border-focused)))
  (:set-borders (window :obj)
                {:left true :bottom :true :top :true :right true}
                (config :border-width)
                ;(color/rgb-to-u32-rgba rgb)))

(defn render [window wm]
  (if (find |(= ($ :focused) window) (wm :seats))
    (set-borders window :focused (wm :config))
    (set-borders window :normal (wm :config))))

(defn- handle-event [obj event window]
  (match event
    [:closed] (put window :closed true)
    [:dimensions-hint min-w min-h max-w max-h]
    (do
      (put window :min-w min-w)
      (put window :min-h min-h)
      (put window :max-w max-w)
      (put window :max-h max-h))
    [:dimensions w h]
    (do (put window :w w) (put window :h h))
    [:app-id app-id]
    (put window :app-id app-id)
    [:title title]
    (put window :title title)
    [:parent parent]
    (put window :parent (if parent (:get-user-data parent)))
    [:decoration-hint hint]
    (put window :decoration-hint hint)
    [:move-requested seat serial]
    (put window :move-requested {:seat (:get-user-data seat)
                                 :serial serial})
    [:resize-requested seat serial edges]
    (put window :resize-requested {:seat (:get-user-data seat)
                                   :serial serial
                                   :edges edges})
    [:fullscreen-requested output]
    (put window :fullscreen-requested [:enter (if output (:get-user-data output))])
    [:exit-fullscreen-requested]
    (put window :fullscreen-requested [:exit])))

(defn create [obj]
  (def window @{:obj obj
                :node (:get-node obj)
                :new true})
  (:set-listener obj handle-event window)
  window)
