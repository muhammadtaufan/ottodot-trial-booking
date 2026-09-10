require 'rails_helper'

RSpec.describe "Bookings API", type: :request do
  let(:student) { create(:student) }
  let(:trial_class) { create(:trial_class, capacity: 4) }

  describe "POST /bookings" do
    context "with valid parameters" do
      it "creates a booking with pending_payment status" do
        expect {
          post "/bookings", params: {
            student_id: student.id,
            trial_class_id: trial_class.id
          }
        }.to change(Booking, :count).by(1)

        expect(response).to have_http_status(:created)
        parsed = JSON.parse(response.body)
        expect(parsed["data"]["status"]).to eq("pending_payment")
        expect(parsed["data"]["student_id"]).to eq(student.id)
        expect(parsed["data"]["trial_class_id"]).to eq(trial_class.id)
      end
    end

    context "when a confirmed booking already exists" do
      before { create(:booking, :confirmed, student: student, trial_class: trial_class) }

      it "returns 409 conflict and does not create a new booking" do
        expect {
          post "/bookings", params: {
            student_id: student.id,
            trial_class_id: trial_class.id
          }
        }.not_to change(Booking, :count)

        expect(response).to have_http_status(:conflict)
        parsed = JSON.parse(response.body)
        expect(parsed["errors"][0]["status"]).to eq("409")
        expect(parsed["errors"][0]["title"]).to eq("Duplicate booking")
      end
    end

    context "when a payment_failed booking exists for the same student and class" do
      before { create(:booking, :payment_failed, student: student, trial_class: trial_class) }

      it "allows creating a new booking (retry case)" do
        expect {
          post "/bookings", params: {
            student_id: student.id,
            trial_class_id: trial_class.id
          }
        }.to change(Booking, :count).by(1)

        expect(response).to have_http_status(:created)
        parsed = JSON.parse(response.body)
        expect(parsed["data"]["status"]).to eq("pending_payment")
      end
    end

    context "when a seat_unavailable booking exists for the same student and class" do
      before { create(:booking, :seat_unavailable, student: student, trial_class: trial_class) }

      it "allows creating a new booking (retry case)" do
        expect {
          post "/bookings", params: {
            student_id: student.id,
            trial_class_id: trial_class.id
          }
        }.to change(Booking, :count).by(1)

        expect(response).to have_http_status(:created)
        parsed = JSON.parse(response.body)
        expect(parsed["data"]["status"]).to eq("pending_payment")
      end
    end
  end

  describe "GET /bookings/:id" do
    let(:booking) { create(:booking, student: student, trial_class: trial_class) }

    it "returns the booking with student and trial_class data" do
      get "/bookings/#{booking.id}"

      expect(response).to have_http_status(:ok)
      parsed = JSON.parse(response.body)
      expect(parsed["data"]["id"]).to eq(booking.id)
      expect(parsed["data"]["status"]).to eq("pending_payment")
      expect(parsed["data"]["student"]["id"]).to eq(student.id)
      expect(parsed["data"]["student"]["name"]).to eq(student.name)
      expect(parsed["data"]["trial_class"]["id"]).to eq(trial_class.id)
      expect(parsed["data"]["trial_class"]["subject"]).to eq(trial_class.subject)
      expect(parsed["data"]["trial_class"]["capacity"]).to eq(trial_class.capacity)
    end

    it "returns 404 for non-existent booking" do
      get "/bookings/99999"

      expect(response).to have_http_status(:not_found)
      parsed = JSON.parse(response.body)
      expect(parsed["errors"][0]["status"]).to eq("404")
    end
  end

  describe "POST /bookings/:id/pay" do
    let(:booking) { create(:booking, :pending_payment, student: student, trial_class: trial_class) }

    context "with successful payment" do
      it "confirms the booking when seats are available" do
        post "/bookings/#{booking.id}/pay", params: { simulate: "success" }

        expect(response).to have_http_status(:ok)
        booking.reload
        expect(booking.status).to eq("confirmed")
        
        payment_attempt = booking.payment_attempts.last
        expect(payment_attempt.status).to eq("succeeded")
      end
    end

    context "with failed payment" do
      it "marks booking as payment_failed" do
        post "/bookings/#{booking.id}/pay", params: { simulate: "fail" }

        expect(response).to have_http_status(:ok)
        booking.reload
        expect(booking.status).to eq("payment_failed")
        
        payment_attempt = booking.payment_attempts.last
        expect(payment_attempt.status).to eq("failed")
      end

      it "does not include the failed booking in confirmed count" do
        post "/bookings/#{booking.id}/pay", params: { simulate: "fail" }

        confirmed_count = trial_class.bookings.confirmed.count
        expect(confirmed_count).to eq(0)
      end
    end

    context "at capacity" do
      it "confirms bookings up to capacity and marks excess as seat_unavailable" do
        # Create 3 confirmed bookings
        3.times do
          b = create(:booking, :confirmed, trial_class: trial_class)
        end

        # Create 4th booking (should confirm)
        fourth_booking = create(:booking, :pending_payment, trial_class: trial_class)
        post "/bookings/#{fourth_booking.id}/pay", params: { simulate: "success" }
        fourth_booking.reload
        expect(fourth_booking.status).to eq("confirmed")
        expect(trial_class.bookings.confirmed.count).to eq(4)

        # Create 5th booking (should mark as seat_unavailable)
        fifth_booking = create(:booking, :pending_payment, trial_class: trial_class)
        post "/bookings/#{fifth_booking.id}/pay", params: { simulate: "success" }
        fifth_booking.reload
        
        expect(fifth_booking.status).to eq("seat_unavailable")
        
        # Check payment attempt has the race note
        payment_attempt = fifth_booking.payment_attempts.last
        expect(payment_attempt.status).to eq("succeeded")
        expect(payment_attempt.note).to eq("seat lost to race")
        
        # Confirmed count should still be 4
        expect(trial_class.bookings.confirmed.count).to eq(4)
      end
    end

    context "concurrent bookings (race condition)" do
      # Disable transactional fixtures for this example to allow concurrent DB access
      self.use_transactional_tests = false

      after do
        # Manual cleanup since transactional fixtures are disabled
        # Delete in order to respect foreign key constraints
        PaymentAttempt.delete_all
        Booking.delete_all
        Student.delete_all
        TrialClass.delete_all
        Parent.delete_all
      end

      it "ensures exactly one booking gets the last seat under concurrent payment attempts" do
        # Create class at exactly 3 confirmed (capacity 4, so 1 seat left)
        trial_class_race = create(:trial_class, capacity: 4)
        3.times do
          create(:booking, :confirmed, trial_class: trial_class_race)
        end

        # Create two pending bookings that will race for the last seat
        booking_a = create(:booking, :pending_payment, trial_class: trial_class_race)
        booking_b = create(:booking, :pending_payment, trial_class: trial_class_race)

        results = {}
        threads = []

        # Thread A attempts payment
        threads << Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            post "/bookings/#{booking_a.id}/pay", params: { simulate: "success" }
            booking_a.reload
            results[:a_status] = booking_a.status
          end
        end

        # Thread B attempts payment
        threads << Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            post "/bookings/#{booking_b.id}/pay", params: { simulate: "success" }
            booking_b.reload
            results[:b_status] = booking_b.status
          end
        end

        # Wait for both threads to complete
        threads.each(&:join)

        # Verify exactly one is confirmed and one is seat_unavailable
        confirmed_count = trial_class_race.bookings.confirmed.count
        expect(confirmed_count).to eq(4)

        statuses = [results[:a_status], results[:b_status]].sort
        expect(statuses).to match_array(["confirmed", "seat_unavailable"])

        # Verify the race loser has proper payment attempt note
        if results[:a_status] == "seat_unavailable"
          booking_a.reload
          expect(booking_a.payment_attempts.last.note).to eq("seat lost to race")
        end
        if results[:b_status] == "seat_unavailable"
          booking_b.reload
          expect(booking_b.payment_attempts.last.note).to eq("seat lost to race")
        end
      end
    end
  end
end
