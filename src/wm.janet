(import wayland :as wl)

(import ./window)
(import ./output)
(import ./seat)

(defn- layout [wm]
  (def output (first (wm :outputs)))
  (def windows (filter |(not ($ :float)) (wm :windows)))
  (def side-count (- (length windows) 1))
  (def total-w (max 0 (- (output :w) (* 2 ((wm :config) :outer-padding)))))
  (def total-h (max 0 (- (output :h) (* 2 ((wm :config) :outer-padding)))))
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
       (map (fn [window box]
              (window/set-position window wm ;(slice box 0 2))
              (window/propose-dimensions window wm ;(slice box 2 4)))
            windows)))

(defn- manage [wm]
  (update wm :outputs |(keep output/manage-start $))
  (update wm :seats |(keep seat/manage-start $))
  (update wm :windows |(keep window/manage-start $))

  (map |(output/manage $ wm) (wm :outputs))
  (map |(seat/manage $ wm) (wm :seats))
  (map |(window/manage $ wm) (wm :windows))

  (layout wm)

  (map output/manage-finish (wm :outputs))
  (map seat/manage-finish (wm :seats))
  (map window/manage-finish (wm :windows))

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

  (defn handle-event [event]
    (match event
      [:unavailable] (do
                       (print "another window manager is already running")
                       (os/exit 1))
      [:finished] (error "unreachable")
      [:manage-start] (manage wm)
      [:render-start] (render wm)
      [:output obj] (array/push (wm :outputs) (output/create obj (wm :registry)))
      [:seat obj] (array/push (wm :seats) (seat/create obj))
      [:window obj] (array/push (wm :windows) (window/create obj))))

  (:set-handler (registry :rwm) handle-event))
