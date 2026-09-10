# Trial Booking Backend

A Rails 8 backend for a trial class booking system where parents can book trial lessons for their children (students), process payments, and manage seat capacity.

## How to Run the Solution

### Prerequisites
- Docker and Docker Compose (for the database)
- Ruby 3.3+
- Bundler

### Setup Steps

1. **Start the PostgreSQL database:**
   ```bash
   docker compose up -d db
   ```

2. **Install dependencies and prepare the database:**
   ```bash
   bin/setup --skip-server
   ```
   
   This script will:
   - Run `bundle install`
   - Create the database, run migrations, and seed with sample trial classes
   - Clear logs and temp files
   - Skip starting the dev server (since we're passing `--skip-server`)

3. **Start the Rails server:**
   ```bash
   bin/rails s
   ```
   The API will be available at `http://localhost:3000`

4. **Run tests:**
   ```bash
   bundle exec rspec
   ```

## What You Built

A trial booking system with the following features:

- **Trial class listing**: Parents browse available trial classes (with subject, schedule, and remaining seats).
- **Booking creation**: Parent selects a child (student) and a trial class, creating a pending booking.
- **Simulated payment processing**: The booking payment flow with controllable outcomes (success or failure via a query parameter).
- **Booking status tracking**: Each booking transitions through states: `pending_payment` → `confirmed`, `payment_failed`, or `seat_unavailable`.
- **Teacher/admin roster view**: View which students are confirmed for a specific trial class.
- **Seat capacity management**: Each trial class has a fixed capacity (default 4 seats); once full, subsequent bookings are marked `seat_unavailable` rather than confirmed.
- **Duplicate-booking prevention**: A student cannot have more than one confirmed booking for the same trial class.

### API Endpoints

- `GET /trial_classes` – List all trial classes with available seats.
- `GET /trial_classes/:id/roster` – Get confirmed students enrolled in a trial class.
- `POST /bookings` – Create a new booking (requires `student_id` and `trial_class_id`).
- `GET /bookings/:id` – Retrieve a booking's status and details.
- `POST /bookings/:id/pay` – Process payment and confirm the booking (pass `simulate=fail` to simulate payment failure).

## Time Spent

Approximately **3–4 hours**, including:
- Understanding the requirements and designing the data model.
- Implementing the core booking and payment flow with concurrency handling.
- Writing comprehensive tests, including a multi-threaded race condition test.
- Deploying a Docker Compose PostgreSQL setup.

## Assumptions Made

- **No real payment gateway**: Payment processing is mocked via a `PaymentGateway` service. Pass `simulate=fail` to the pay endpoint to test failure scenarios; otherwise, payment succeeds.
- **No notifications or emails**: Bookings do not trigger confirmation emails or status notifications.
- **Capacity is fixed per trial class**: Defaults to 4 students but is configurable per class.
- **No waitlist or cancellation**: Once a booking exists, it cannot be cancelled. If a seat becomes unavailable due to the race condition, the payment succeeds but the booking is marked `seat_unavailable`; a new booking can be created to retry.

## Key Architecture & Backend Decisions

### Technology Stack
- **Rails 8.1** monolith with **PostgreSQL 16** database (not SQLite).
- PostgreSQL was chosen because the duplicate-booking defense leverages a **partial unique index** on `(student_id, trial_class_id) WHERE status = 'confirmed'`, which is cleanly supported by Postgres but not in SQLite.

### Concurrency & Seat Claiming Strategy
- **Pessimistic locking** using `trial_class.with_lock` (Rails' `SELECT ... FOR UPDATE`) serializes the critical section where seat availability is checked and a booking is confirmed.
- **Single source of truth for seat count**: The number of confirmed bookings is computed live via a SQL count (`trial_class.bookings.confirmed.count`), not stored in a separate column. This avoids the complexity of decrementing a counter on cancellation and reduces the risk of skew between the actual bookings and a cached seat count.
- **Seat claiming happens at payment time**, not at booking creation. Creating a booking only creates a `pending_payment` row—no seat is held, so no locking is needed. This allows parents to start a booking without blocking other customers.

### Booking Status States
```
pending_payment  → The parent has created a booking but not yet paid.
confirmed        → Payment succeeded and a seat was available.
payment_failed   → The payment processor rejected the charge.
seat_unavailable → Payment succeeded but the class reached capacity before
                   the booking could be confirmed (lost to a race).
```

The distinction between `payment_failed` and `seat_unavailable` is intentional: they represent genuinely different outcomes. `seat_unavailable` tells the parent "your payment went through, but someone else got the last seat; you can retry or try a different class." `payment_failed` means "the payment itself was rejected."

### Duplicate-Booking Prevention (Two Layers)
1. **Application-level check**: Before initiating payment, a `BookingsController#create` checks if a confirmed booking already exists for `(student_id, trial_class_id)`. If so, returns a 409 Conflict immediately.
2. **Database-level constraint**: A **partial unique index** on `(student_id, trial_class_id) WHERE status = 1` prevents two confirmed bookings for the same student-class pair, even if the app layer's check is bypassed.

The index is scoped to `status = 1` (confirmed only) by design: a `payment_failed` or `seat_unavailable` booking does not block the student from trying to book again. This allows for safe retries.

### Transaction Safety
All booking confirmations happen inside `ActiveRecord::Base.transaction`, ensuring atomicity:
- Payment is recorded.
- If payment fails, the booking is marked `payment_failed` and the transaction rolls back (no seat is lost).
- If payment succeeds, the trial class is locked, the confirmed count is checked, and the booking status is updated—all before the transaction commits.

## What Was Deliberately Cut

Given the timeboxed nature of this exercise, the following were intentionally excluded:

- **Email Notifications**: No confirmation or status emails.
- **Waitlist**: Full classes can only offer the `seat_unavailable` outcome; no queue for the next available slot.
- **Background Jobs**: No async processing (e.g., email delivery, report generation).
- **Cancellation Flow**: No endpoint to cancel a confirmed booking. This would require a `cancelled` status, a refund/void mechanism, and reversal logic.
- **Real Payment Gateway Integration**: Only a mock payment processor.
- **Web UI**: This is an API-only backend. Clients would integrate via HTTP requests.
- **Idempotency Keys**: No protection against duplicate payments if a client retries the pay endpoint.
- **Soft Deletes**: No support for recovering deleted bookings or students.

## Monitoring After Release

To ensure the system's correctness and health, monitor the following:

1. **Confirmed booking count vs. capacity**: For each trial class, verify that `COUNT(bookings WHERE status = 'confirmed')` never exceeds the class's `capacity`. This should always be zero if the locking mechanism is working correctly (any violation would indicate a concurrency bug).

2. **Payment success rate**: Track the percentage of bookings that transition to `confirmed` vs. `payment_failed` vs. `seat_unavailable`. A sudden spike in failures or a shift in the distribution suggests a payment processor issue or a bug.

3. **Seat unavailability frequency**: Monitor how often bookings end up in the `seat_unavailable` state. If this is very high, the trial class capacity may be too low; if zero in high-traffic times, demand might exceed supply.

4. **Booking retry patterns**: Track how many students retry after `payment_failed` or `seat_unavailable`. A low retry rate might indicate poor user experience or inadequate retry guidance.

5. **Database lock contention**: Monitor lock wait times on the `trial_classes` table during payment spikes. High contention is expected but should not cause cascading timeouts.

## What You'd Do Next with More Time

1. **Idempotency keys**: Add an idempotency key to the pay endpoint, stored in a `BookingPaymentAttempt` table. Allow clients to safely retry failed payment requests without creating duplicate payment records.

2. **Refund / void flow**: Implement a `refund` endpoint for `seat_unavailable` bookings. After a refund, the booking transitions to a `refunded` status and can no longer transition to `confirmed`.

3. **Stale booking cleanup**: A background job to auto-expire bookings stuck in `pending_payment` for more than (e.g.) 30 minutes, freeing the student to try again without admin intervention.

4. **Waitlist**: For full classes, allow students to join a waitlist. If a confirmed booking is cancelled (future), automatically confirm the next waitlist student.

5. **Notifications**: Email confirmations, payment receipts, and "a seat opened up" alerts to waitlisted parents.

6. **Audit logging**: Store a log of all state changes (booking creation, payment attempts, status transitions) for compliance and debugging.

7. **API versioning**: Namespace routes under `/api/v1/` before any external client depends on the current shape, so breaking changes (e.g. status enum additions) don't require a coordinated client migration later.

8. **Caching for read-heavy endpoints**: `GET /trial_classes` recomputes `seats_remaining` from a live `COUNT` on every request. Under real traffic this is the first thing to cache — a short-TTL Redis cache invalidated on booking confirmation, or at minimum an `ETag`/conditional-GET so clients polling for seat availability don't re-fetch the full payload every time.

9. **More targeted indexing under load**: the current schema indexes `trial_class_id` and `student_id` individually. The hot-path query (`trial_class.bookings.confirmed.count`, run inside the lock on every `pay` call) would benefit from a composite index on `(trial_class_id, status)` once there's real write volume — it's not needed at this dataset size but is the first index to add before the lock's hold time starts to matter.

10. **Pagination**: `GET /trial_classes` and the roster endpoint return full result sets. Fine at seed-data scale; would need cursor or offset pagination once a deployment has more than a handful of classes or a roster grows past a page.

11. **Lock contention handling at higher scale**: the pessimistic lock (see tradeoffs above) assumes low-to-moderate contention. At genuinely high concurrent-payment volume for the same class, the next step would be either a bounded retry-with-backoff around the lock acquisition (instead of letting a request hang/timeout) or moving the seat-claim into a queued worker that processes confirmations for a given class serially.

## Last-Seat Race: Approach, Rationale, and Tradeoffs

### The Problem

When two parents race to book the last available seat, both can succeed at the payment step in separate requests. Without proper concurrency control, both could incorrectly end up with a `confirmed` status, violating the capacity constraint.

### The Solution: Pessimistic Locking

The chosen approach uses **pessimistic (row) locking** via `trial_class.with_lock`:

```ruby
@booking.trial_class.with_lock do
  confirmed_count = @booking.trial_class.bookings.confirmed.count
  
  if confirmed_count >= @booking.trial_class.capacity
    @booking.update!(status: :seat_unavailable)
  else
    @booking.update!(status: :confirmed)
  end
end
```

When Thread A acquires the lock on the trial class row, Thread B blocks until the lock is released. This serializes the count-and-decide step:

1. Thread A reads the lock (e.g., count = 3 / capacity = 4).
2. Thread A finds a seat available, confirms its booking, and releases the lock.
3. Thread B acquires the lock and reads the same row (now with Thread A's confirmation visible).
4. Thread B reads the new count (4 / capacity = 4) and marks its booking `seat_unavailable`.

The outcome is **deterministic and fair**: exactly one booking wins, regardless of arrival order.

### Why Pessimistic Locking Over Optimistic Locking

An alternative is **optimistic locking** (version columns + retry loops):

- Add a `version` column to `trial_classes`.
- Thread A reads version (v=1, count=3), confirms booking, increments version (v=2).
- Thread B reads version (v=1), tries to confirm with the old version, fails, and retries.
- On retry, Thread B reads version (v=2, count=4) and transitions to `seat_unavailable`.

**Why pessimistic was chosen:**
- **Simpler reasoning**: A lock serializes all access to the row, eliminating the need for retry logic or version checking.
- **Narrow contention window**: Lock is held only during the payment step (microseconds). Retrying a version mismatch could incur latency if many threads miss and must retry.
- **Easier testing**: The pessimistic approach's correctness is straightforward to verify; optimistic retries are harder to test for edge cases.
- **Within the time budget**: Building a robust retry loop is more code; pessimistic locking is three lines.

**Tradeoff accepted:**
- If contention were very high (e.g., thousands of parents booking simultaneously), pessimistic locking could cause lock timeouts and cascade into transaction failures. Optimistic locking would avoid this by allowing retries without blocking.
- For the expected scale of a trial-booking system (dozens to hundreds of concurrent bookings per day), pessimistic locking is both simpler and adequate.

### How Correctness Was Verified

The implementation includes a **concurrent test** (`spec/requests/bookings_spec.rb`, "concurrent bookings (race condition)" block) that:
1. Creates 3 confirmed bookings for a class with capacity 4 (leaving 1 seat).
2. Creates 2 pending bookings that will race for the last seat.
3. Spawns 2 threads, each calling `Booking::Confirmation.new(...).call` on a separate DB connection (simulating concurrent requests).
4. Asserts that exactly one booking ends up `confirmed` and the other is `seat_unavailable`.

To further verify the lock's necessity, the test was run **with the lock removed** (`with_lock` replaced with direct `count` and `update`), confirming that the race condition manifests reliably: both bookings would sometimes end up `confirmed`, exceeding capacity. With the lock in place, the test always passes.
