;; ------------------------------------------------------------
;; Route Registration (corrected)
;; ------------------------------------------------------------

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-HASH (err u101))
(define-constant ERR-INVALID-DESCRIPTION (err u102))
(define-constant ERR-INVALID-SAFETY-LEVEL (err u103))
(define-constant ERR-INVALID-GEOLOCATION (err u104))
(define-constant ERR-ROUTE-ALREADY-EXISTS (err u105))
(define-constant ERR-INVALID-ROUTE-ID (err u106))
(define-constant ERR-ROUTE-NOT-FOUND (err u107))
(define-constant ERR-INVALID-TIMESTAMP (err u108))
(define-constant ERR-AUTHORITY-NOT-VERIFIED (err u109))
(define-constant ERR-GEOLOCATION-OUT-OF-BOUNDS (err u110))
(define-constant ERR-INVALID-BOUNDARIES (err u111))
(define-constant ERR-ROUTE-UPDATE-NOT-ALLOWED (err u112))
(define-constant ERR-INVALID-UPDATE-HASH (err u113))
(define-constant ERR-MAX-ROUTES-EXCEEDED (err u114))
(define-constant ERR-INVALID-ROUTE-TYPE (err u115))
(define-constant ERR-INVALID-DISTANCE (err u116))
(define-constant ERR-INVALID-ELEVATION (err u117))
(define-constant ERR-INVALID-WEATHER-CONDITION (err u118))
(define-constant ERR-INVALID-TRAFFIC-STATUS (err u119))
(define-constant ERR-INVALID-EMERGENCY-STATUS (err u120))

;; ------------------------------------------------------------
;; Data Vars
;; ------------------------------------------------------------

(define-data-var next-route-id uint u0)
(define-data-var max-routes uint u1000)
(define-data-var registration-fee uint u1000)
;; must be optional
(define-data-var authority-contract (optional principal) none)

;; ------------------------------------------------------------
;; Storage
;; ------------------------------------------------------------

(define-map routes
  uint
  {
    hash: (buff 32),
    description: (string-utf8 500),
    safety-level: uint,
    geolocation: { lat: int, lon: int },
    boundaries: { min-lat: int, max-lat: int, min-lon: int, max-lon: int },
    timestamp: uint,
    creator: principal,
    route-type: (string-utf8 50),
    distance: uint,
    elevation: uint,
    weather-condition: (string-utf8 100),
    traffic-status: (string-utf8 100),
    emergency-status: bool
  }
)

;; fast existence check: hash -> route-id
(define-map routes-by-hash
  (buff 32)
  uint)

(define-map route-updates
  uint
  {
    update-hash: (buff 32),
    update-description: (string-utf8 500),
    update-safety-level: uint,
    update-timestamp: uint,
    updater: principal
  }
)

;; ------------------------------------------------------------
;; Read-only views
;; ------------------------------------------------------------

(define-read-only (get-route (id uint))
  (map-get? routes id)
)

(define-read-only (get-route-updates (id uint))
  (map-get? route-updates id)
)

(define-read-only (is-route-registered (h (buff 32)))
  (is-some (map-get? routes-by-hash h))
)

;; ------------------------------------------------------------
;; Validators
;; ------------------------------------------------------------

(define-private (validate-hash (h (buff 32)))
  (if (is-eq (len h) u32)
      (ok true)
      ERR-INVALID-HASH)
)

(define-private (validate-description (desc (string-utf8 500)))
  (if (> (len desc) u0)
      (ok true)
      ERR-INVALID-DESCRIPTION)
)

(define-private (validate-safety-level (sl uint))
  ;; valid range 1..5
  (if (or (<= sl u0) (> sl u5))
      ERR-INVALID-SAFETY-LEVEL
      (ok true))
)

(define-private (validate-geolocation (geo { lat: int, lon: int }))
  (let ((lat (get lat geo))
        (lon (get lon geo)))
    (if (and (>= lat -90000000) (<= lat 90000000)
             (>= lon -180000000) (<= lon 180000000))
        (ok true)
        ERR-GEOLOCATION-OUT-OF-BOUNDS))
)

(define-private (validate-boundaries (bounds { min-lat: int, max-lat: int, min-lon: int, max-lon: int }))
  (let ((min-lat (get min-lat bounds))
        (max-lat (get max-lat bounds))
        (min-lon (get min-lon bounds))
        (max-lon (get max-lon bounds)))
    (if (and (<= min-lat max-lat)
             (<= min-lon max-lon))
        (ok true)
        ERR-INVALID-BOUNDARIES))
)

(define-private (validate-timestamp (ts uint))
  (if (>= ts block-height)
      (ok true)
      ERR-INVALID-TIMESTAMP)
)

(define-private (validate-route-type (rt (string-utf8 50)))
  (if (or (is-eq rt "road") (is-eq rt "path") (is-eq rt "water"))
      (ok true)
      ERR-INVALID-ROUTE-TYPE)
)

(define-private (validate-distance (d uint))
  (if (<= d u1000000)
      (ok true)
      ERR-INVALID-DISTANCE)
)

(define-private (validate-elevation (e uint))
  (if (<= e u10000)
      (ok true)
      ERR-INVALID-ELEVATION)
)

(define-private (validate-weather (w (string-utf8 100)))
  (if (or (is-eq w "clear") (is-eq w "rainy") (is-eq w "stormy"))
      (ok true)
      ERR-INVALID-WEATHER-CONDITION)
)

