;; Campus Visit Planner Contract
;; Coordinates college tour scheduling and logistics

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-VISIT-NOT-FOUND (err u301))
(define-constant ERR-INVALID-INPUT (err u302))
(define-constant ERR-VISIT-CONFLICT (err u303))
(define-constant ERR-CAPACITY-FULL (err u304))

;; Data Variables
(define-data-var next-visit-id uint u1)
(define-data-var next-tour-id uint u1)

;; Data Maps
(define-map campus-visits
  { visit-id: uint }
  {
    student-wallet: principal,
    university-name: (string-ascii 100),
    visit-date: uint,
    tour-type: (string-ascii 50),
    status: (string-ascii 20),
    transportation: (string-ascii 50),
    accommodation: (string-ascii 100),
    created-at: uint
  }
)

(define-map tour-schedules
  { tour-id: uint }
  {
    university-name: (string-ascii 100),
    tour-date: uint,
    tour-time: uint,
    tour-type: (string-ascii 50),
    capacity: uint,
    current-bookings: uint,
    guide-name: (string-ascii 100),
    meeting-point: (string-ascii 200),
    duration-minutes: uint
  }
)

(define-map visit-feedback
  { visit-id: uint }
  {
    rating: uint,
    comments: (string-ascii 500),
    would-recommend: bool,
    submitted-at: uint
  }
)

(define-map student-visit-history
  { student-wallet: principal, university-name: (string-ascii 100) }
  { visit-id: uint, visit-count: uint }
)

;; Public Functions

;; Schedule a campus visit
(define-public (schedule-visit (university-name (string-ascii 100)) (visit-date uint) (tour-type (string-ascii 50)) (transportation (string-ascii 50)) (accommodation (string-ascii 100)))
  (let
    (
      (visit-id (var-get next-visit-id))
    )
    (asserts! (> visit-date block-height) ERR-INVALID-INPUT)
    (asserts! (> (len university-name) u0) ERR-INVALID-INPUT)

    ;; Check for visit conflicts (simplified - would check actual date conflicts)
    (asserts! (is-none (map-get? student-visit-history { student-wallet: tx-sender, university-name: university-name })) ERR-VISIT-CONFLICT)

    (map-set campus-visits
      { visit-id: visit-id }
      {
        student-wallet: tx-sender,
        university-name: university-name,
        visit-date: visit-date,
        tour-type: tour-type,
        status: "scheduled",
        transportation: transportation,
        accommodation: accommodation,
        created-at: block-height
      }
    )

    (map-set student-visit-history
      { student-wallet: tx-sender, university-name: university-name }
      { visit-id: visit-id, visit-count: u1 }
    )

    (var-set next-visit-id (+ visit-id u1))
    (ok visit-id)
  )
)

;; Create tour schedule (admin only)
(define-public (create-tour-schedule (university-name (string-ascii 100)) (tour-date uint) (tour-time uint) (tour-type (string-ascii 50)) (capacity uint) (guide-name (string-ascii 100)) (meeting-point (string-ascii 200)) (duration-minutes uint))
  (let
    (
      (tour-id (var-get next-tour-id))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> tour-date block-height) ERR-INVALID-INPUT)
    (asserts! (> capacity u0) ERR-INVALID-INPUT)
    (asserts! (> duration-minutes u0) ERR-INVALID-INPUT)

    (map-set tour-schedules
      { tour-id: tour-id }
      {
        university-name: university-name,
        tour-date: tour-date,
        tour-time: tour-time,
        tour-type: tour-type,
        capacity: capacity,
        current-bookings: u0,
        guide-name: guide-name,
        meeting-point: meeting-point,
        duration-minutes: duration-minutes
      }
    )

    (var-set next-tour-id (+ tour-id u1))
    (ok tour-id)
  )
)

;; Book a tour slot
(define-public (book-tour (tour-id uint) (visit-id uint))
  (let
    (
      (tour (unwrap! (map-get? tour-schedules { tour-id: tour-id }) ERR-VISIT-NOT-FOUND))
      (visit (unwrap! (map-get? campus-visits { visit-id: visit-id }) ERR-VISIT-NOT-FOUND))
    )
    (asserts! (is-eq (get student-wallet visit) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (< (get current-bookings tour) (get capacity tour)) ERR-CAPACITY-FULL)
    (asserts! (is-eq (get university-name tour) (get university-name visit)) ERR-INVALID-INPUT)

    (map-set tour-schedules
      { tour-id: tour-id }
      (merge tour { current-bookings: (+ (get current-bookings tour) u1) })
    )

    (ok true)
  )
)

;; Update visit status
(define-public (update-visit-status (visit-id uint) (new-status (string-ascii 20)))
  (let
    (
      (visit (unwrap! (map-get? campus-visits { visit-id: visit-id }) ERR-VISIT-NOT-FOUND))
    )
    (asserts! (is-eq (get student-wallet visit) tx-sender) ERR-NOT-AUTHORIZED)

    (map-set campus-visits
      { visit-id: visit-id }
      (merge visit { status: new-status })
    )

    (ok true)
  )
)

;; Submit visit feedback
(define-public (submit-feedback (visit-id uint) (rating uint) (comments (string-ascii 500)) (would-recommend bool))
  (let
    (
      (visit (unwrap! (map-get? campus-visits { visit-id: visit-id }) ERR-VISIT-NOT-FOUND))
    )
    (asserts! (is-eq (get student-wallet visit) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (and (<= rating u5) (> rating u0)) ERR-INVALID-INPUT)
    (asserts! (is-eq (get status visit) "completed") ERR-INVALID-INPUT)

    (map-set visit-feedback
      { visit-id: visit-id }
      {
        rating: rating,
        comments: comments,
        would-recommend: would-recommend,
        submitted-at: block-height
      }
    )

    (ok true)
  )
)

;; Cancel visit
(define-public (cancel-visit (visit-id uint))
  (let
    (
      (visit (unwrap! (map-get? campus-visits { visit-id: visit-id }) ERR-VISIT-NOT-FOUND))
    )
    (asserts! (is-eq (get student-wallet visit) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> (get visit-date visit) block-height) ERR-INVALID-INPUT)

    (map-set campus-visits
      { visit-id: visit-id }
      (merge visit { status: "cancelled" })
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get campus visit details
(define-read-only (get-visit (visit-id uint))
  (map-get? campus-visits { visit-id: visit-id })
)

;; Get tour schedule
(define-read-only (get-tour-schedule (tour-id uint))
  (map-get? tour-schedules { tour-id: tour-id })
)

;; Get visit feedback
(define-read-only (get-feedback (visit-id uint))
  (map-get? visit-feedback { visit-id: visit-id })
)

;; Get student visit history
(define-read-only (get-visit-history (student-wallet principal) (university-name (string-ascii 100)))
  (map-get? student-visit-history { student-wallet: student-wallet, university-name: university-name })
)

;; Check tour availability
(define-read-only (is-tour-available (tour-id uint))
  (match (map-get? tour-schedules { tour-id: tour-id })
    tour (< (get current-bookings tour) (get capacity tour))
    false
  )
)

;; Get available tour slots
(define-read-only (get-available-slots (tour-id uint))
  (match (map-get? tour-schedules { tour-id: tour-id })
    tour (- (get capacity tour) (get current-bookings tour))
    u0
  )
)

;; Check if visit is upcoming
(define-read-only (is-visit-upcoming (visit-id uint))
  (match (map-get? campus-visits { visit-id: visit-id })
    visit (and (> (get visit-date visit) block-height) (is-eq (get status visit) "scheduled"))
    false
  )
)
