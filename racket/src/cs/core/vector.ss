(define (vector-immutable . args)
  (let ([vec (apply vector args)])
    (#%$vector-set-immutable! vec)
    vec))

;; ----------------------------------------

(define (vector? v)
  (or (#%vector? v)
      (and (impersonator? v)
           (#%vector? (impersonator-val v)))))

(define (mutable-vector? v)
  (or (#%mutable-vector? v)
      (and (impersonator? v)
           (#%mutable-vector? (impersonator-val v)))))

;; ----------------------------------------

(define-record vector-chaperone chaperone (ref set))
(define-record vector-impersonator impersonator (ref set))

(define/who (chaperone-vector vec ref set . props)
  (check who vector? vec)
  (do-impersonate-vector who make-vector-chaperone vec ref set
                         make-props-chaperone props))

(define/who (impersonate-vector vec ref set . props)
  (check who mutable-vector? :contract "(and/c vector? (not/c immutable?))" vec)
  (do-impersonate-vector who make-vector-impersonator vec ref set
                         make-props-impersonator props))

(define (do-impersonate-vector who make-vector-impersonator vec ref set
                               make-props-impersonator props)
  (check who (procedure-arity-includes/c 3) :or-false ref)
  (check who (procedure-arity-includes/c 3) :or-false set)
  (let ([val (if (impersonator? vec)
                 (impersonator-val vec)
                 vec)]
        [props (add-impersonator-properties who
                                            props
                                            (if (impersonator? vec)
                                                (impersonator-props vec)
                                                empty-hasheq))])
    (if (or ref set)
        (make-vector-impersonator val vec props ref set)
        (make-props-impersonator val vec props))))

(define (set-vector-impersonator-hash!)
  (record-type-hash-procedure (record-type-descriptor vector-chaperone)
                              (lambda (c hash-code)
                                (hash-code (impersonator-next c))))
  (record-type-hash-procedure (record-type-descriptor vector-impersonator)
                              (lambda (i hash-code)
                                (hash-code (vector-copy i)))))

;; ----------------------------------------

(define-record vector*-chaperone vector-chaperone ())
(define-record vector*-impersonator vector-impersonator ())

(define/who (chaperone-vector* vec ref set . props)
  (check who vector? vec)
  (do-impersonate-vector* who make-vector*-chaperone vec ref set
                          make-props-chaperone props))

(define/who (impersonate-vector* vec ref set . props)
  (check who mutable-vector? vec)
  (do-impersonate-vector who make-vector*-impersonator vec ref set
                         make-props-impersonator props))

(define (do-impersonate-vector* who make-vector*-impersonator vec ref set
                                make-props-impersonator props)
  (check who (procedure-arity-includes/c 4) :or-false ref)
  (check who (procedure-arity-includes/c 4) :or-false set)
  (let ([val (if (impersonator? vec)
                 (impersonator-val vec)
                 vec)]
        [props (add-impersonator-properties who
                                            props
                                            (if (impersonator? vec)
                                                (impersonator-props vec)
                                                empty-hasheq))])
    (if (or ref set)
        (make-vector*-impersonator val vec props ref set)
        (make-props-impersonator val vec props))))

;; ----------------------------------------

(define (vector-length vec)
  (if (#%vector? vec)
      (#3%vector-length vec)
      (pariah (impersonate-vector-length vec))))

(define (unsafe-vector-length vec)
  (vector-length vec))

(define (impersonate-vector-length vec)
  (if (and (impersonator? vec)
           (#%vector? (impersonator-val vec)))
      (#%vector-length (impersonator-val vec))
      ;; Let primitive report the error:
      (#2%vector-length vec)))

;; ----------------------------------------

(define (vector-ref vec idx)
  (if (#%vector? vec)
      (#2%vector-ref vec idx)
      (pariah (impersonate-vector-ref vec idx))))

(define (unsafe-vector-ref vec idx)
  (if (#%vector? vec)
      (#3%vector-ref vec idx)
      (pariah (impersonate-vector-ref vec idx))))

(define (impersonate-vector-ref orig idx)
  (if (and (impersonator? orig)
           (#%vector? (impersonator-val orig)))
      (let loop ([o orig])
        (cond
         [(#%vector? o) (#%vector-ref o idx)]
         [(vector-chaperone? o)
          (let* ([val (loop (impersonator-next o))]
                 [new-val (if (vector*-chaperone? o)
                              ((vector-chaperone-ref o) orig o idx val)
                              ((vector-chaperone-ref o) o idx val))])
            (unless (chaperone-of? new-val val)
              (raise-arguments-error 'vector-ref
                                     "chaperone produced a result that is not a chaperone of the original result"
                                     "chaperone result" new-val
                                     "original result" val))
            new-val)]
         [(vector-impersonator? o)
          (let ([val  (loop (impersonator-next o))])
            (if (vector*-impersonator? o)
                ((vector-impersonator-ref o) orig o idx val)
                ((vector-impersonator-ref o) o idx val)))]
         [else (loop (impersonator-next o))]))
      ;; Let primitive report the error:
      (#2%vector-ref orig idx)))

;; ----------------------------------------

(define (vector-set! vec idx val)
  (if (#%vector? vec)
      (#2%vector-set! vec idx val)
      (pariah (impersonate-vector-set! vec idx val))))

(define (unsafe-vector-set! vec idx val)
  (if (#%vector? vec)
      (#3%vector-set! vec idx val)
      (pariah (impersonate-vector-set! vec idx val))))

(define (impersonate-vector-set! orig idx val)
  (cond
   [(not (and (impersonator? orig)
              (mutable-vector? (impersonator-val orig))))
    ;; Let primitive report the error:
    (#2%vector-set! orig idx val)]
   [(or (not (exact-nonnegative-integer? idx))
        (>= idx (vector-length (impersonator-val orig))))
    ;; Let primitive report the index error:
    (#2%vector-set! (impersonator-val orig) idx val)]
   [else
    (let loop ([o orig] [val val])
      (cond
       [(#%vector? o) (#2%vector-set! o idx val)]
       [else
        (let ([next (impersonator-next o)])
          (cond
           [(vector-chaperone? o)
            (let ([new-val (if (vector*-chaperone? o)
                               ((vector-chaperone-set o) orig o idx val)
                               ((vector-chaperone-set o) o idx val))])
              (unless (chaperone-of? new-val val)
                (raise-arguments-error 'vector-set!
                                       "chaperone produced a result that is not a chaperone of the original result"
                                       "chaperone result" new-val
                                       "original result" val))
              (loop next val))]
           [(vector-impersonator? o)
            (loop next
                  (if (vector*-impersonator? o)
                      ((vector-impersonator-set o) orig o idx val)
                      ((vector-impersonator-set o) o idx val)))]
           [else (loop next val)]))]))]))

;; ----------------------------------------

(define/who (vector-copy vec)
  (cond
   [(#%vector? vec)
    (#3%vector-copy vec)]
   [(vector? vec)
    (let* ([len (vector-length vec)]
           [vec2 (make-vector len)])
      (vector-copy! vec2 0 vec)
      vec2)]
   [else
    (raise-argument-error who "vector?" vec)]))

(define/who vector-copy!
  (case-lambda
   [(dest d-start src)
    (vector-copy! dest d-start src 0 (and (vector? src) (vector-length src)))]
   [(src s-start dest d-start)
    (vector-copy! dest d-start src s-start (and (vector? src) (vector-length src)))]
   [(dest d-start src s-start s-end)
    (check who mutable-vector? :contract "(and/c vector? (not/c immutable?))" dest)
    (check who exact-nonnegative-integer? d-start)
    (check who vector? src)
    (check who exact-nonnegative-integer? s-start)
    (check who exact-nonnegative-integer? s-end)
    (let ([d-len (vector-length dest)])
      (check-range who "vector" dest d-start #f d-len)
      (check-range who "vector" src s-start s-end (vector-length src))
      (let ([len (fx- s-end s-start)])
        (check-space who "vector" d-start d-len len)
        (if (and (#%vector? src) (#%vector? dest))
            (vector*-copy! dest d-start src s-start s-end)
            (let loop ([i len])
              (unless (fx= 0 i)
                (let ([i (fx1- i)])
                  (vector-set! dest (fx+ d-start i) (vector-ref src (fx+ s-start i)))
                  (loop i)))))))]))

;; Like `vector-copy!`, but doesn't work on impersonators, and doesn't
;; add its own tests on the vector or range (so unsafe if the core is
;; compiled as unsafe)
(define/who vector*-copy!
  (case-lambda
   [(dest dest-start src)
    (vector*-copy! dest dest-start src 0 (#%vector-length src))]
   [(src src-start dest dest-start)
    (vector*-copy! dest dest-start src src-start (#%vector-length src))]
   [(dest dest-start src src-start src-end)
    (let loop ([i (fx- src-end src-start)])
      (unless (fx= 0 i)
        (let ([i (fx1- i)])
          (#%vector-set! dest (fx+ dest-start i) (vector-ref src (fx+ src-start i)))
          (loop i))))]))

(define/who vector->values
  (case-lambda
   [(vec)
    (check who vector? vec)
     (let ([len (vector-length vec)])
       (cond
        [(fx= len 0) (values)]
        [(fx= len 1) (vector-ref vec 0)]
        [(fx= len 2) (values (vector-ref vec 0) (vector-ref vec 1))]
        [(fx= len 3) (values (vector-ref vec 0) (vector-ref vec 1) (vector-ref vec 2))]
        [else (chez:apply values (vector->list vec))]))]
   [(vec start)
    (vector->values vec start (and (vector? vec) (vector-length vec)))]
   [(vec start end)
    (check who vector? vec)
    (check who exact-nonnegative-integer? start)
    (check who exact-nonnegative-integer? end)
    (check-range who "vector" vec start end (vector-length vec))
    (chez:apply values
                (let loop ([start start])
                  (cond
                   [(fx= start end) null]
                   [else (cons (vector-ref vec start)
                               (loop (fx1+ start)))])))]))

(define/who (vector-fill! vec v)
  (cond
   [(#%vector? vec)
    (#3%vector-fill! vec v)]
   [(vector? vec)
    (check who mutable-vector? :contract "(and/c vector? (not immutable?))" v)
    (let ([len (vector-length vec)])
      (let loop ([i 0])
        (unless (= i len)
          (vector-set! vec i v)
          (loop (fx1+ i)))))]
   [else
    (raise-argument-error who "vector?" vec)]))

(define/who (vector->immutable-vector v)
  (cond
   [(#%vector? v)
    (#3%vector->immutable-vector v)]
   [(vector? v)
    (if (mutable-vector? v)
        (#3%vector->immutable-vector
         (vector-copy v))
        v)]
   [else
    (raise-argument-error who "vector?" v)]))