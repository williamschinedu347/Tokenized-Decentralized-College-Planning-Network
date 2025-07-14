;; Financial Aid Optimizer Contract
;; Identifies scholarships and grant opportunities

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-OPPORTUNITY-NOT-FOUND (err u201))
(define-constant ERR-INVALID-INPUT (err u202))
(define-constant ERR-APPLICATION-EXISTS (err u203))
(define-constant ERR-INSUFFICIENT-FUNDS (err u204))

;; Data Variables
(define-data-var next-opportunity-id uint u1)
(define-data-var next-aid-application-id uint u1)

;; Data Maps
(define-map financial-opportunities
  { opportunity-id: uint }
  {
    name: (string-ascii 100),
    provider: (string-ascii 100),
    amount: uint,
    deadline: uint,
    gpa-requirement: uint,
    income-limit: uint,
    major-requirement: (string-ascii 50),
    status: (string-ascii 20),
    created-at: uint
  }
)

(define-map aid-applications
  { aid-application-id: uint }
  {
    student-wallet: principal,
    opportunity-id: uint,
    amount-requested: uint,
    status: (string-ascii 20),
    submitted-at: uint,
    decision-date: (optional uint)
  }
)

(define-map student-aid-profile
  { student-wallet: principal }
  {
    family-income: uint,
    financial-need: uint,
    current-aid-total: uint,
    preferred-majors: (string-ascii 200),
    updated-at: uint
  }
)

(define-map opportunity-applications
  { student-wallet: principal, opportunity-id: uint }
  { aid-application-id: uint }
)

;; Public Functions

;; Create financial aid profile
(define-public (create-aid-profile (family-income uint) (financial-need uint) (preferred-majors (string-ascii 200)))
  (begin
    (asserts! (> financial-need u0) ERR-INVALID-INPUT)
    (asserts! (>= family-income u0) ERR-INVALID-INPUT)

    (map-set student-aid-profile
      { student-wallet: tx-sender }
      {
        family-income: family-income,
        financial-need: financial-need,
        current-aid-total: u0,
        preferred-majors: preferred-majors,
        updated-at: block-height
      }
    )

    (ok true)
  )
)

;; Add financial opportunity (admin only)
(define-public (add-opportunity (name (string-ascii 100)) (provider (string-ascii 100)) (amount uint) (deadline uint) (gpa-requirement uint) (income-limit uint) (major-requirement (string-ascii 50)))
  (let
    (
      (opportunity-id (var-get next-opportunity-id))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (> deadline block-height) ERR-INVALID-INPUT)
    (asserts! (<= gpa-requirement u400) ERR-INVALID-INPUT)

    (map-set financial-opportunities
      { opportunity-id: opportunity-id }
      {
        name: name,
        provider: provider,
        amount: amount,
        deadline: deadline,
        gpa-requirement: gpa-requirement,
        income-limit: income-limit,
        major-requirement: major-requirement,
        status: "active",
        created-at: block-height
      }
    )

    (var-set next-opportunity-id (+ opportunity-id u1))
    (ok opportunity-id)
  )
)

;; Apply for financial aid
(define-public (apply-for-aid (opportunity-id uint) (amount-requested uint))
  (let
    (
      (aid-application-id (var-get next-aid-application-id))
      (opportunity (unwrap! (map-get? financial-opportunities { opportunity-id: opportunity-id }) ERR-OPPORTUNITY-NOT-FOUND))
    )
    (asserts! (is-none (map-get? opportunity-applications { student-wallet: tx-sender, opportunity-id: opportunity-id })) ERR-APPLICATION-EXISTS)
    (asserts! (> amount-requested u0) ERR-INVALID-INPUT)
    (asserts! (<= amount-requested (get amount opportunity)) ERR-INVALID-INPUT)
    (asserts! (> (get deadline opportunity) block-height) ERR-INVALID-INPUT)
    (asserts! (is-eq (get status opportunity) "active") ERR-INVALID-INPUT)

    (map-set aid-applications
      { aid-application-id: aid-application-id }
      {
        student-wallet: tx-sender,
        opportunity-id: opportunity-id,
        amount-requested: amount-requested,
        status: "pending",
        submitted-at: block-height,
        decision-date: none
      }
    )

    (map-set opportunity-applications
      { student-wallet: tx-sender, opportunity-id: opportunity-id }
      { aid-application-id: aid-application-id }
    )

    (var-set next-aid-application-id (+ aid-application-id u1))
    (ok aid-application-id)
  )
)

;; Update aid application status (admin only)
(define-public (update-aid-status (aid-application-id uint) (new-status (string-ascii 20)))
  (let
    (
      (application (unwrap! (map-get? aid-applications { aid-application-id: aid-application-id }) ERR-OPPORTUNITY-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set aid-applications
      { aid-application-id: aid-application-id }
      (merge application {
        status: new-status,
        decision-date: (some block-height)
      })
    )

    (ok true)
  )
)

;; Update aid profile
(define-public (update-aid-profile (family-income uint) (financial-need uint) (current-aid-total uint) (preferred-majors (string-ascii 200)))
  (let
    (
      (existing-profile (unwrap! (map-get? student-aid-profile { student-wallet: tx-sender }) ERR-INVALID-INPUT))
    )
    (asserts! (> financial-need u0) ERR-INVALID-INPUT)
    (asserts! (>= family-income u0) ERR-INVALID-INPUT)
    (asserts! (>= current-aid-total u0) ERR-INVALID-INPUT)

    (map-set student-aid-profile
      { student-wallet: tx-sender }
      {
        family-income: family-income,
        financial-need: financial-need,
        current-aid-total: current-aid-total,
        preferred-majors: preferred-majors,
        updated-at: block-height
      }
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get financial opportunity
(define-read-only (get-opportunity (opportunity-id uint))
  (map-get? financial-opportunities { opportunity-id: opportunity-id })
)

;; Get aid application
(define-read-only (get-aid-application (aid-application-id uint))
  (map-get? aid-applications { aid-application-id: aid-application-id })
)

;; Get student aid profile
(define-read-only (get-aid-profile (student-wallet principal))
  (map-get? student-aid-profile { student-wallet: student-wallet })
)

;; Check if student is eligible for opportunity
(define-read-only (is-eligible-for-opportunity (student-wallet principal) (opportunity-id uint))
  (match (map-get? financial-opportunities { opportunity-id: opportunity-id })
    opportunity
      (match (map-get? student-aid-profile { student-wallet: student-wallet })
        profile
          (and
            (<= (get family-income profile) (get income-limit opportunity))
            (> (get deadline opportunity) block-height)
            (is-eq (get status opportunity) "active")
          )
        false
      )
    false
  )
)

;; Get matching opportunities for student
(define-read-only (get-matching-opportunities-count (student-wallet principal))
  (match (map-get? student-aid-profile { student-wallet: student-wallet })
    profile u1  ;; Simplified - would iterate through opportunities in real implementation
    u0
  )
)

;; Calculate remaining financial need
(define-read-only (get-remaining-financial-need (student-wallet principal))
  (match (map-get? student-aid-profile { student-wallet: student-wallet })
    profile
      (if (> (get financial-need profile) (get current-aid-total profile))
        (- (get financial-need profile) (get current-aid-total profile))
        u0
      )
    u0
  )
)
