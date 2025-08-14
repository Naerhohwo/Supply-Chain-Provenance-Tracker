;; supply-chain-sentinel.clar
;;
;; This contract creates an immutable provenance log for manufacturing assets.
;; Each asset or batch is represented as a unique Non-Fungible Token (NFT).
;; The contract tracks the asset's owner and logs every custody transfer with
;; metadata, providing a transparent audit trail from source to final product.
;;
;; It also manages a list of authorized participants who can handle the assets.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Constants and Error Codes ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-constant CONTRACT_OWNER tx-sender)

;; Error Codes
(define-constant ERR_UNAUTHORIZED u200)
(define-constant ERR_ITEM_NOT_FOUND u201)
(define-constant ERR_NOT_OWNER u202)
(define-constant ERR_PARTICIPANT_ALREADY_REGISTERED u203)
(define-constant ERR_PARTICIPANT_NOT_REGISTERED u204)
(define-constant ERR_INVALID_CUSTODIAN u205)
(define-constant ERR_METADATA_TOO_LONG u206)
(define-constant ERR_EMPTY_STRING u207)
(define-constant ERR_LOG_FULL u208)

;; Constants for validation
(define-constant MAX_LOG_ENTRIES u50)
(define-constant MAX_LOCATION_LENGTH u64)
(define-constant MAX_NOTES_LENGTH u128)

;;;;;;;;;;;;;;;;;;;;;;;;
;; Data Storage       ;;
;;;;;;;;;;;;;;;;;;;;;;;;

;; Define the NFT for the tracked items/batches
(define-non-fungible-token supply-item uint)

;; Counter for the next item ID
(define-data-var last-item-id uint u0)

;; Map of authorized supply chain participants
(define-map participants principal bool)

;; Map to store the provenance log for each item
;; key: uint (item-id)
;; value: list of log entries
(define-map provenance-log uint (list 50 {
  custodian: principal,
  timestamp-burn-height: uint,
  location: (string-ascii 64),
  notes: (string-ascii 128)
}))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Private Helper Functions        ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-private (is-owner (user principal))
  (is-eq user CONTRACT_OWNER)
)

;; Validate string inputs to ensure they're not empty and within length limits
(define-private (validate-location (location (string-ascii 64)))
  (and
    (> (len location) u0)
    (<= (len location) MAX_LOCATION_LENGTH)
  )
)

(define-private (validate-notes (notes (string-ascii 128)))
  (and
    (> (len notes) u0)
    (<= (len notes) MAX_NOTES_LENGTH)
  )
)

(define-private (add-log-entry (item-id uint) (custodian principal) (location (string-ascii 64)) (notes (string-ascii 128)))
  (begin
    ;; Validate inputs
    (asserts! (validate-location location) (err ERR_EMPTY_STRING))
    (asserts! (validate-notes notes) (err ERR_EMPTY_STRING))

    (let ((new-log-entry {
      custodian: custodian,
      timestamp-burn-height: burn-block-height,
      location: location,
      notes: notes
    }))
      (let ((current-log (default-to (list) (map-get? provenance-log item-id))))
        ;; Check if log is already at max capacity
        (asserts! (< (len current-log) MAX_LOG_ENTRIES) (err ERR_LOG_FULL))

        ;; Add new entry to log
        (match (as-max-len? (append current-log new-log-entry) u50)
          updated-log (begin
            (map-set provenance-log item-id updated-log)
            (ok true)
          )
          (err ERR_LOG_FULL)
        )
      )
    )
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Public Read-Only Functions ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Get the owner of a specific supply item
(define-read-only (get-item-owner (item-id uint))
  (ok (nft-get-owner? supply-item item-id))
)

;; Get the full provenance log for a specific item
(define-read-only (get-provenance-log (item-id uint))
  (map-get? provenance-log item-id)
)

;; Check if a principal is a registered participant
(define-read-only (is-participant-registered (who principal))
  (is-some (map-get? participants who))
)

;; Get the current item count
(define-read-only (get-last-item-id)
  (var-get last-item-id)
)

;; Check if an item exists
(define-read-only (item-exists (item-id uint))
  (is-some (nft-get-owner? supply-item item-id))
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Public Transactional Functions ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Contract owner can add new authorized participants to the supply chain.
;; @param who: The principal of the new participant.
(define-public (register-participant (who principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (map-get? participants who)) (err ERR_PARTICIPANT_ALREADY_REGISTERED))
    (map-set participants who true)
    (ok true)
  )
)

;; Contract owner can remove a participant.
;; @param who: The principal of the participant to remove.
(define-public (deregister-participant (who principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (asserts! (is-some (map-get? participants who)) (err ERR_PARTICIPANT_NOT_REGISTERED))
    (map-delete participants who)
    (ok true)
  )
)

;; A registered participant can register a new item/batch on the blockchain.
;; This mints a new NFT and creates its initial provenance log entry.
;; @param initial-location: A string describing the origin location.
;; @param initial-notes: A string with notes about the new item.
(define-public (register-new-item (initial-location (string-ascii 64)) (initial-notes (string-ascii 128)))
  (begin
    (asserts! (is-some (map-get? participants tx-sender)) (err ERR_PARTICIPANT_NOT_REGISTERED))

    ;; Pre-validate inputs before processing
    (asserts! (validate-location initial-location) (err ERR_EMPTY_STRING))
    (asserts! (validate-notes initial-notes) (err ERR_EMPTY_STRING))

    (let ((item-id (+ u1 (var-get last-item-id))))
      ;; Mint the NFT to the creator (the first custodian)
      (try! (nft-mint? supply-item item-id tx-sender))
      (var-set last-item-id item-id)

      ;; Create the first log entry (inputs already validated)
      (try! (add-log-entry item-id tx-sender initial-location initial-notes))

      (print {
        type: "provenance",
        event: "item-registered",
        item-id: item-id,
        custodian: tx-sender
      })
      (ok item-id)
    )
  )
)

;; The current owner of an item can transfer custody to another registered participant.
;; This transfers the NFT and adds a new entry to the provenance log.
;; @param item-id: The ID of the item to transfer.
;; @param new-custodian: The principal of the new owner.
;; @param new-location: The current location of the item.
;; @param transfer-notes: Notes regarding the transfer.
(define-public (transfer-custody (item-id uint) (new-custodian principal) (new-location (string-ascii 64)) (transfer-notes (string-ascii 128)))
  (let ((current-owner (unwrap! (nft-get-owner? supply-item item-id) (err ERR_ITEM_NOT_FOUND))))
    ;; Check permissions and validate inputs
    (asserts! (is-eq tx-sender current-owner) (err ERR_NOT_OWNER))
    (asserts! (is-some (map-get? participants new-custodian)) (err ERR_PARTICIPANT_NOT_REGISTERED))
    (asserts! (not (is-eq tx-sender new-custodian)) (err ERR_INVALID_CUSTODIAN))

    ;; Pre-validate string inputs
    (asserts! (validate-location new-location) (err ERR_EMPTY_STRING))
    (asserts! (validate-notes transfer-notes) (err ERR_EMPTY_STRING))

    ;; Transfer the NFT
    (try! (nft-transfer? supply-item item-id tx-sender new-custodian))

    ;; Add a new log entry for the transfer (inputs already validated)
    (try! (add-log-entry item-id new-custodian new-location transfer-notes))

    (print {
      type: "provenance",
      event: "custody-transferred",
      item-id: item-id,
      from: tx-sender,
      to: new-custodian
    })
    (ok true)
  )
)