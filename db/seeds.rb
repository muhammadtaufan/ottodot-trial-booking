# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be used by tests and demos to understand the system behavior.

puts "Seeding database..."

# ==============================================================================
# CASE 1: Class with Available Seats
# A class with capacity 4 and 1 confirmed booking, leaving 3 seats available
# ==============================================================================
puts "\n[CASE 1] Seeding: Class with available seats (1/4 booked)"

parent_1 = Parent.find_or_create_by!(name: "Alice Parent", email: "alice@example.com")
student_1 = parent_1.students.find_or_create_by!(name: "Alice Student A")

class_1 = TrialClass.find_or_create_by!(subject: "Math Basics - Available Seats Demo") do |tc|
  tc.starts_at = Time.current + 2.days
  tc.capacity = 4
end

booking_1_1 = class_1.bookings.find_or_create_by!(student_id: student_1.id) do |b|
  b.status = :confirmed
end

puts "  Parent: #{parent_1.name} (#{parent_1.email})"
puts "  Student: #{student_1.name}"
puts "  Class: #{class_1.subject} (capacity #{class_1.capacity}, starts #{class_1.starts_at})"
puts "  Booking: Student #{student_1.name} → #{booking_1_1.status} (#{class_1.bookings.confirmed.count}/#{class_1.capacity} confirmed)"
puts "  ✓ Case 1 ready: #{4 - class_1.bookings.confirmed.count} seats still available"

# ==============================================================================
# CASE 2: Class at Exactly 3 Confirmed (Boundary Case)
# A class with capacity 4 and exactly 3 confirmed students, leaving 1 seat remaining
# This is the boundary case that tests verify against for the last-seat logic
# ==============================================================================
puts "\n[CASE 2] Seeding: Class with exactly 3 confirmed (boundary case 3/4)"

parent_2 = Parent.find_or_create_by!(name: "Bob Parent", email: "bob@example.com")
student_2a = parent_2.students.find_or_create_by!(name: "Bob Student B1")
student_2b = parent_2.students.find_or_create_by!(name: "Bob Student B2")

parent_3 = Parent.find_or_create_by!(name: "Carol Parent", email: "carol@example.com")
student_2c = parent_3.students.find_or_create_by!(name: "Carol Student B3")

class_2 = TrialClass.find_or_create_by!(subject: "English Literature - Boundary Case") do |tc|
  tc.starts_at = Time.current + 3.days
  tc.capacity = 4
end

booking_2_1 = class_2.bookings.find_or_create_by!(student_id: student_2a.id) do |b|
  b.status = :confirmed
end
booking_2_2 = class_2.bookings.find_or_create_by!(student_id: student_2b.id) do |b|
  b.status = :confirmed
end
booking_2_3 = class_2.bookings.find_or_create_by!(student_id: student_2c.id) do |b|
  b.status = :confirmed
end

puts "  Parents: #{parent_2.name}, #{parent_3.name}"
puts "  Students: #{student_2a.name}, #{student_2b.name}, #{student_2c.name}"
puts "  Class: #{class_2.subject} (capacity #{class_2.capacity}, starts #{class_2.starts_at})"
puts "  Bookings: #{class_2.bookings.confirmed.count} confirmed"
puts "  ✓ Case 2 ready: exactly 3 confirmed students, 1 seat remaining (boundary for next booking)"

# ==============================================================================
# CASE 3: Confirmed Booking for Duplicate Booking Rejection Demo
# Seed a student + class pair with 1 confirmed booking to demo a live duplicate attempt
# The demo/README will show a second POST /bookings for this same student+class getting rejected
# ==============================================================================
puts "\n[CASE 3] Seeding: Confirmed booking for duplicate-booking-attempt demo"

parent_4 = Parent.find_or_create_by!(name: "Diana Parent", email: "diana@example.com")
student_3 = parent_4.students.find_or_create_by!(name: "Diana Student C")

class_3 = TrialClass.find_or_create_by!(subject: "Science Intro - Duplicate Demo") do |tc|
  tc.starts_at = Time.current + 4.days
  tc.capacity = 4
end

booking_3_1 = class_3.bookings.find_or_create_by!(student_id: student_3.id) do |b|
  b.status = :confirmed
end

puts "  Parent: #{parent_4.name} (#{parent_4.email})"
puts "  Student: #{student_3.name}"
puts "  Class: #{class_3.subject} (starts #{class_3.starts_at})"
puts "  Booking: #{booking_3_1.status}"
puts "  ✓ Case 3 ready: POST /bookings for Diana Student C + Science Intro again will be rejected with 409"

# ==============================================================================
# CASE 4: Payment Failed Booking (Excluded from Roster)
# A booking already in payment_failed status to demonstrate it doesn't occupy a seat
# ==============================================================================
puts "\n[CASE 4] Seeding: Payment failed booking (excluded from seat count)"

parent_5 = Parent.find_or_create_by!(name: "Eve Parent", email: "eve@example.com")
student_4 = parent_5.students.find_or_create_by!(name: "Eve Student D")

class_4 = TrialClass.find_or_create_by!(subject: "History Essentials - Payment Fail Demo") do |tc|
  tc.starts_at = Time.current + 5.days
  tc.capacity = 4
end

booking_4_1 = class_4.bookings.find_or_create_by!(student_id: student_4.id) do |b|
  b.status = :payment_failed
end

puts "  Parent: #{parent_5.name} (#{parent_5.email})"
puts "  Student: #{student_4.name}"
puts "  Class: #{class_4.subject} (capacity #{class_4.capacity}, starts #{class_4.starts_at})"
puts "  Booking: #{booking_4_1.status}"
puts "  Roster count (confirmed only): #{class_4.bookings.confirmed.count}/#{class_4.capacity}"
puts "  ✓ Case 4 ready: payment_failed booking excluded from roster (0 confirmed in this class)"

# ==============================================================================
# Summary
# ==============================================================================
puts "\n" + "=" * 70
puts "Seed data complete!"
puts "=" * 70
puts "4 seeded cases (subject as unique key, idempotent on re-run):"
puts "  [CASE 1] Math Basics - Available Seats Demo"
puts "  [CASE 2] English Literature - Boundary Case"
puts "  [CASE 3] Science Intro - Duplicate Demo"
puts "  [CASE 4] History Essentials - Payment Fail Demo"
puts "\nEach case is clearly labeled above with its purpose."
puts "Run `bin/rails db:seed` again to verify idempotency (no duplicates, no errors)."
