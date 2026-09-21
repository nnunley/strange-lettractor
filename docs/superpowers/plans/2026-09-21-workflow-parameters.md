# Workflow Input Parameters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a DOT workflow declare typed input parameters that a launch supplies and that are substituted into attribute values before the run begins.

**Architecture:** A new `attractor.parameters` namespace owns declaration parsing, value resolution, type coercion and string substitution. A substitution transform runs first in the transform pipeline, so every downstream consumer — the stylesheet transform, validation, the tool handler, workflow capture — sees an ordinary resolved graph and never learns parameters exist. Resolved values are mirrored into the run context and, when declared `:export`, into tool-node environments through the explicit-environment argument `exec_command` already accepts.

**Tech Stack:** let-go (Clojure dialect, `*.lg`), `clojure.edn` for declaration and params-file parsing, `clojure.test` for tests, `lgx` as the build and test runner.

**Spec:** `docs/rfc/draft-ndn-workflow-parameters-00.md`

## Global Constraints

- Every requirement ID below is from the spec. A task's exit criterion is its own tests passing **and** `make test` staying green (1336 tests, 10885 assertions at time of writing).
- Requirement IDs are permanent. Do not rename them; later RFCs and commits cite them.
- Parameter names match `param-name` from the spec's Formal Grammar: `LOWER *( LOWER / DIGIT / "_" )`.
- Types are exactly three: `:string`, `:int`, `[:enum "a" "b" ...]`. Do not add more.
- The `params` graph attribute MUST NOT itself be substituted into.
- Substitution leaves a reference whose parameter is declared but unsupplied in place; that is a launch error, not a validation error.
- Run one test namespace with `make run-<name>`, which maps to `attractor.<name>-test` (underscores in the filename become hyphens in the namespace).
- No Claude attribution in commit messages.

---

## File Structure

| File | Responsibility |
|---|---|
| `src/attractor/parameters.lg` (create) | Declarations, resolution, coercion, substitution, trust. The only new namespace. |
| `test/attractor/parameters_test.lg` (create) | Unit tests for the above. |
| `src/attractor/transforms.lg` (modify) | Prepend the substitution transform; record reference sites on the graph. |
| `src/attractor/validation.lg` (modify) | Three new rules appended to `built-in-rules`. |
| `src/attractor/pipeline.lg` (modify) | Resolve parameters in `prepare`; reject them on `resume`. |
| `src/attractor/cli.lg` (modify) | `--param`, `--params-file`, `--trust` on `run`, `validate`, `graph`. |
| `src/attractor/hub.lg` (modify) | Carry parameters and trust through `:workflow/run`; seed the context. |
| `src/attractor/handlers.lg` (modify) | Pass exported parameters as the tool command's explicit environment. |
| `src/attractor/context.lg` (modify) | Persist and restore resolved parameters in the checkpoint. |
| `test/attractor/parameters_contract_test.lg` (create) | End-to-end: prepare, run, context, environment, checkpoint. |

---

### Task 1: Declaration parsing and its validation rule

Implements `[R-param-declaration]`, `[R-param-name-charset]`, `[R-legacy-params-rejected]`.

**Files:**
- Create: `src/attractor/parameters.lg`
- Create: `test/attractor/parameters_test.lg`
- Modify: `src/attractor/validation.lg` (add `rule-parameter-declaration`, append to `built-in-rules` in `validate`)

**Interfaces:**
- Produces: `(parameters/parse-declarations attr-value)` → `{:declarations [decl ...] :errors ["msg" ...]}`, where each `decl` is `{:name "editable" :type :string :default "solve.lg" :doc "" :export false :delegable false}` and `:type` is `:string`, `:int`, or `[:enum "a" "b"]`. A blank or absent attribute yields `{:declarations [] :errors []}`.
- Produces: `(parameters/valid-name? s)` → boolean.

- [ ] **Step 1: Write the failing tests**

```clojure
(ns attractor.parameters-test
  (:require [clojure.test :refer [deftest is testing]]
            [attractor.parameters :as parameters]))

(deftest parameter-names-are-lowercase-identifiers
  (doseq [good ["editable" "run_cmd" "max_iterations" "a1"]]
    (is (true? (parameters/valid-name? good)) good))
  (doseq [bad ["Editable" "run-cmd" "1st" "_leading" ""]]
    (is (false? (parameters/valid-name? bad)) bad)))

(deftest declarations-parse-into-records-with-defaults
  (let [res (parameters/parse-declarations
              "[{:name :editable :type :string :default \"solve.lg\" :export true}
                {:name :direction :type [:enum \"min\" \"max\"] :default \"min\" :delegable true}]")]
    (is (= [] (:errors res)))
    (is (= 2 (count (:declarations res))))
    (let [d (first (:declarations res))]
      (is (= "editable" (:name d)))
      (is (= :string (:type d)))
      (is (= "solve.lg" (:default d)))
      (is (true? (:export d)))
      (is (false? (:delegable d))))))

(deftest absent-params-attribute-declares-nothing
  (is (= {:declarations [] :errors []} (parameters/parse-declarations nil)))
  (is (= {:declarations [] :errors []} (parameters/parse-declarations "  "))))

(deftest duplicate-name-is-an-error
  (let [res (parameters/parse-declarations
              "[{:name :editable :type :string} {:name :editable :type :int}]")]
    (is (some #(clojure.string/includes? % "duplicate") (:errors res)))))

(deftest default-must-match-declared-type
  (let [res (parameters/parse-declarations
              "[{:name :max_iterations :type :int :default \"many\"}]")]
    (is (some #(clojure.string/includes? % "max_iterations") (:errors res)))))

(deftest unknown-type-is-an-error
  (let [res (parameters/parse-declarations "[{:name :x :type :duration}]")]
    (is (some #(clojure.string/includes? % "duration") (:errors res)))))

(deftest legacy-comma-separated-form-names-the-declaration-form
  (let [res (parameters/parse-declarations "task_file, target_dir, max_iterations")]
    (is (some #(clojure.string/includes? % "comma-separated") (:errors res)))
    (is (some #(clojure.string/includes? % ":name") (:errors res)))))
```

- [ ] **Step 2: Run the tests and watch them fail**

Run: `make run-parameters`
Expected: FAIL — the namespace `attractor.parameters` does not exist.

- [ ] **Step 3: Write the minimal implementation**

