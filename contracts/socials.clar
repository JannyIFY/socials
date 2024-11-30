;; Define constants
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-POST-NOT-FOUND (err u2))
(define-constant ERR-INSUFFICIENT-FUNDS (err u3))
(define-constant ERR-INVALID-POST (err u4))
(define-constant ERR-INVALID-AMOUNT (err u5))
(define-constant ERR-SELF-ACTION (err u6))

;; Define data variables
(define-data-var platform-owner principal tx-sender)
(define-data-var post-counter uint u0)

;; Define data maps
(define-map Posts uint 
  {
    author: principal,
    content-hash: (string-ascii 64),
    tips-received: uint,
    likes: uint,
    timestamp: uint
  }
)

(define-map UserProfiles principal 
  {
    username: (string-ascii 50),
    reputation-score: uint,
    total-posts: uint,
    total-earnings: uint
  }
)

(define-map Followers { follower: principal, following: principal } bool)

;; Helper functions for validation
(define-private (is-valid-post-id (post-id uint))
  (and 
    (>= post-id u1)
    (<= post-id (var-get post-counter))
  )
)

(define-private (is-valid-amount (amount uint))
  (> amount u0)
)

;; Create a new post
(define-public (create-post (content-hash (string-ascii 64)))
  (let
    (
      (post-id (+ (var-get post-counter) u1))
      (current-user-profile (default-to 
        { username: "", reputation-score: u0, total-posts: u0, total-earnings: u0 }
        (map-get? UserProfiles tx-sender)
      ))
    )
    ;; Validate content hash is not empty
    (asserts! (> (len content-hash) u0) ERR-INVALID-POST)
    
    (map-set Posts post-id
      {
        author: tx-sender,
        content-hash: content-hash,
        tips-received: u0,
        likes: u0,
        timestamp: block-height
      }
    )
    (map-set UserProfiles tx-sender
      (merge current-user-profile
        {
          total-posts: (+ (get total-posts current-user-profile) u1)
        }
      )
    )
    (var-set post-counter post-id)
    (ok post-id)
  )
)

;; Tip a post creator
(define-public (tip-post (post-id uint) (amount uint))
  (let
    (
      (post (unwrap! (map-get? Posts post-id) ERR-POST-NOT-FOUND))
      (author (get author post))
    )
    ;; Validate inputs
    (asserts! (is-valid-post-id post-id) ERR-INVALID-POST)
    (asserts! (is-valid-amount amount) ERR-INVALID-AMOUNT)
    (asserts! (not (is-eq tx-sender author)) ERR-SELF-ACTION)
    
    (let
      (
        (author-profile (unwrap! (map-get? UserProfiles author) ERR-NOT-AUTHORIZED))
        (updated-tips (+ (get tips-received post) amount))
        (updated-earnings (+ (get total-earnings author-profile) amount))
        (updated-reputation (+ (get reputation-score author-profile) u1))
      )
      
      ;; Perform STX transfer first
      (try! (stx-transfer? amount tx-sender author))
      
      ;; Update post data
      (map-set Posts post-id
        (merge post { tips-received: updated-tips })
      )
      
      ;; Update author profile
      (map-set UserProfiles author
        (merge author-profile
          {
            reputation-score: updated-reputation,
            total-earnings: updated-earnings
          }
        )
      )
      (ok true)
    )
  )
)

;; Like a post
(define-public (like-post (post-id uint))
  (let
    (
      (post (unwrap! (map-get? Posts post-id) ERR-POST-NOT-FOUND))
      (author (get author post))
    )
    ;; Validate post-id
    (asserts! (is-valid-post-id post-id) ERR-INVALID-POST)
    (asserts! (not (is-eq tx-sender author)) ERR-SELF-ACTION)
    
    (let
      (
        (author-profile (unwrap! (map-get? UserProfiles author) ERR-NOT-AUTHORIZED))
        (updated-likes (+ (get likes post) u1))
        (updated-reputation (+ (get reputation-score author-profile) u1))
      )
      
      (map-set Posts post-id
        (merge post { likes: updated-likes })
      )
      
      (map-set UserProfiles author
        (merge author-profile
          {
            reputation-score: updated-reputation
          }
        )
      )
      (ok true)
    )
  )
)

;; Follow a user
(define-public (follow-user (user-to-follow principal))
  (begin
    (asserts! (not (is-eq tx-sender user-to-follow)) ERR-SELF-ACTION)
    (asserts! (is-some (map-get? UserProfiles user-to-follow)) ERR-NOT-AUTHORIZED)
    (map-set Followers { follower: tx-sender, following: user-to-follow } true)
    (ok true)
  )
)

;; Create or update user profile
(define-public (set-profile (username (string-ascii 50)))
  (let
    (
      (current-profile (default-to 
        { username: "", reputation-score: u0, total-posts: u0, total-earnings: u0 }
        (map-get? UserProfiles tx-sender)
      ))
    )
    ;; Validate username is not empty
    (asserts! (> (len username) u0) ERR-INVALID-POST)
    
    (map-set UserProfiles tx-sender
      (merge current-profile { username: username })
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-post (post-id uint))
  (map-get? Posts post-id)
)

(define-read-only (get-user-profile (user principal))
  (map-get? UserProfiles user)
)

(define-read-only (is-following (follower principal) (following principal))
  (default-to false
    (map-get? Followers { follower: follower, following: following })
  )
)