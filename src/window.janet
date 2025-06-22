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
    (put window :parent (:get-user-data parent))))

(defn create [obj]
  (def window @{:obj obj
                :node (:get-node obj)
                :closed false
                :min-w 0 :min-h 0 :max-w 0 :max-h 0
                :w 0 :h 0
                :app-id nil
                :title nil})
  (:set-listener obj handle-event window)
  (:set-user-data obj window)
  window)