```clojure
(ns attractor.parameters
  (:require [clojure.string :as str]
            [clojure.edn :as edn]))

(def ^:private name-pattern #"[a-z][a-z0-9_]*")

(defn valid-name? [s]
  (boolean (and (string? s) (re-matches name-pattern s))))

(defn- enum-type? [t]
  (and (vector? t) (= :enum (first t)) (seq (rest t))
       (every? string? (rest t))))

(defn- known-type? [t]
  (or (= :string t) (= :int t) (enum-type? t)))

(defn- default-matches? [t v]
  (cond
    (= :string t) (string? v)
    (= :int t) (integer? v)
    (enum-type? t) (contains? (set (rest t)) v)
    :else false))

(defn- legacy-form? [text]
  ;; Upstream spells params as a bare comma-separated name list.
  (boolean (re-matches #"\s*[a-z][a-z0-9_]*(\s*,\s*[a-z][a-z0-9_]*)*\s*" text)))

(defn- read-one [raw]
  (let [nm (:name raw)
        nm (cond (keyword? nm) (name nm) (string? nm) nm :else nil)
        t (:type raw)]
    (cond
      (not (valid-name? nm))
      {:error (str "invalid parameter name: " (pr-str (:name raw)))}

      (not (known-type? t))
      {:error (str "parameter '" nm "' has unknown type " (pr-str t))}

      (and (contains? raw :default) (not (default-matches? t (:default raw))))
      {:error (str "parameter '" nm "' default " (pr-str (:default raw))
                   " is not a " (pr-str t))}

      :else
      {:declaration {:name nm :type t
                     :default (get raw :default)
                     :has_default (contains? raw :default)
                     :doc (or (:doc raw) "")
                     :export (true? (:export raw))
                     :delegable (true? (:delegable raw))}})))

(defn parse-declarations [attr-value]
  (let [text (str (or attr-value ""))]
    (if (str/blank? text)
      {:declarations [] :errors []}
      (if (legacy-form? text)
        {:declarations []
         :errors [(str "'params' is a comma-separated name list; this runtime "
                       "expects a vector of declarations, e.g. "
                       "[{:name :task_file :type :string}]")]}
        (let [parsed (try (edn/read-string text) (catch Object e {::bad (str e)}))]
          (cond
            (and (map? parsed) (contains? parsed ::bad))
            {:declarations [] :errors [(str "'params' is not readable EDN: " (::bad parsed))]}

            (not (vector? parsed))
            {:declarations [] :errors ["'params' must be a vector of declarations"]}

            :else
            (let [results (mapv read-one parsed)
                  decls (vec (keep :declaration results))
                  errs (vec (keep :error results))
                  dup (->> (map :name decls)
                           frequencies
                           (filter (fn [[_ n]] (> n 1)))
                           (map first)
                           sort)]
              {:declarations decls
               :errors (vec (concat errs
                                    (map #(str "duplicate parameter name '" % "'") dup)))})))))))
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: `make run-parameters`
Expected: PASS, all assertions.

- [ ] **Step 5: Add the validation rule**

In `src/attractor/validation.lg`, add `[attractor.parameters :as parameters]` to the `ns` requires, then add the rule beside `rule-stylesheet-syntax`:

```clojure
;; Rule: parameter_declaration
(defn rule-parameter-declaration [graph]
  (let [res (parameters/parse-declarations (get-in graph [:attrs :params]))]
    (mapv (fn [msg] {:rule "parameter_declaration" :severity :error :message msg})
          (:errors res))))
```

Append `rule-parameter-declaration` to the `built-in-rules` vector inside `validate`.

- [ ] **Step 6: Test the rule end to end**

Add to `test/attractor/parameters_test.lg`:

```clojure
(deftest validation-reports-declaration-errors
  (let [graph {:nodes {} :edges [] :attrs {:params "[{:name :x :type :duration}]"}}
        diags (filter #(= "parameter_declaration" (:rule %))
                      (attractor.validation/validate graph))]
    (is (= 1 (count diags)))
    (is (= :error (:severity (first diags))))))
```

Add `[attractor.validation]` to the test namespace requires.

Run: `make run-parameters && make run-validation`
Expected: PASS both.

- [ ] **Step 7: Commit**

```bash
git add src/attractor/parameters.lg test/attractor/parameters_test.lg src/attractor/validation.lg
git commit -m "feat(parameters): declarations parse and validate

