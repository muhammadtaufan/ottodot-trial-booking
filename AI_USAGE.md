# AI Usage in This Project

## Tools and Process

This Rails application was built with Claude Code (Anthropic's CLI coding agent) throughout the implementation. The development process included a self-review loop where an independent AI pass reviewed the code and tests before they were committed to ensure quality and catch issues that might not be apparent in a single pass.

## What AI Was Used For

AI directly wrote or generated the following components:

- **Scaffolding the Rails application** — generating models, migrations, controllers, and RESTful endpoint structure for students, trial classes, bookings, and payment attempts
- **Implementing core booking and payment logic** — writing the `Booking` model with status state transitions, the `Booking::Confirmation` service object that handles payment confirmation and seat availability checks, and the business rules for trial class capacity enforcement and payment validation
- **Implementing race condition protection** — writing the database row lock mechanism (via Rails' `with_lock` method in the `Booking::Confirmation` service object) to guarantee exactly one successful booking when multiple concurrent requests attempt to book the final seat in a trial class
- **Writing RSpec request specifications** — generating comprehensive test suites including edge cases (last-seat race contention, payment validations, invalid parameters, missing required fields)
- **Generating seed data** — creating realistic test scenarios in database migrations to populate students, trial classes, and booking fixtures
- **Writing this documentation**

## Where AI Accelerated Development

Generating the full CRUD scaffolding (models, migrations, controllers, seed data covering several edge cases) was quick and freed time to focus on the genuinely hard part: the concurrency and race-condition logic. Without AI, the repetitive setup work would have consumed hours; instead, the effort could be concentrated on the novel, challenging aspects of the implementation.

## Where AI Output Was Wrong and How It Was Caught

A critical bug was discovered during code review that illustrates the importance of independent verification:

### The Race Condition Test Bug

A request spec for the last-seat race condition was written to verify that two concurrent booking attempts for the final seat in a trial class would result in exactly one success and one failure. The test initially reported as passing reliably when the row lock was in place and failing reliably when the lock was removed — exactly the behavior we wanted to see.

However, when an independent re-run of that same test was executed (as part of a second review pass), the results were completely different: **the test failed consistently even with the row lock in place**. This suggested the lock wasn't actually being tested properly.

**Root Cause:** The test was driving both concurrent "threads" through Rails' HTTP test helpers (`post '/bookings/:id/pay'`). Rails' test infrastructure shares a single underlying database session object per test example, and this object is not thread-safe. The two simulated requests were corrupting each other's state — stepping on each other's database transaction state and response buffers — rather than genuinely racing against the database row lock.

**The Fix:** Each thread needed to call the payment confirmation service object directly (`Booking::Confirmation.new(...).call`) instead of routing through the simulated HTTP layer. Crucially, each thread also needed its own connection from the connection pool via `ActiveRecord::Base.connection_pool.with_connection`. This allowed the two threads to actually contend on the database row lock as two real concurrent requests would:

```ruby
# Before (broken): HTTP layer, shared session
thread1 = Thread.new { post '/bookings/:id/pay', params: {...} }
thread2 = Thread.new { post '/bookings/:id/pay', params: {...} }

# After (correct): Direct service call, each thread gets own connection
thread1 = Thread.new do
  ActiveRecord::Base.connection_pool.with_connection do
    Booking::Confirmation.new(booking_a, simulate: "success").call
  end
end

thread2 = Thread.new do
  ActiveRecord::Base.connection_pool.with_connection do
    Booking::Confirmation.new(booking_b, simulate: "success").call
  end
end
```

The test also had to disable transactional fixtures (`self.use_transactional_tests = false`) to allow actual concurrent database access rather than the default Rails behavior of wrapping each test in a transaction.

**Verification:** After the fix, the test passed reliably with the lock in place. To confirm the logic was actually protecting against the race condition (and not just passing for other reasons), the row lock was deliberately disabled in the `Booking::Confirmation` service and the test was re-run multiple times. The test then failed reliably across multiple runs. Once the lock was re-enabled, the test passed reliably again. This deliberate break-and-restore cycle provided genuine proof the logic works, not just "the test turned green once."

### Earlier Corrections

Two smaller issues were also caught during the code-review pass:

1. **Unreachable state transition** — An early design diagram claimed a state transition that had no corresponding code path in the actual implementation. The code was reviewed and the diagram was corrected to match the real implementation.

2. **Schema/code mismatch** — A field was referenced in the booking confirmation logic before a corresponding migration column existed. The migration was fixed to ensure the schema matched what the code expected, preventing a runtime error.

## What to Do Differently Next Time

Run concurrency-sensitive tests through an independent second pass earlier in development, rather than trusting a single execution's report of pass/fail counts. The bug described above (the test environment's shared session corrupting multi-threaded state) would have been caught immediately if the test had been run twice from the beginning. That single extra check would have surfaced the issue much sooner and prevented the false confidence that a seemingly green test provides.

## Final Verification

The final implementation was verified as follows:

- **Row lock verification** — The row lock (via Rails' `with_lock` mechanism in the `Booking::Confirmation` service object) was confirmed to prevent double-booking by:
  1. Running the race-condition test with the lock in place (passes reliably across multiple runs)
  2. Deliberately disabling the `with_lock` guard in the `Booking::Confirmation` code and re-running the test (fails reliably across multiple runs with both threads sometimes getting the confirmed status)
  3. Re-enabling the lock and running again (passes reliably again with exactly one confirmed and one seat_unavailable result)
  
  This break-and-restore cycle confirms the lock is actually doing the work, not just that the test happens to pass.

- **Payment confirmation logic** — The booking confirmation and payment state transitions were verified through RSpec request specs covering valid payments, failed payments, capacity limits, and the race condition scenario. The specs verify that:
  - Payments update the booking status appropriately (confirmed, payment_failed, or seat_unavailable)
  - Payment attempts are recorded with the correct status and notes
  - The confirmed count never exceeds the trial class capacity

- **Schema consistency** — Database migrations were verified to create all required columns (status enums, foreign keys, payment attempt tracking) before they are referenced in the code.
