(defn- make-bin-source
  [image-file declarations lookup-into-invocations no-core]
  (string
    declarations
    ```
#include <stddef.h>
static const unsigned char bytes[] = {
#embed "``` image-file ```"
};
const unsigned char * const janet_payload_image_embed = bytes;
const size_t janet_payload_image_embed_size = sizeof(bytes);

int main(int argc, const char **argv) {

#if defined(JANET_PRF)
    uint8_t hash_key[JANET_HASH_KEY_SIZE + 1];
#ifdef JANET_REDUCED_OS
    char *envvar = NULL;
#else
    char *envvar = getenv("JANET_HASHSEED");
#endif
    if (NULL != envvar) {
        strncpy((char *) hash_key, envvar, sizeof(hash_key) - 1);
    } else if (janet_cryptorand(hash_key, JANET_HASH_KEY_SIZE) != 0) {
        fputs("unable to initialize janet PRF hash function.\n", stderr);
        return 1;
    }
    janet_init_hash_key(hash_key);
#endif

    janet_init();

    ```
    (if no-core
      ```
    /* Get core env */
    JanetTable *env = janet_table(8);
    JanetTable *lookup = janet_core_lookup_table(NULL);
    JanetTable *temptab;
    int handle = janet_gclock();
    ```
      ```
    /* Get core env */
    JanetTable *env = janet_core_env(NULL);
    JanetTable *lookup = janet_env_lookup(env);
    JanetTable *temptab;
    int handle = janet_gclock();
    ```)
    lookup-into-invocations
    ```
    /* Unmarshal bytecode */
    Janet marsh_out = janet_unmarshal(
      janet_payload_image_embed,
      janet_payload_image_embed_size,
      0,
      lookup,
      NULL);

    /* Verify the marshalled object is a function */
    if (!janet_checktype(marsh_out, JANET_FUNCTION)) {
        fprintf(stderr, "invalid bytecode image - expected function.");
        return 1;
    }
    JanetFunction *jfunc = janet_unwrap_function(marsh_out);

    /* Check arity */
    janet_arity(argc, jfunc->def->min_arity, jfunc->def->max_arity);

    /* Collect command line arguments */
    JanetArray *args = janet_array(argc);
    for (int i = 0; i < argc; i++) {
        janet_array_push(args, janet_cstringv(argv[i]));
    }

    /* Create enviornment */
    temptab = env;
    janet_table_put(temptab, janet_ckeywordv("args"), janet_wrap_array(args));
    janet_table_put(temptab, janet_ckeywordv("executable"), janet_cstringv(argv[0]));
    janet_gcroot(janet_wrap_table(temptab));

    /* Unlock GC */
    janet_gcunlock(handle);

    /* Run everything */
    JanetFiber *fiber = janet_fiber(jfunc, 64, argc, argc ? args->data : NULL);
    fiber->env = temptab;
#ifdef JANET_EV
    janet_gcroot(janet_wrap_fiber(fiber));
    janet_schedule(fiber, janet_wrap_nil());
    janet_loop();
    int status = janet_fiber_status(fiber);
    janet_deinit();
    return status;
#else
    Janet out;
    JanetSignal result = janet_continue(fiber, janet_wrap_nil(), &out);
    if (result != JANET_SIGNAL_OK && result != JANET_SIGNAL_EVENT) {
      janet_stacktrace(fiber, out);
      janet_deinit();
      return result;
    }
    janet_deinit();
    return 0;
#endif
}

```))

(def [_ main-file image-file out-file & args] (dyn :args))

(def mods @{})
(var i 0)
(while (< i (length args))
  (case (args i)
    "--source" (do
                 (def name (args (++ i)))
                 (def path (args (++ i)))
                 (put mods name {:kind :source
                                 :path path}))
    "--image" (do
                (def name (args (++ i)))
                (def path (args (++ i)))
                (put mods name {:kind :image
                                :path path}))
    "--native" (do
                 (def name (args (++ i)))
                 (def entry (args (++ i)))
                 (def path (args (++ i)))
                 (put mods name @{:kind :native
                                  :entry entry
                                  :path path}))
    (error "unexpected arg"))
  (++ i))

(def module-paths (filter |(let [pattern (first $)]
                             (not (and (string? pattern)
                                       (string/find ":sys:" pattern))))
                          module/paths))
(each [name info] (pairs mods)
  (array/push module-paths [|(if (= $ name) (info :path)) (info :kind)]))

(def module-cache @{})
(def env (make-env))
(put env *module-paths* module-paths)
(put env *module-make-env* (fn :module-make-env [&opt e] (default e env) (make-env e)))
(put env *module-cache* module-cache)
(dofile main-file :env env)
(def main (module/value env 'main))

(def mdict (invert (env-lookup root-env)))

(loop [[name m] :pairs module-cache
       :let [n (m :native)]
       :when n
       :let [prefix (gensym)]]
  (def info (find |(= name ($ :path)) mods))
  (assert (= :native (info :kind)))
  (put info :prefix prefix)
  (def oldproto (table/getproto m))
  (table/setproto m nil)
  (loop [[sym value] :pairs (env-lookup m)]
    (put mdict value (symbol prefix sym)))
  (table/setproto m oldproto))

(def declarations @"#include <janet.h>\n")
(def lookup-into-invocations @"")
(each info mods
  (when (= :native (info :kind))
    (buffer/push-string declarations
                        "extern void "
                        (info :entry)
                        "(JanetTable *);\n")
    (buffer/push-string lookup-into-invocations
                        "    temptab = janet_table(0);\n"
                        "    temptab->proto = env;\n"
                        "    " (info :entry) "(temptab);\n"
                        "    janet_env_lookup_into(lookup, temptab, \""
                        (info :prefix)
                        "\", 0);\n\n")))

(spit image-file (marshal main mdict))
(spit out-file (make-bin-source image-file declarations lookup-into-invocations false))

(os/exit 0)
