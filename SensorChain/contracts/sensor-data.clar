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

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-INVALID-PARAMS (err u400))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-INSUFFICIENT-FUNDS (err u402))

;; Data structures

;; Sensor registration details
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

;; Sensor data entries
(define-map sensor-data
  { sensor-id: uint, timestamp: uint }
  {
    data-hash: (buff 32),
    quality-score: uint,
    price: uint,
    metadata: (string-utf8 256)
  }
)

;; Subscription tiers for buyers
(define-map subscriptions
  { buyer: principal }
  {
    tier: uint,
    expiry: uint,
    active: bool
  }
)

;; Access control for data buyers
(define-map data-access
  { buyer: principal, sensor-id: uint }
  {
    access-until: uint,
    tier: uint
  }
)

;; Principal variables
(define-data-var contract-owner principal tx-sender)
(define-data-var platform-fee uint u50) ;; 5% fee in basis points

;; Administrative functions

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (asserts! (<= new-fee u1000) ERR-INVALID-PARAMS)
    (ok (var-set platform-fee new-fee))))

;; Sensor registration and management

(define-public (register-sensor 
    (sensor-id uint)
    (sensor-type (string-utf8 64))
    (location (string-utf8 128)))
  (let
    ((stake-amount MIN-STAKE-AMOUNT))
    (begin
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

(define-public (deactivate-sensor (sensor-id uint))
  (let
    ((sensor (unwrap! (map-get? sensors {sensor-id: sensor-id}) ERR-NOT-FOUND)))
    (begin
      (asserts! (is-eq (get owner sensor) tx-sender) ERR-UNAUTHORIZED)
      (try! (as-contract (stx-transfer? (get stake-amount sensor) (as-contract tx-sender) tx-sender)))
      (ok (map-set sensors
        {sensor-id: sensor-id}
        (merge sensor {active: false}))))))

;; Data submission and management

(define-public (submit-sensor-data
    (sensor-id uint)
    (data-hash (buff 32))
    (price uint)
    (metadata (string-utf8 256)))
  (let
    ((sensor (unwrap! (map-get? sensors {sensor-id: sensor-id}) ERR-NOT-FOUND))
     (quality-score (calculate-quality-score sensor-id)))
    (begin
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

;; Subscription management

(define-public (purchase-subscription 
    (tier uint)
    (duration uint))
  (let
    ((price (calculate-subscription-price tier duration)))
    (begin
      (asserts! (or (is-eq tier BRONZE) (is-eq tier SILVER) (is-eq tier GOLD)) ERR-INVALID-PARAMS)
      (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
      (ok (map-set subscriptions
        {buyer: tx-sender}
        {
          tier: tier,
          expiry: (+ block-height duration),
          active: true
        })))))

;; Data access management

(define-public (purchase-data-access
    (sensor-id uint)
    (duration uint))
  (let
    ((sensor-info (unwrap! (map-get? sensors {sensor-id: sensor-id}) ERR-NOT-FOUND))
     (subscription (unwrap! (map-get? subscriptions {buyer: tx-sender}) ERR-UNAUTHORIZED))
     (latest-data (unwrap! (map-get? sensor-data {sensor-id: sensor-id, timestamp: block-height}) ERR-NOT-FOUND)))
    (begin
      (asserts! (get active subscription) ERR-UNAUTHORIZED)
      (asserts! (get active sensor-info) ERR-NOT-FOUND)
      (try! (stx-transfer? (get price latest-data) tx-sender (get owner sensor-info)))
      (ok (map-set data-access
        {buyer: tx-sender, sensor-id: sensor-id}
        {
          access-until: (+ block-height duration),
          tier: (get tier subscription)
        })))))

;; Helper functions

(define-private (calculate-quality-score (sensor-id uint))
  (let
    ((sensor (unwrap! (map-get? sensors {sensor-id: sensor-id}) u0)))
    ;; Simplified quality score calculation
    ;; In reality, this would involve complex validation logic
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

;; Read-only functions

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