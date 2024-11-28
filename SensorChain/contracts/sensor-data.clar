;; IoT Sensor Data Marketplace
;; A decentralized marketplace for IoT sensor data trading

;; Constants for subscription tiers
(define-constant BRONZE u1)
(define-constant SILVER u2)
(define-constant GOLD u3)

;; Constants for minimum requirements
(define-constant MIN-STAKE-AMOUNT u1000)
(define-constant MIN-QUALITY-SCORE u60)
(define-constant MINIMUM-PRICE u100)

;; Constants for validation
(define-constant MAX-SENSOR-ID u1000000)
(define-constant MAX-DURATION u52560) ;; Max duration ~1 year in blocks
(define-constant MAX-SUBSCRIPTION-PRICE u1000000)

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-INVALID-PARAMS (err u400))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-INSUFFICIENT-FUNDS (err u402))

;; Data structures (remain unchanged)
(define-map sensors
  { sensor-id: uint }
  {
    owner: principal,
    stake-amount: uint,
    registration-time: uint,
    sensor-type: (string-utf8 64),
    location: (string-utf8 128),
    active: bool,
    total-data-points: uint,
    quality-score: uint
  }
)

(define-map sensor-data
  { sensor-id: uint, timestamp: uint }
  {
    data-hash: (buff 32),
    quality-score: uint,
    price: uint,
    metadata: (string-utf8 256)
  }
)

(define-map subscriptions
  { buyer: principal }
  {
    tier: uint,
    expiry: uint,
    active: bool
  }
)

(define-map data-access
  { buyer: principal, sensor-id: uint }
  {
    access-until: uint,
    tier: uint
  }
)

;; Principal variables
(define-data-var contract-owner principal tx-sender)
(define-data-var platform-fee uint u50)

;; Input validation functions
(define-private (validate-sensor-id (sensor-id uint))
  (and 
    (> sensor-id u0)
    (<= sensor-id MAX-SENSOR-ID)))

(define-private (validate-duration (duration uint))
  (and 
    (> duration u0)
    (<= duration MAX-DURATION)))

(define-private (validate-string-not-empty (str (string-utf8 256)))
  (> (len str) u0))

(define-private (validate-data-hash (hash (buff 32)))
  (> (len hash) u0))

(define-private (validate-subscription-tier (tier uint))
  (or (is-eq tier BRONZE)
      (is-eq tier SILVER)
      (is-eq tier GOLD)))

;; Administrative functions (remain unchanged)
(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (<= new-fee u1000) ERR-INVALID-PARAMS)
    (ok (var-set platform-fee new-fee))))

