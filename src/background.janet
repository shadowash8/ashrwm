(import ./color)

(defn manage [bg output wm]
  (:sync-next-commit (bg :shell-surface))
  (:place-bottom (bg :node))
  (:set-position (bg :node) (output :x) (output :y))
  (def buffer (:create-u32-rgba-buffer
                ((wm :registry) :single-pixel)
                ;(color/rgb-to-u32-rgba ((wm :config) :background))))
  (:attach (bg :surface) buffer 0 0)
  (:damage-buffer (bg :surface) 0 0 0x7fff_ffff 0x7fff_ffff)
  (:set-destination (bg :viewport) (output :w) (output :h))
  (:commit (bg :surface))
  (:destroy buffer))

(defn create [registry]
  (def surface (:create-surface (registry :compositor)))
  (def viewport (:get-viewport (registry :viewporter) surface))
  (def shell-surface (:get-shell-surface (registry :rwm) surface))
  @{:surface surface
    :viewport viewport
    :shell-surface shell-surface
    :node (:get-node shell-surface)})