Implements R-param-declaration, R-param-name-charset,
R-legacy-params-rejected. A params attribute in upstream's comma-separated
form is rejected by name, so an imported workflow says what to write
instead of failing as unreadable EDN."
```

---

### Task 2: Reference substitution over a string

Implements `[R-substitution-syntax]`.

**Files:**
- Modify: `src/attractor/parameters.lg`
- Modify: `test/attractor/parameters_test.lg`

**Interfaces:**
- Produces: `(parameters/substitute-string text values)` → `{:text "..." :used #{"name"}}`, where `values` is a map of parameter name to already-rendered string. A reference whose name is absent from `values` is left in place. `{{{{` yields a literal `{{`.

- [ ] **Step 1: Write the failing tests**

```clojure
(deftest substitution-replaces-references-and-leaves-shell-alone
  (let [vals {"editable" "solve.lg"}]
    (is (= "edit solve.lg" (:text (parameters/substitute-string "edit {{editable}}" vals))))
    (is (= "solve.lgsolve.lg"
           (:text (parameters/substitute-string "{{editable}}{{editable}}" vals))))
    (is (= "\"${LG:-lg}\" bench.lg"
           (:text (parameters/substitute-string "\"${LG:-lg}\" bench.lg" vals))))
    (is (= "$goal" (:text (parameters/substitute-string "$goal" vals))))
    (is (= "cost is {50}" (:text (parameters/substitute-string "cost is {50}" vals))))))

(deftest doubled-open-brace-is-an-escape
  (is (= "{{editable}}"
         (:text (parameters/substitute-string "{{{{editable}}" {"editable" "solve.lg"})))))

(deftest an-unsupplied-reference-is-left-in-place
  (is (= "edit {{editable}}" (:text (parameters/substitute-string "edit {{editable}}" {})))))

(deftest substitution-reports-which-names-it-used
  (is (= #{"editable"}
         (:used (parameters/substitute-string "a {{editable}} b" {"editable" "x"})))))
```

- [ ] **Step 2: Run the tests and watch them fail**

Run: `make run-parameters`
Expected: FAIL — `substitute-string` is not defined.

- [ ] **Step 3: Write the minimal implementation**

Append to `src/attractor/parameters.lg`:

```clojure
;; Scan once, left to right. "{{{{" emits a literal "{{" and consumes four
;; characters, so an escape can never be re-read as a reference.
(defn substitute-string [text values]
  (if-not (string? text)
    {:text text :used #{}}
    (loop [i 0 out [] used #{}]
      (cond
        (>= i (count text))
        {:text (apply str out) :used used}

        (and (<= (+ i 4) (count text)) (= "{{{{" (subs text i (+ i 4))))
        (recur (+ i 4) (conj out "{{") used)

        (and (<= (+ i 2) (count text)) (= "{{" (subs text i (+ i 2))))
        (let [close (str/index-of text "}}" (+ i 2))
              nm (when close (subs text (+ i 2) close))]
          (if (and close (valid-name? nm) (contains? values nm))
            (recur (+ close 2) (conj out (get values nm)) (conj used nm))
            (recur (+ i 2) (conj out "{{") used)))

        :else
        (recur (inc i) (conj out (subs text i (inc i))) used)))))
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: `make run-parameters`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/attractor/parameters.lg test/attractor/parameters_test.lg
git commit -m "feat(parameters): substitute doubled-brace references in a string

Implements R-substitution-syntax. Shell variables and Graphviz record-label
braces pass through untouched, which is the reason the syntax is doubled
braces rather than \$name."
```

---

### Task 3: The substitution transform, running first

Implements `[R-substitution-order]`, `[R-substitution-scope]`.

**Files:**
- Modify: `src/attractor/parameters.lg`
- Modify: `src/attractor/transforms.lg`
- Modify: `test/attractor/parameters_test.lg`

**Interfaces:**
- Consumes: `parameters/substitute-string` from Task 2.
- Produces: `(parameters/substitution-transform values)` → a function `(fn [graph] graph')`. It rewrites every string value in `(:attrs graph)`, in each node map and its `:attrs`, and in each edge map and its `:attrs`, skipping the key `:params`. It attaches `:parameter_references` to the graph: a map of parameter name to a set of attribute keys it was substituted into.
- Produces: `(transforms/apply-transforms graph custom-transforms parameter-values)` — a third arity that prepends the substitution transform.

- [ ] **Step 1: Write the failing tests**

```clojure
(deftest substitution-transform-rewrites-graph-node-and-edge-attributes
  (let [graph {:model_stylesheet ".r { llm_model: {{model}}; }"
               :goal "make {{editable}} fast"
               :attrs {:params "[{:name :model :type :string}]"
                       :model_stylesheet ".r { llm_model: {{model}}; }"}
               :nodes {"run" {:id "run" :timeout "{{budget}}"
                              :tool_command "sh ar.sh {{editable}}"
                              :attrs {:tool_command "sh ar.sh {{editable}}"}}}
               :edges [{:from "run" :to "exit" :condition "param.direction = {{direction}}"
                        :attrs {:condition "param.direction = {{direction}}"}}]}
        out ((parameters/substitution-transform
               {"model" "haiku" "editable" "solve.lg" "budget" "30s" "direction" "max"})
             graph)]
    (is (= ".r { llm_model: haiku; }" (:model_stylesheet out)))
    (is (= "make solve.lg fast" (:goal out)))
    (is (= "30s" (get-in out [:nodes "run" :timeout])))
    (is (= "sh ar.sh solve.lg" (get-in out [:nodes "run" :tool_command])))
    (is (= "sh ar.sh solve.lg" (get-in out [:nodes "run" :attrs :tool_command])))
    (is (= "param.direction = max" (:condition (first (:edges out)))))))

(deftest the-params-attribute-is-never-substituted-into
  (let [graph {:attrs {:params "[{:name :x :type :string :default \"{{x}}\"}]"}
               :nodes {} :edges []}
        out ((parameters/substitution-transform {"x" "boom"}) graph)]
    (is (= "[{:name :x :type :string :default \"{{x}}\"}]" (get-in out [:attrs :params])))))

(deftest substitution-records-where-each-parameter-was-used
  (let [graph {:attrs {} :nodes {"a" {:id "a" :tool_command "{{p}}" :attrs {:tool_command "{{p}}"}}}
               :edges []}
        out ((parameters/substitution-transform {"p" "v"}) graph)]
    (is (contains? (get-in out [:parameter_references "p"]) :tool_command))))

(deftest substitution-runs-before-the-stylesheet-transform
  ;; The stylesheet transform resolves llm_model onto nodes. If substitution
  ;; ran after it, the node would carry the literal reference instead.
  (let [graph {:model_stylesheet ".r { llm_model: {{model}}; }"
               :attrs {} :edges []
               :nodes {"n" {:id "n" :class "r" :shape "box" :attrs {}}}}
        out (attractor.transforms/apply-transforms graph [] {"model" "haiku"})]
    (is (= "haiku" (get-in out [:nodes "n" :llm_model])))))
```

Add `[attractor.transforms]` to the test namespace requires.

- [ ] **Step 2: Run the tests and watch them fail**

Run: `make run-parameters`
Expected: FAIL — `substitution-transform` is not defined.

- [ ] **Step 3: Write the minimal implementation**

Append to `src/attractor/parameters.lg`:

```clojure
(defn- rewrite-map [m values skip refs]
  (reduce (fn [[acc r] [k v]]
            (if (or (contains? skip k) (not (string? v)))
              [(assoc acc k v) r]
              (let [{:keys [text used]} (substitute-string v values)]
                [(assoc acc k text)
                 (reduce (fn [rr nm] (update rr nm (fnil conj #{}) k)) r used)])))
          [{} refs]
          m))

(defn substitution-transform [values]
  (fn [graph]
    (let [skip #{:params}
          [top refs] (rewrite-map (dissoc graph :nodes :edges :attrs) values #{} {})
          [attrs refs] (rewrite-map (or (:attrs graph) {}) values skip refs)
          [nodes refs]
          (reduce (fn [[acc r] [nid node]]
                    (let [[n r1] (rewrite-map (dissoc node :attrs) values #{} r)
                          [na r2] (rewrite-map (or (:attrs node) {}) values skip r1)]
                      [(assoc acc nid (assoc n :attrs na)) r2]))
                  [{} refs]
                  (or (:nodes graph) {}))
          [edges refs]
          (reduce (fn [[acc r] edge]
                    (let [[e r1] (rewrite-map (dissoc edge :attrs) values #{} r)
                          [ea r2] (rewrite-map (or (:attrs edge) {}) values skip r1)]
                      [(conj acc (assoc e :attrs ea)) r2]))
                  [[] refs]
                  (or (:edges graph) []))]
      (assoc top :attrs attrs :nodes nodes :edges (vec edges)
                 :parameter_references refs))))
```

- [ ] **Step 4: Add the transform arity**

In `src/attractor/transforms.lg`, add `[attractor.parameters :as parameters]` to the requires and replace `apply-transforms` with:

```clojure
(defn apply-transforms
  ([graph] (apply-transforms graph []))
  ([graph custom-transforms] (apply-transforms graph custom-transforms nil))
  ([graph custom-transforms parameter-values]
   ;; Substitution runs first so every later transform, validation rule and
   ;; handler reads an ordinary resolved graph.
   (let [leading (if parameter-values
                   [(parameters/substitution-transform parameter-values)]
                   [])
         all-transforms (concat leading default-transforms custom-transforms)]
     (reduce (fn [g t] (t g)) graph all-transforms))))
```

- [ ] **Step 5: Run the tests and watch them pass**

Run: `make run-parameters && make run-validation`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/attractor/parameters.lg src/attractor/transforms.lg test/attractor/parameters_test.lg
git commit -m "feat(parameters): substitute into the graph before every other transform

Implements R-substitution-order and R-substitution-scope. Running first is
what lets a parameter reach model_stylesheet and timeout, which are read
before any node runs."
```

---

### Task 4: The undeclared-reference rule

Implements `[R-undeclared-reference]`.

**Files:**
- Modify: `src/attractor/parameters.lg`
- Modify: `src/attractor/validation.lg`
- Modify: `test/attractor/parameters_test.lg`

**Interfaces:**
- Consumes: `parameters/parse-declarations` (Task 1).
- Produces: `(parameters/find-references graph)` → `[{:name "x" :node_id "guard" :attr :tool_command} ...]` for every `{{name}}` remaining in the graph after substitution. `:node_id` is `nil` for a graph-level attribute; an edge carries `:edge [from to]`.

A reference to a *declared* parameter is left alone here — that means no value was supplied, which the launch path reports (Task 5), not validation.

- [ ] **Step 1: Write the failing tests**

```clojure
(deftest undeclared-references-are-validation-errors
  (let [graph {:attrs {:params "[{:name :editable :type :string}]"}
               :nodes {"guard" {:id "guard" :tool_command "sh ar.sh {{editble}}"
                                :attrs {:tool_command "sh ar.sh {{editble}}"}}}
               :edges []}
        diags (filter #(= "parameter_reference" (:rule %))
                      (attractor.validation/validate graph))]
    (is (= 1 (count diags)))
    (is (clojure.string/includes? (:message (first diags)) "editble"))
    (is (clojure.string/includes? (:message (first diags)) "guard"))))

(deftest a-declared-but-unsupplied-reference-is-not-a-validation-error
  (let [graph {:attrs {:params "[{:name :editable :type :string}]"}
               :nodes {"guard" {:id "guard" :tool_command "sh ar.sh {{editable}}"
                                :attrs {:tool_command "sh ar.sh {{editable}}"}}}
               :edges []}]
    (is (empty? (filter #(= "parameter_reference" (:rule %))
                        (attractor.validation/validate graph))))))
```

- [ ] **Step 2: Run the tests and watch them fail**

Run: `make run-parameters`
Expected: FAIL — no `parameter_reference` diagnostics are produced.

- [ ] **Step 3: Write the minimal implementation**

Append to `src/attractor/parameters.lg`:

```clojure
(defn- refs-in [text]
  (if-not (string? text)
    []
    (loop [i 0 found []]
      (let [open (str/index-of text "{{" i)]
        (if (nil? open)
          found
          (if (and (<= (+ open 4) (count text)) (= "{{{{" (subs text open (+ open 4))))
            (recur (+ open 4) found)
            (let [close (str/index-of text "}}" (+ open 2))
                  nm (when close (subs text (+ open 2) close))]
              (if (and close (valid-name? nm))
                (recur (+ close 2) (conj found nm))
                (recur (+ open 2) found)))))))))

(defn find-references [graph]
  (let [scan (fn [m where]
               (mapcat (fn [[k v]]
                         (map (fn [nm] (merge {:name nm :attr k} where)) (refs-in v)))
                       m))]
    (vec (concat
           (scan (dissoc graph :nodes :edges :attrs :parameter_references) {})
           (scan (dissoc (or (:attrs graph) {}) :params) {})
           (mapcat (fn [[nid node]]
                     (concat (scan (dissoc node :attrs) {:node_id nid})
                             (scan (or (:attrs node) {}) {:node_id nid})))
                   (or (:nodes graph) {}))
           (mapcat (fn [edge]
                     (let [where {:edge [(:from edge) (:to edge)]}]
                       (concat (scan (dissoc edge :attrs) where)
                               (scan (or (:attrs edge) {}) where))))
                   (or (:edges graph) []))))))
```

- [ ] **Step 4: Add the rule**

In `src/attractor/validation.lg`, beside `rule-parameter-declaration`:

```clojure
;; Rule: parameter_reference
(defn rule-parameter-reference [graph]
  (let [declared (set (map :name (:declarations (parameters/parse-declarations
                                                  (get-in graph [:attrs :params])))))]
    (vec (keep (fn [ref]
                 (when-not (contains? declared (:name ref))
                   (merge {:rule "parameter_reference" :severity :error
                           :message (str (if (:node_id ref)
                                           (str "node '" (:node_id ref) "' ")
                                           "graph ")
                                         "attribute '" (name (:attr ref))
                                         "' references undeclared parameter '"
                                         (:name ref) "'")}
                          (when (:node_id ref) {:node_id (:node_id ref)})
                          (when (:edge ref) {:edge (:edge ref)}))))
               (parameters/find-references graph)))))
```

Append `rule-parameter-reference` to `built-in-rules`.

- [ ] **Step 5: Run the tests and watch them pass**

Run: `make run-parameters && make run-validation`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/attractor/parameters.lg src/attractor/validation.lg test/attractor/parameters_test.lg
git commit -m "feat(parameters): reject a reference to an undeclared parameter

Implements R-undeclared-reference. A typo would otherwise substitute
nothing and leave a corrupted command to run."
```

---

### Task 5: Resolution, precedence, coercion and missing values

Implements `[R-value-precedence]`, `[R-type-coercion]`, `[R-missing-value]`.

**Files:**
- Modify: `src/attractor/parameters.lg`
- Modify: `test/attractor/parameters_test.lg`

**Interfaces:**
- Consumes: `parameters/parse-declarations` (Task 1).
- Produces: `(parameters/resolve-values declarations supplied)` → `{:values {"name" "rendered"} :typed {"name" v} :sources {"name" :flag} :errors [{:rule "parameter_missing" :message "..."}]}`. Each error carries the rule name the spec's error table assigns it — `parameter_missing`, `parameter_type` or `parameter_undeclared` — so `prepare` reports them as distinct categories rather than collapsing three failures into one. `supplied` is `{:file {"name" v} :flags {"name" "text"}}`. Precedence is flag, then file, then default, then error. Flag values arrive as text and are coerced; file values are already EDN-typed and are type-checked, not parsed.
- Produces: `(parameters/render v)` → the string a substitution writes: an integer in decimal, a string verbatim.

- [ ] **Step 1: Write the failing tests**

```clojure
(def ^:private decls
  (:declarations
    (parameters/parse-declarations
      "[{:name :editable :type :string :default \"solve.lg\"}
        {:name :run_cmd :type :string}
        {:name :direction :type [:enum \"min\" \"max\"] :default \"min\"}
        {:name :max_iterations :type :int :default 0}]")))

(deftest a-flag-beats-the-file-which-beats-the-default
  (let [res (parameters/resolve-values
              decls {:file {"direction" "max" "max_iterations" 7}
                     :flags {"direction" "min" "run_cmd" "sh bench.sh"}})]
    (is (= [] (:errors res)))
    (is (= "min" (get-in res [:values "direction"])))
    (is (= :flag (get-in res [:sources "direction"])))
    (is (= "7" (get-in res [:values "max_iterations"])))
    (is (= :file (get-in res [:sources "max_iterations"])))
    (is (= "solve.lg" (get-in res [:values "editable"])))
    (is (= :default (get-in res [:sources "editable"])))))

(deftest a-parameter-with-no-default-and-no-value-is-an-error
  (let [res (parameters/resolve-values decls {:file {} :flags {}})]
    (is (some #(and (= "parameter_missing" (:rule %))
                    (clojure.string/includes? (:message %) "run_cmd"))
              (:errors res)))))

(deftest flag-text-is-coerced-to-the-declared-type
  (let [ok (parameters/resolve-values decls {:file {} :flags {"run_cmd" "x" "max_iterations" "-1"}})]
    (is (= [] (:errors ok)))
    (is (= -1 (get-in ok [:typed "max_iterations"])))
    (is (= "-1" (get-in ok [:values "max_iterations"]))))
  (doseq [bad ["7.5" "many"]]
    (let [res (parameters/resolve-values decls {:file {} :flags {"run_cmd" "x" "max_iterations" bad}})]
      (is (some #(and (= "parameter_type" (:rule %))
                      (clojure.string/includes? (:message %) "max_iterations"))
                (:errors res)) bad))))

(deftest an-enum-error-names-the-allowed-values
  (doseq [bad ["Max" "middle"]]
    (let [res (parameters/resolve-values decls {:file {} :flags {"run_cmd" "x" "direction" bad}})
          msg (:message (first (filter #(clojure.string/includes? (:message %) "direction")
                                       (:errors res))))]
      (is (some? msg) bad)
      (is (clojure.string/includes? msg "min") bad)
      (is (clojure.string/includes? msg "max") bad))))

(deftest a-supplied-name-that-is-not-declared-is-an-error
  (let [res (parameters/resolve-values decls {:file {} :flags {"run_cmd" "x" "editble" "y"}})]
    (is (some #(clojure.string/includes? % "editble") (:errors res)))))
```

- [ ] **Step 2: Run the tests and watch them fail**

Run: `make run-parameters`
Expected: FAIL — `resolve-values` is not defined.

- [ ] **Step 3: Write the minimal implementation**

Append to `src/attractor/parameters.lg`:

```clojure
(defn render [v]
  (if (integer? v) (str v) (str v)))

(defn- allowed-values [t] (vec (rest t)))

(defn- coerce-text [t text nm]
  (cond
    (= :string t) {:value text}
    (= :int t) (if (re-matches #"[-+]?[0-9]+" text)
                 {:value (edn/read-string text)}
                 {:error {:rule "parameter_type"
                          :message (str "parameter '" nm "' expects an :int, got "
                                        (pr-str text))}})
    (enum-type? t) (if (contains? (set (allowed-values t)) text)
                     {:value text}
                     {:error {:rule "parameter_type"
                              :message (str "parameter '" nm "' expects one of "
                                            (str/join ", " (allowed-values t))
                                            ", got " (pr-str text))}})
    :else {:error {:rule "parameter_type"
                   :message (str "parameter '" nm "' has unknown type")}}))

(defn- check-typed [t v nm]
  (if (default-matches? t v)
    {:value v}
    {:error {:rule "parameter_type"
             :message (str "parameter '" nm "' value " (pr-str v)
                           " is not a " (pr-str t))}}))

(defn resolve-values [declarations supplied]
  (let [flags (or (:flags supplied) {})
        file (or (:file supplied) {})
        by-name (into {} (map (fn [d] [(:name d) d]) declarations))
        unknown (sort (remove #(contains? by-name %)
                              (distinct (concat (keys flags) (keys file)))))
        base {:values {} :typed {} :sources {}
              :errors (mapv (fn [u] {:rule "parameter_undeclared"
                                     :message (str "'" u "' names no declared parameter")})
                            unknown)}]
    (reduce
      (fn [acc d]
        (let [nm (:name d) t (:type d)
              r (cond
                  (contains? flags nm) (assoc (coerce-text t (str (get flags nm)) nm) :source :flag)
                  (contains? file nm) (assoc (check-typed t (get file nm) nm) :source :file)
                  (:has_default d) {:value (:default d) :source :default}
                  :else {:error {:rule "parameter_missing"
                                 :message (str "'" nm "' is required and was not supplied")}})]
          (if (:error r)
            (update acc :errors conj (:error r))
            (-> acc
                (assoc-in [:values nm] (render (:value r)))
                (assoc-in [:typed nm] (:value r))
                (assoc-in [:sources nm] (:source r))))))
      base
      declarations)))
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: `make run-parameters`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/attractor/parameters.lg test/attractor/parameters_test.lg
git commit -m "feat(parameters): resolve values by precedence with typed coercion

Implements R-value-precedence, R-type-coercion, R-missing-value. A flag
beats the file beats the declared default, and an enum error names the
allowed values so the fix is in the message."
```

---

### Task 6: Trust levels and delegability

Implements `[R-trust-monotonic]`, `[R-delegated-rejects-nondelegable]`, `[R-delegable-closed-type]`.

**Files:**
- Modify: `src/attractor/parameters.lg`
- Modify: `src/attractor/validation.lg`
- Modify: `test/attractor/parameters_test.lg`

**Interfaces:**
- Consumes: `parameters/resolve-values` (Task 5), `parameters/find-references` (Task 4).
- Produces: `(parameters/effective-trust parent requested)` → `:trusted` or `:delegated`. `nil` parent means the launch is the root.
- Produces: `(parameters/check-delegation declarations supplied trust)` → `["msg" ...]`, empty under `:trusted`.
- Produces: `(parameters/closed-type? t)` → boolean; true for `:int` and `[:enum ...]`.

- [ ] **Step 1: Write the failing tests**

```clojure
(deftest trust-never-increases-along-a-chain
  (is (= :trusted (parameters/effective-trust nil :trusted)))
  (is (= :delegated (parameters/effective-trust :trusted :delegated)))
  (is (= :delegated (parameters/effective-trust :delegated :delegated)))
  (is (= :delegated (parameters/effective-trust :delegated :trusted))))

(deftest a-delegated-launch-may-set-only-delegable-parameters
  (let [ds (:declarations
             (parameters/parse-declarations
               "[{:name :run_cmd :type :string}
                 {:name :direction :type [:enum \"min\" \"max\"] :delegable true}]"))]
    (is (= [] (parameters/check-delegation ds {:flags {"run_cmd" "sh evil.sh"}} :trusted)))
    (is (= [] (parameters/check-delegation ds {:flags {"direction" "max"}} :delegated)))
    (let [errs (parameters/check-delegation ds {:flags {"run_cmd" "sh evil.sh"}} :delegated)]
      (is (= 1 (count errs)))
      (is (clojure.string/includes? (first errs) "run_cmd")))))

(deftest a-delegable-string-may-not-reach-a-command-a-path-or-the-stylesheet
  (doseq [attr [:tool_command :subpipeline.dotfile]]
    (let [graph {:attrs {:params "[{:name :p :type :string :delegable true}]"}
                 :nodes {"n" {:id "n" :attrs {attr "{{p}}"}}} :edges []
                 :parameter_references {"p" #{attr}}}
          diags (filter #(= "parameter_delegable_open" (:rule %))
                        (attractor.validation/validate graph))]
      (is (= 1 (count diags)) (str attr))))
  (let [graph {:attrs {:params "[{:name :p :type :string :delegable true}]"
                       :model_stylesheet "{{p}}"}
               :nodes {} :edges [] :parameter_references {"p" #{:model_stylesheet}}}]
    (is (= 1 (count (filter #(= "parameter_delegable_open" (:rule %))
                            (attractor.validation/validate graph)))))))

(deftest a-closed-type-or-a-non-delegable-parameter-may-reach-a-command
  (doseq [decl ["[{:name :p :type :int :delegable true}]"
                "[{:name :p :type [:enum \"a\" \"b\"] :delegable true}]"
                "[{:name :p :type :string}]"]]
    (let [graph {:attrs {:params decl}
                 :nodes {"n" {:id "n" :attrs {:tool_command "{{p}}"}}} :edges []
                 :parameter_references {"p" #{:tool_command}}}]
      (is (empty? (filter #(= "parameter_delegable_open" (:rule %))
                          (attractor.validation/validate graph)))
          decl))))
```

- [ ] **Step 2: Run the tests and watch them fail**

Run: `make run-parameters`
Expected: FAIL — `effective-trust` is not defined.

- [ ] **Step 3: Write the minimal implementation**

Append to `src/attractor/parameters.lg`:

```clojure
(def ^:private sensitive-attrs
  #{:tool_command :subpipeline.dotfile :model_stylesheet})

(defn closed-type? [t]
  (or (= :int t) (enum-type? t)))

;; A launch may lower its own trust and never raise it.
(defn effective-trust [parent requested]
  (let [req (or requested :trusted)]
    (if (= :delegated parent) :delegated req)))

(defn check-delegation [declarations supplied trust]
  (if (not= :delegated trust)
    []
    (let [by-name (into {} (map (fn [d] [(:name d) d]) declarations))
          names (distinct (concat (keys (or (:flags supplied) {}))
                                  (keys (or (:file supplied) {}))))]
      (vec (keep (fn [nm]
                   (when-let [d (get by-name nm)]
                     (when-not (:delegable d)
                       (str "'" nm "' may not be supplied by a delegated launch"))))
                 (sort names))))))
```

- [ ] **Step 4: Add the rule**

In `src/attractor/validation.lg`:

```clojure
;; Rule: parameter_delegable_open
(defn rule-parameter-delegable-open [graph]
  (let [decls (:declarations (parameters/parse-declarations (get-in graph [:attrs :params])))
        refs (or (:parameter_references graph) {})]
    (vec (mapcat
           (fn [d]
             (let [used (get refs (:name d) #{})
                   risky (sort (filter parameters/sensitive-attr? used))]
               (if (and (:delegable d) (not (parameters/closed-type? (:type d))) (seq risky))
                 [{:rule "parameter_delegable_open" :severity :error
                   :message (str "delegable parameter '" (:name d) "' is :string and is "
                                 "referenced from " (str/join ", " (map name risky))
                                 "; a delegable parameter reaching a command, a path or the "
                                 "stylesheet must have a closed type (:int or [:enum ...])")}]
                 [])))
           decls))))
```

Export the predicate from `attractor.parameters`:

```clojure
(defn sensitive-attr? [k] (contains? sensitive-attrs k))
```

Append `rule-parameter-delegable-open` to `built-in-rules`.

- [ ] **Step 5: Run the tests and watch them pass**

Run: `make run-parameters && make run-validation`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/attractor/parameters.lg src/attractor/validation.lg test/attractor/parameters_test.lg
git commit -m "feat(parameters): bound what a delegated launch can supply

Implements R-trust-monotonic, R-delegated-rejects-nondelegable,
R-delegable-closed-type. Reference sites are static, so a delegable
parameter reaching a command, a path or the stylesheet is caught at
validate rather than at launch."
```

---

### Task 7: Resolve in prepare and mirror into the run context

Implements `[R-context-mirror]`.

**Files:**
- Modify: `src/attractor/pipeline.lg` (`prepare`)
- Modify: `src/attractor/hub.lg` (`:workflow/run`)
- Create: `test/attractor/parameters_contract_test.lg`

**Interfaces:**
- Consumes: everything from Tasks 1–6.
- Produces: `prepare` accepts `:parameters {:file {} :flags {}}` and `:trust :trusted|:delegated`, and returns `:parameters {:values ... :typed ... :sources ...}` in its result alongside `:graph` and `:diagnostics`. Resolution errors become `:error`-severity diagnostics with rule `parameter_missing`, `parameter_type`, `parameter_undeclared` or `parameter_not_delegable`, so the existing `raise-on-errors` gate stops the run before any node executes.
- Produces: the run context is seeded with `param.<name>` for every resolved parameter.

- [ ] **Step 1: Write the failing test**

```clojure
(ns attractor.parameters-contract-test
  (:require [clojure.test :refer [deftest is]]
            [clojure.string :as str]
            [attractor.pipeline :as pipeline]
            [attractor.context :as context]))

(def ^:private source
  "digraph P {
     graph [params=\"[{:name :direction :type [:enum \\\"min\\\" \\\"max\\\"] :default \\\"min\\\"}]\"]
     start [shape=Mdiamond]
     echo [shape=parallelogram, tool_command=\"printf {{direction}}\"]
     exit [shape=Msquare]
     start -> echo
     echo -> exit
   }")

(deftest prepare-substitutes-a-flag-value-into-a-tool-command
  (let [res (pipeline/prepare source {:parameters {:flags {"direction" "max"}}})]
    (is (= [] (filter #(= :error (:severity %)) (:diagnostics res))))
    (is (= "printf max" (get-in res [:graph :nodes "echo" :tool_command])))
    (is (= "max" (get-in res [:parameters :values "direction"])))))

(deftest prepare-uses-the-declared-default-when-nothing-is-supplied
  (let [res (pipeline/prepare source {})]
    (is (= "printf min" (get-in res [:graph :nodes "echo" :tool_command])))))

(deftest a-missing-required-value-is-an-error-diagnostic
  (let [src (str/replace source ":default \\\"min\\\"" "")
        res (pipeline/prepare src {})]
    (is (some #(= "parameter_missing" (:rule %)) (:diagnostics res)))))

(deftest resolved-parameters-are-seeded-into-the-run-context
  (let [ctx (context/make-context)
        _ (pipeline/run source {:parameters {:flags {"direction" "max"}}
                                :context ctx
                                :logs-root "/tmp/attractor-param-ctx"})]
    (is (= "max" (context/ctx-get-string ctx "param.direction")))))
```

- [ ] **Step 2: Run the test and watch it fail**

Run: `make run-parameters_contract`
Expected: FAIL — `prepare` ignores `:parameters` and the command still reads `printf {{direction}}`.

- [ ] **Step 3: Wire it into prepare**

In `src/attractor/pipeline.lg`, add `[attractor.parameters :as parameters]` to the requires and replace `prepare`:

```clojure
(defn- tagged-diagnostics [errors]
  ;; resolve-values already carries the spec's rule name on each error.
  (mapv (fn [e] {:rule (:rule e) :severity :error :message (:message e)}) errors))

(defn- parameter-diagnostics [rule messages]
  (mapv (fn [m] {:rule rule :severity :error :message m}) messages))

(defn prepare
  "Parse, resolve parameters, transform, and validate without execution."
  ([dot-source] (prepare dot-source {}))
  ([dot-source options]
   (capture/prepare-closure
     dot-source options
     (fn [source]
       (let [graph (parser/parse-dot source)
             supplied (or (:parameters options) {})
             trust (parameters/effective-trust (:parent-trust options) (:trust options))
             decl (parameters/parse-declarations (get-in graph [:attrs :params]))
             delegation (parameters/check-delegation (:declarations decl) supplied trust)
             resolved (parameters/resolve-values (:declarations decl) supplied)
             prepared-graph (transforms/apply-transforms
                              graph (or (:custom-transforms options) [])
                              (:values resolved))
             diagnostics (vec (concat
                                (validation/validate
                                  prepared-graph (or (:custom-rules options) []))
                                (parameter-diagnostics "parameter_not_delegable" delegation)
                                (tagged-diagnostics (:errors resolved))))]
         {:graph prepared-graph :diagnostics diagnostics
          :parameters resolved :trust trust})))))
```

- [ ] **Step 4: Seed the context**

In `src/attractor/pipeline.lg`'s `run`, after the `raise-on-errors` gate, seed the caller's context (or the one the engine will make) with the resolved values:

```clojure
         _ (when-let [ctx (:context options)]
             (context/ctx-apply-updates!
               ctx
               (into {} (map (fn [[k v]] [(str "param." k) v])
                             (get-in prepared [:parameters :values])))))
```

Add `[attractor.context :as context]` to the requires if it is not already there.

In `src/attractor/hub.lg`'s `:workflow/run` case, replace `ctx (context/make-context)` with a context seeded from the request, and forward the options:

```clojure
          ctx (context/make-context)
          params {:file (or (:params_file request) {})
                  :flags (or (:params request) {})}
```

and add `:parameters params :trust (:trust request)` to the option map passed to `pipeline/run`.

- [ ] **Step 5: Run the tests and watch them pass**

Run: `make run-parameters_contract && make test`
Expected: PASS, and the full suite green.

- [ ] **Step 6: Commit**

```bash
git add src/attractor/pipeline.lg src/attractor/hub.lg test/attractor/parameters_contract_test.lg
git commit -m "feat(parameters): resolve in prepare and mirror into the run context

Implements R-context-mirror. Resolution errors are error-severity
diagnostics, so the existing gate stops the run before any node executes,
and param.<name> is readable by an edge condition and forwardable through
input_map."
```

---

### Task 8: Export declared parameters to tool-node environments

Implements `[R-export-env]`.

**Files:**
- Modify: `src/attractor/handlers.lg`
- Modify: `test/attractor/parameters_contract_test.lg`

**Interfaces:**
- Consumes: the resolved values seeded as `param.<name>` in the run context (Task 7), and the declarations, which the handler reads from the graph.
- Produces: `handle-timed-tool` passes `{"ATTRACTOR_PARAM_EDITABLE" "solve.lg"}` as the fourth argument to `exec_command`, which already validates names against `[A-Za-z_][A-Za-z0-9_]*` and currently receives `nil`.

- [ ] **Step 1: Write the failing test**

```clojure
(def ^:private export-source
  "digraph P {
     graph [params=\"[{:name :editable :type :string :export true}
                      {:name :secret_note :type :string}]\"]
     start [shape=Mdiamond]
     probe [shape=parallelogram, timeout=\"30s\",
            tool_command=\"env | grep '^ATTRACTOR_PARAM_' | sort\"]
     exit [shape=Msquare]
     start -> probe
     probe -> exit
   }")

(deftest only-exported-parameters-reach-a-tool-node
  (let [ctx (context/make-context)
        _ (pipeline/run export-source
                        {:parameters {:flags {"editable" "solve.lg" "secret_note" "hidden"}}
                         :context ctx
                         :logs-root "/tmp/attractor-param-env"})
        out (context/ctx-get-string ctx "tool.output")]
    (is (str/includes? out "ATTRACTOR_PARAM_EDITABLE=solve.lg"))
    (is (not (str/includes? out "SECRET_NOTE")))))
```

- [ ] **Step 2: Run the test and watch it fail**

Run: `make run-parameters_contract`
Expected: FAIL — the output contains no `ATTRACTOR_PARAM_` lines.

- [ ] **Step 3: Write the minimal implementation**

In `src/attractor/handlers.lg`, add `[attractor.parameters :as parameters]` to the requires. Add a helper and thread the graph's declarations plus the context into the tool call:

```clojure
(defn- exported-environment [graph ctx]
  (let [decls (:declarations (parameters/parse-declarations (get-in graph [:attrs :params])))]
    (into {} (keep (fn [d]
                     (when (:export d)
                       (let [v (context/ctx-get-string ctx (str "param." (:name d)) nil)]
                         (when (some? v)
                           [(str "ATTRACTOR_PARAM_" (str/upper-case (:name d))) v]))))
                   decls))))
```

`handle-tool` already receives the context and the graph and ignores both, so
no signature changes ripple outward. At `src/attractor/handlers.lg:134`, rename
the ignored arguments and thread the map down:

```clojure
(defn handle-tool [node context graph _logs-root]
  (try
    (let [cmd (or (:tool_command (:attrs node)) (:tool_command node) "")
          timeout-ms (parsed-tool-timeout-ms node)
          env-vars (exported-environment graph context)]
      (if (str/blank? cmd)
        {:status :fail :failure_reason "No tool_command specified"}
        (if timeout-ms
          (handle-timed-tool node cmd timeout-ms env-vars)
          (handle-unbounded-tool cmd))))
    (catch Object e
      (merge {:status :fail
              :failure_reason (str "Tool execution exception: " e)}
             (select-keys (or (ex-data e) {}) [:category :retryable])))))
```

Give `handle-timed-tool` the extra parameter — `(defn- handle-timed-tool [node cmd timeout-ms env-vars] ...)` — and change its one `exec_command` call from

```clojure
      (let [res ((:exec_command environment) cmd timeout-ms (os/cwd) nil)
```

to

```clojure
      (let [res ((:exec_command environment) cmd timeout-ms (os/cwd) env-vars)
```

`handle-unbounded-tool` shells out through `os/sh` directly and has no
environment seam, so a node without a `timeout` receives no exported
parameters. Note that in the test above, the probe node carries
`timeout="30s"` for exactly this reason.

- [ ] **Step 4: Run the tests and watch them pass**

Run: `make run-parameters_contract && make test`
Expected: PASS, full suite green.

- [ ] **Step 5: Commit**

```bash
git add src/attractor/handlers.lg test/attractor/parameters_contract_test.lg
git commit -m "feat(parameters): export declared parameters to tool-node environments

Implements R-export-env. Export is per declaration, so the params
attribute remains the complete picture of what a tool node can read."
```

---

### Task 9: CLI flags on run, validate and graph

Implements `[R-value-precedence]` at the command line.

**Files:**
- Modify: `src/attractor/cli.lg`
- Modify: `test/attractor/parameters_contract_test.lg`

**Interfaces:**
- Consumes: `prepare`/`run` options from Task 7.
- Produces: `(cli/parse-parameter-args args)` → `{:flags {"k" "v"} :file {...} :trust :trusted|:delegated :errors []}`. `--param` is repeatable; `--params-file` reads an EDN map; `--trust` accepts `trusted` or `delegated`.

- [ ] **Step 1: Write the failing test**

```clojure
(deftest parameter-flags-parse-with-repetition-and-a-file
  (spit "/tmp/attractor-params.edn" "{:direction \"max\" :max_iterations 7}")
  (let [res (attractor.cli/parse-parameter-args
              ["run" "wf.dot" "--params-file" "/tmp/attractor-params.edn"
               "--param" "direction=min" "--param" "run_cmd=sh bench.sh"
               "--trust" "delegated"])]
    (is (= [] (:errors res)))
    (is (= {"direction" "min" "run_cmd" "sh bench.sh"} (:flags res)))
    (is (= "max" (get-in res [:file "direction"])))
    (is (= 7 (get-in res [:file "max_iterations"])))
    (is (= :delegated (:trust res)))))

(deftest a-malformed-param-flag-is-rejected
  (let [res (attractor.cli/parse-parameter-args ["run" "wf.dot" "--param" "novalue"])]
    (is (some #(clojure.string/includes? % "novalue") (:errors res)))))

(deftest an-unknown-trust-level-is-rejected
  (let [res (attractor.cli/parse-parameter-args ["run" "wf.dot" "--trust" "root"])]
    (is (some #(clojure.string/includes? % "root") (:errors res)))))
```

Add `[attractor.cli]` to the test namespace requires.

- [ ] **Step 2: Run the test and watch it fail**

Run: `make run-parameters_contract`
Expected: FAIL — `parse-parameter-args` is not defined.

- [ ] **Step 3: Write the minimal implementation**

In `src/attractor/cli.lg`:

```clojure
(defn parse-parameter-args [args]
  (loop [rem (vec args) flags {} file {} trust nil errors []]
    (cond
      (empty? rem) {:flags flags :file file :trust (or trust :trusted) :errors errors}

      (= "--param" (first rem))
      (let [v (second rem)
            idx (when (string? v) (str/index-of v "="))]
        (if (and v idx (pos? idx))
          (recur (subvec rem 2) (assoc flags (subs v 0 idx) (subs v (inc idx)))
                 file trust errors)
          (recur (if v (subvec rem 2) (subvec rem 1)) flags file trust
                 (conj errors (str "--param expects name=value, got " (pr-str v))))))

      (= "--params-file" (first rem))
      (let [p (second rem)
            parsed (try (edn/read-string (io/slurp p)) (catch Object e {::bad (str e)}))]
        (cond
          (nil? p) (recur (subvec rem 1) flags file trust
                          (conj errors "--params-file expects a path"))
          (and (map? parsed) (contains? parsed ::bad))
          (recur (subvec rem 2) flags file trust
                 (conj errors (str "--params-file " p " is not readable EDN: " (::bad parsed))))
          (not (map? parsed))
          (recur (subvec rem 2) flags file trust
                 (conj errors (str "--params-file " p " must contain an EDN map")))
          :else
          (recur (subvec rem 2) flags
                 (into file (map (fn [[k v]] [(name k) v]) parsed))
                 trust errors)))

      (= "--trust" (first rem))
      (let [v (second rem)]
        (if (contains? #{"trusted" "delegated"} v)
          (recur (subvec rem 2) flags file (keyword v) errors)
          (recur (if v (subvec rem 2) (subvec rem 1)) flags file trust
                 (conj errors (str "--trust expects trusted or delegated, got " (pr-str v))))))

      :else (recur (subvec rem 1) flags file trust errors))))
```

Add `[clojure.edn :as edn]` to the requires if absent. In `cmd-run`, `cmd-validate` and `cmd-graph`, call `parse-parameter-args`, print any `:errors` and exit 2, then pass `:parameters {:flags ... :file ...}` and `:trust` into the request map and on to `pipeline/prepare`/`pipeline/run`.

Update the usage lines:

```clojure
  (println "  run <dotfile> [--logs-root <dir>] [--auto-approve] [--param k=v]... [--params-file <path>] [--trust trusted|delegated]   Execute a DOT pipeline")
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: `make run-parameters_contract && make run-cli && make test`
Expected: PASS, full suite green.

- [ ] **Step 5: Commit**

```bash
git add src/attractor/cli.lg test/attractor/parameters_contract_test.lg
git commit -m "feat(parameters): accept --param, --params-file and --trust

Implements R-value-precedence at the command line for run, validate and
graph, so a launch can be checked without being executed."
```

---

### Task 10: Checkpoint capture and resume rejection

Implements `[R-checkpoint-capture]`, `[R-resume-rejects-params]`.

**Files:**
- Modify: `src/attractor/context.lg` (`save-checkpoint`, `load-checkpoint`)
- Modify: `src/attractor/pipeline.lg` (`resume`)
- Modify: `test/attractor/parameters_contract_test.lg`

**Interfaces:**
- Consumes: `(:parameters prepared)` from Task 7.
- Produces: the checkpoint gains a `:parameters` field holding the resolved `:values` map. `load-checkpoint` restores it. `pipeline/resume` raises `ex-info` with `{:category :workflow_configuration_error :option :--param}` when the caller passes `:parameters` or `:trust`.

Resume currently drops unrecognised options silently through `select-keys` on `resume-runtime-option-keys`, so without this the caller's parameters would be accepted and ignored.

- [ ] **Step 1: Write the failing tests**

```clojure
(deftest a-checkpoint-records-the-resolved-parameters
  (let [cp {:timestamp 1 :current_node "echo" :completed_nodes [] :node_retries {}
            :node_outcomes {} :context_values {} :logs []
            :parameters {"direction" "max"}}
        path "/tmp/attractor-param-cp.edn"]
    (context/save-checkpoint cp path)
    (is (= {"direction" "max"} (:parameters (context/load-checkpoint path))))))

(deftest resume-refuses-parameters
  (let [path "/tmp/attractor-param-cp.edn"
        thrown (try (pipeline/resume {:checkpoint-path path :parameters {:flags {"direction" "min"}}})
                    nil
                    (catch Object e (ex-data e)))]
    (is (= :workflow_configuration_error (:category thrown)))
    (is (= :--param (:option thrown)))))
```

- [ ] **Step 2: Run the tests and watch them fail**

Run: `make run-parameters_contract`
Expected: FAIL — the checkpoint round-trip drops `:parameters`, and `resume` accepts the option silently.

- [ ] **Step 3: Persist the field**

In `src/attractor/context.lg`, add `:parameters` to the map built in `save-checkpoint` and to the one `load-checkpoint` returns, following the existing `cond->` pattern used for `:workflow_fingerprint` so an older checkpoint without the field still loads.

- [ ] **Step 4: Reject the option on resume**

In `src/attractor/pipeline.lg`'s `resume`, before anything else:

```clojure
   (doseq [[k flag] [[:parameters :--param] [:trust :--trust]]]
     (when (contains? options k)
       (throw (ex-info (str "option " (name flag) " is not permitted on resume")
                       {:category :workflow_configuration_error
                        :option flag}))))
```

Then pass the checkpoint's recorded `:parameters` as the substitution values when the pinned graph is prepared, so the resumed run substitutes exactly what the original did.

- [ ] **Step 5: Run the tests and watch them pass**

Run: `make run-parameters_contract && make run-workflow_recovery_contract && make test`
Expected: PASS, full suite green.

- [ ] **Step 6: Commit**

```bash
git add src/attractor/context.lg src/attractor/pipeline.lg test/attractor/parameters_contract_test.lg
git commit -m "feat(parameters): capture resolved values and refuse them on resume

Implements R-checkpoint-capture and R-resume-rejects-params. The resume
path drops unrecognised options silently, so accepting --param there would
have been honoured in appearance only."
```

---

## Requirement Coverage

Run the spec's own coverage check — both sides must yield the same set:

```bash
grep -o '\[R-[a-z-]*\]' docs/rfc/draft-ndn-workflow-parameters-00.md | sort -u > /tmp/rfc-ids
grep -o '\[R-[a-z-]*\]' docs/superpowers/plans/2026-09-21-workflow-parameters.md | sort -u > /tmp/plan-ids
diff /tmp/rfc-ids /tmp/plan-ids && echo "coverage ok"
```

| Requirement | Task |
|---|---|
| `[R-param-declaration]` | 1 |
| `[R-param-name-charset]` | 1 |
| `[R-legacy-params-rejected]` | 1 |
| `[R-substitution-syntax]` | 2 |
| `[R-substitution-order]` | 3 |
| `[R-substitution-scope]` | 3 |
| `[R-undeclared-reference]` | 4 |
| `[R-value-precedence]` | 5, 9 |
| `[R-type-coercion]` | 5 |
| `[R-missing-value]` | 5 |
| `[R-trust-monotonic]` | 6 |
| `[R-delegated-rejects-nondelegable]` | 6 |
| `[R-delegable-closed-type]` | 6 |
| `[R-context-mirror]` | 7 |
| `[R-export-env]` | 8 |
| `[R-checkpoint-capture]` | 10 |
| `[R-resume-rejects-params]` | 10 |

## After the plan

The spec's embedded transcripts are its acceptance criteria and its corpus is declared red. Once Task 10 lands, re-run `rfc-run` against the draft; when the transcripts pass, change the masthead `Corpus:` to green in a superseding draft (a published RFC is frozen, and this one is still `DRAFT`, so amend it in place while it remains unpublished).

Two follow-ups the spec names as Out of Scope and this plan does not build: the pinned-bundle launch operation where `DELEGATED` becomes load-bearing, and implicit parameter inheritance into sub-pipelines, which `input_map` already owns.
