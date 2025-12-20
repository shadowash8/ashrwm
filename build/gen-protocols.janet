(def [_ out-file wayland-xml wayland-protocols river-protocols] (dyn :args))
(spit out-file (make-image (curenv)))
