(import wayland :as wl)

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
                :closed false
                :min-w 0 :min-h 0 :max-w 0 :max-h 0
                :w 0 :h 0
                :app-id nil
                :title nil
                :parent nil
                :decoration-hint nil})
  (:set-listener obj handle-event window)
  window)
