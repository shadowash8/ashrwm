(import wayland :as wl)

(defn- update-windowing-start [window]
  (if (window :closed)
    (:destroy (window :obj))
    window))

(defn- update-windowing [window wm]
  (if (window :new)
    (:use-ssd (window :obj))))

(defn- update-windowing-finish [window]
  (put window :new nil)
  (put window :move-requested nil)
  (put window :resize-requested nil)
  (put window :fullscreen-requested nil))

(defn- set-borders [window status]
  (def rgb (case status
             :focused 0x93a1a1
             :normal 0x586e75))
  (:set-borders (window :obj)
                {:left true :bottom :true :top :true :right true}
                8
                (* (band 0xff (brushift rgb 16)) (/ 0xffff_ffff 0xff))
                (* (band 0xff (brushift rgb 8)) (/ 0xffff_ffff 0xff))
                (* (band 0xff rgb) (/ 0xffff_ffff 0xff))
                0xffff_ffff))

(defn- update-rendering [window wm]
  (if (find |(= ($ :focused) window) (wm :seats))
    (set-borders window :focused)
    (set-borders window :normal)))

(def- window-proto
  @{:update-windowing-start update-windowing-start
    :update-windowing update-windowing
    :update-windowing-finish update-windowing-finish
    :update-rendering update-rendering})

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
    (put window :fullscreen-requested [:exit])

    (printf "Ignoring event %p" event)))

(defn create [obj]
  (def window @{:obj obj
                :node (:get-node obj)
                :new true})
  (:set-listener obj handle-event window)
  (table/setproto window window-proto))
