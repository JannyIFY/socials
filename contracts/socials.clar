;; Define constants
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-POST-NOT-FOUND (err u2))
(define-constant ERR-INSUFFICIENT-FUNDS (err u3))

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
      (author-profile (default-to 
        { username: "", reputation-score: u0, total-posts: u0, total-earnings: u0 }
        (map-get? UserProfiles author)
      ))
    )
    (try! (stx-transfer? amount tx-sender author))
    (map-set Posts post-id
      (merge post { tips-received: (+ (get tips-received post) amount) })
    )
    (map-set UserProfiles author
      (merge author-profile
        {
          reputation-score: (+ (get reputation-score author-profile) u1),
          total-earnings: (+ (get total-earnings author-profile) amount)
        }
      )
    )
    (ok true)
  )
)

;; Like a post
(define-public (like-post (post-id uint))
  (let
    (
      (post (unwrap! (map-get? Posts post-id) ERR-POST-NOT-FOUND))
      (author (get author post))
      (author-profile (default-to 
        { username: "", reputation-score: u0, total-posts: u0, total-earnings: u0 }
        (map-get? UserProfiles author)
      ))
    )
    (map-set Posts post-id
      (merge post { likes: (+ (get likes post) u1) })
    )
    (map-set UserProfiles author
      (merge author-profile
        {
          reputation-score: (+ (get reputation-score author-profile) u1)
        }
      )
    )
    (ok true)
  )
)

;; Follow a user
(define-public (follow-user (user-to-follow principal))
  (begin
    (asserts! (not (is-eq tx-sender user-to-follow)) ERR-NOT-AUTHORIZED)
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