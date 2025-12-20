(import ./window)
(import ./output)
(import ./seat)

(defn- show-hide [wm]
  (def all-tags @{})
  (each output (wm :outputs)
    (merge-into all-tags (output :tags))
    # Ensure the output on which windows are fullscreen is updated
    # if they become visible on a different output.
    (each window (wm :windows)
      (when (and (window :fullscreen)
                 ((output :tags) (window :tag)))
        (:fullscreen (window :obj) (output :obj)))))
  (each window (wm :windows)
    (if (all-tags (window :tag))
      (:show (window :obj))
      (:hide (window :obj)))))

(defn- layout [wm output]
  (def windows (filter |(not ($ :float)) (output/visible output (wm :windows))))
  (def side-count (- (length windows) 1))
  (def usable (output/usable-area output))
  (def total-w (max 0 (- (usable :w) (* 2 ((wm :config) :outer-padding)))))
  (def total-h (max 0 (- (usable :h) (* 2 ((wm :config) :outer-padding)))))
  (def main-w (if (= 0 side-count) total-w (math/round (* total-w ((wm :config) :main-ratio)))))
  (def side-w (- total-w main-w))
  (def side-h (div total-h side-count))
  (def side-h-rem (% total-h side-count))
  (->> (range (length windows))
       (map (fn [i]
              (case i
                0 [0 0 main-w total-h]
                1 [main-w 0 side-w (+ side-h side-h-rem)]
                [main-w (+ side-h-rem (* side-h (- i 1)))
                 side-w side-h])))
       (map (fn [[x y w h]]
              (def outer ((wm :config) :outer-padding))
              (def inner ((wm :config) :inner-padding))
              [(+ x outer inner) (+ y outer inner)
               (- w (* 2 inner)) (- h (* 2 inner))]))
       (map (fn [[x y w h]]
              [(+ x (usable :x)) (+ y (usable :y)) w h]))
       (map (fn [window box]
              (window/set-position window wm ;(slice box 0 2))
              (window/propose-dimensions window wm ;(slice box 2 4)))
            windows)))

(defn- manage [wm]
  (update wm :render-order |(->> $ (filter (fn [window] (not (window :closed))))))

  (update wm :outputs |(keep output/manage-start $))
  (update wm :windows |(keep window/manage-start $))
  (update wm :seats |(keep seat/manage-start $))

  (map |(output/manage $ wm) (wm :outputs))
  (map |(window/manage $ wm) (wm :windows))
  (map |(seat/manage $ wm) (wm :seats))

  (map |(layout wm $) (wm :outputs))
  (show-hide wm)

  (map output/manage-finish (wm :outputs))
  (map window/manage-finish (wm :windows))
  (map seat/manage-finish (wm :seats))

  (:manage-finish ((wm :registry) :rwm)))

(defn- render [wm]
  (map |(window/render $ wm) (wm :windows))
  (map |(seat/render $ wm) (wm :seats))
  (:render-finish ((wm :registry) :rwm)))

(defn init [wm registry]
  (put wm :registry registry)
  (put wm :outputs @[])
  (put wm :seats @[])
  (put wm :windows @[])
  # Windows in rendering order rather than window management order.
  # The last window in the array is rendered on top.
  (put wm :render-order @[])

  (defn handle-event [event]
    (match event
      [:unavailable] (do
                       (print "another window manager is already running")
                       (os/exit 1))
      [:finished] (os/exit 0)
      [:manage-start] (manage wm)
      [:render-start] (render wm)
      [:output obj] (array/push (wm :outputs) (output/create obj (wm :registry)))
      [:seat obj] (array/push (wm :seats) (seat/create obj (wm :registry)))
      [:window obj] (array/insert (wm :windows) 0 (window/create obj))))

  (:set-handler (registry :rwm) handle-event))