(define-private (validate-traffic (t (string-utf8 100)))
  (if (or (is-eq t "low") (is-eq t "medium") (is-eq t "high"))
      (ok true)
      ERR-INVALID-TRAFFIC-STATUS)
)

;; ------------------------------------------------------------
;; Admin / config
;; ------------------------------------------------------------

(define-public (set-authority-contract (contract-principal principal))
  (begin
    ;; allow setting exactly once
    (asserts! (is-none (var-get authority-contract)) ERR-AUTHORITY-NOT-VERIFIED)
    (var-set authority-contract (some contract-principal))
    (ok true))
)

(define-public (set-max-routes (new-max uint))
  (begin
    (asserts! (is-some (var-get authority-contract)) ERR-AUTHORITY-NOT-VERIFIED)
    (var-set max-routes new-max)
    (ok true))
)

(define-public (set-registration-fee (new-fee uint))
  (begin
    (asserts! (is-some (var-get authority-contract)) ERR-AUTHORITY-NOT-VERIFIED)
    (var-set registration-fee new-fee)
    (ok true))
)

;; ------------------------------------------------------------
;; Core entrypoints
;; ------------------------------------------------------------

(define-public (register-route
  (route-hash (buff 32))
  (description (string-utf8 500))
  (safety-level uint)
  (geolocation { lat: int, lon: int })
  (boundaries { min-lat: int, max-lat: int, min-lon: int, max-lon: int })
  (route-type (string-utf8 50))
  (distance uint)
  (elevation uint)
  (weather-condition (string-utf8 100))
  (traffic-status (string-utf8 100))
  (emergency-status bool))
  (let (
        (next-id (var-get next-route-id))
        (current-max (var-get max-routes))
        (authority-check (contract-call? .authority-management is-verified-authority tx-sender))
      )
    ;; capacity guard: require next-id < max-routes
    (asserts! (< next-id current-max) ERR-MAX-ROUTES-EXCEEDED)

    (try! (validate-hash route-hash))
    (try! (validate-description description))
    (try! (validate-safety-level safety-level))
    (try! (validate-geolocation geolocation))
    (try! (validate-boundaries boundaries))
    (try! (validate-route-type route-type))
    (try! (validate-distance distance))
    (try! (validate-elevation elevation))
    (try! (validate-weather weather-condition))
    (try! (validate-traffic traffic-status))

    (asserts! (is-ok authority-check) ERR-NOT-AUTHORIZED)

    ;; make sure the hash isn't already registered
    (asserts! (is-none (map-get? routes-by-hash route-hash)) ERR-ROUTE-ALREADY-EXISTS)

    (map-set routes next-id
      {
        hash: route-hash,
        description: description,
        safety-level: safety-level,
        geolocation: geolocation,
        boundaries: boundaries,
        timestamp: block-height,
        creator: tx-sender,
        route-type: route-type,
        distance: distance,
        elevation: elevation,
        weather-condition: weather-condition,
        traffic-status: traffic-status,
        emergency-status: emergency-status
      })

    ;; index by hash for O(1) existence checks
    (map-set routes-by-hash route-hash next-id)

    (var-set next-route-id (+ next-id u1))
    (print { event: "route-registered", id: next-id })
    (ok next-id))
)

(define-public (update-route
  (route-id uint)
  (update-hash (buff 32))
  (update-description (string-utf8 500))
  (update-safety-level uint))
  (let (
        (route (map-get? routes route-id))
        (authority-check (contract-call? .authority-management is-verified-authority tx-sender))
      )
    (match route
      r
        (begin
          (asserts! (is-eq (get creator r) tx-sender) ERR-NOT-AUTHORIZED)
          (try! (validate-hash update-hash))
          (try! (validate-description update-description))
          (try! (validate-safety-level update-safety-level))
          (asserts! (is-ok authority-check) ERR-NOT-AUTHORIZED)

          ;; prevent collision with an existing, different route
          (let ((existing (map-get? routes-by-hash update-hash)))
            (asserts!
              (or (is-none existing)
                  (is-eq (default-to uffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff existing) route-id))
              ERR-ROUTE-ALREADY-EXISTS))

          ;; keep an index consistent: drop old hash entry and set new one
          (let ((old-hash (get hash r)))
            (map-delete routes-by-hash old-hash)
            (map-set routes-by-hash update-hash route-id))

          (map-set routes route-id
            {
              hash: update-hash,
              description: update-description,
              safety-level: update-safety-level,
              geolocation: (get geolocation r),
              boundaries: (get boundaries r),
              timestamp: block-height,
              creator: tx-sender,
              route-type: (get route-type r),
              distance: (get distance r),
              elevation: (get elevation r),
              weather-condition: (get weather-condition r),
              traffic-status: (get traffic-status r),
              emergency-status: (get emergency-status r)
            })

          (map-set route-updates route-id
            {
              update-hash: update-hash,
              update-description: update-description,
              update-safety-level: update-safety-level,
              update-timestamp: block-height,
              updater: tx-sender
            })

          (print { event: "route-updated", id: route-id })
          (ok true))
      ERR-ROUTE-NOT-FOUND))
)

(define-public (get-route-count)
  (ok (var-get next-route-id))
)

(define-public (check-route-existence (hash (buff 32)))
  (ok (is-route-registered hash))
)