;; Enhanced sensor registration
(define-public (register-sensor 
    (sensor-id uint)
    (sensor-type (string-utf8 64))
    (location (string-utf8 128)))
  (let
    ((stake-amount MIN-STAKE-AMOUNT))
    (begin
      (asserts! (validate-sensor-id sensor-id) ERR-INVALID-PARAMS)
      (asserts! (validate-string-not-empty sensor-type) ERR-INVALID-PARAMS)
      (asserts! (validate-string-not-empty location) ERR-INVALID-PARAMS)
      (asserts! (not (default-to false (get active (map-get? sensors {sensor-id: sensor-id})))) ERR-INVALID-PARAMS)
      (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
      (ok (map-set sensors
        {sensor-id: sensor-id}
        {
          owner: tx-sender,
          stake-amount: stake-amount,
          registration-time: block-height,
          sensor-type: sensor-type,
          location: location,
          active: true,
          total-data-points: u0,
          quality-score: u100
        })))))

;; Enhanced sensor deactivation
(define-public (deactivate-sensor (sensor-id uint))
  (let
    ((sensor (unwrap! (map-get? sensors {sensor-id: sensor-id}) ERR-NOT-FOUND)))
    (begin
      (asserts! (validate-sensor-id sensor-id) ERR-INVALID-PARAMS)
      (asserts! (is-eq (get owner sensor) tx-sender) ERR-UNAUTHORIZED)
      (try! (as-contract (stx-transfer? (get stake-amount sensor) (as-contract tx-sender) tx-sender)))
      (ok (map-set sensors
        {sensor-id: sensor-id}
        (merge sensor {active: false}))))))

;; Enhanced data submission
(define-public (submit-sensor-data
    (sensor-id uint)
    (data-hash (buff 32))
    (price uint)
    (metadata (string-utf8 256)))
  (let
    ((sensor (unwrap! (map-get? sensors {sensor-id: sensor-id}) ERR-NOT-FOUND))
     (quality-score (calculate-quality-score sensor-id)))
    (begin
      (asserts! (validate-sensor-id sensor-id) ERR-INVALID-PARAMS)
      (asserts! (validate-data-hash data-hash) ERR-INVALID-PARAMS)  ;; Add this line
      (asserts! (validate-string-not-empty metadata) ERR-INVALID-PARAMS)
      (asserts! (is-eq (get owner sensor) tx-sender) ERR-UNAUTHORIZED)
      (asserts! (get active sensor) ERR-UNAUTHORIZED)
      (asserts! (>= quality-score MIN-QUALITY-SCORE) ERR-INVALID-PARAMS)
      (asserts! (>= price MINIMUM-PRICE) ERR-INVALID-PARAMS)
      (ok (map-set sensor-data
        {sensor-id: sensor-id, timestamp: block-height}
        {
          data-hash: data-hash,
          quality-score: quality-score,
          price: price,
          metadata: metadata
        })))))

;; Enhanced subscription management
(define-public (purchase-subscription 
    (tier uint)
    (duration uint))
  (let
    ((price (calculate-subscription-price tier duration)))
    (begin
      (asserts! (validate-subscription-tier tier) ERR-INVALID-PARAMS)  ;; Add this line
      (asserts! (validate-duration duration) ERR-INVALID-PARAMS)
      (asserts! (<= price MAX-SUBSCRIPTION-PRICE) ERR-INVALID-PARAMS)
      (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
      (ok (map-set subscriptions
        {buyer: tx-sender}
        {
          tier: tier,
          expiry: (+ block-height duration),
          active: true
        })))))

;; Enhanced data access management
(define-public (purchase-data-access
    (sensor-id uint)
    (duration uint))
  (let
    ((sensor-info (unwrap! (map-get? sensors {sensor-id: sensor-id}) ERR-NOT-FOUND))
     (subscription (unwrap! (map-get? subscriptions {buyer: tx-sender}) ERR-UNAUTHORIZED))
     (latest-data (unwrap! (map-get? sensor-data {sensor-id: sensor-id, timestamp: block-height}) ERR-NOT-FOUND)))
    (begin
      (asserts! (validate-sensor-id sensor-id) ERR-INVALID-PARAMS)
      (asserts! (validate-duration duration) ERR-INVALID-PARAMS)
      (asserts! (get active subscription) ERR-UNAUTHORIZED)
      (asserts! (get active sensor-info) ERR-NOT-FOUND)
      (try! (stx-transfer? (get price latest-data) tx-sender (get owner sensor-info)))
      (ok (map-set data-access
        {buyer: tx-sender, sensor-id: sensor-id}
        {
          access-until: (+ block-height duration),
          tier: (get tier subscription)
        })))))

;; Helper functions (remain unchanged)
(define-private (calculate-quality-score (sensor-id uint))
  (let
    ((sensor (unwrap! (map-get? sensors {sensor-id: sensor-id}) u0)))
    (if (>= (get total-data-points sensor) u1000)
        u95
        u80)))

(define-private (calculate-subscription-price (tier uint) (duration uint))
  (let
    ((base-price-per-block u10))
    (* base-price-per-block
       duration
       (if (is-eq tier GOLD)
           u3
           (if (is-eq tier SILVER)
               u2
               u1)))))

;; Read-only functions (remain unchanged)
(define-read-only (get-sensor-info (sensor-id uint))
  (map-get? sensors {sensor-id: sensor-id}))

(define-read-only (get-latest-sensor-data (sensor-id uint))
  (map-get? sensor-data {sensor-id: sensor-id, timestamp: block-height}))

(define-read-only (check-data-access (buyer principal) (sensor-id uint))
  (let
    ((access-info (map-get? data-access {buyer: buyer, sensor-id: sensor-id})))
    (and
      (is-some access-info)
      (< block-height (get access-until (unwrap! access-info false))))))

(define-read-only (get-subscription-info (buyer principal))
  (map-get? subscriptions {buyer: buyer}))