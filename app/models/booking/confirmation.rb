class Booking::Confirmation
  def initialize(booking, simulate: "success")
    @booking = booking
    @simulate = simulate
  end

  def call
    ActiveRecord::Base.transaction do
      payment_succeeded = PaymentGateway.charge(simulate: @simulate)

      if !payment_succeeded
        @booking.update!(status: :payment_failed)
        @booking.payment_attempts.create!(status: :failed)
        return @booking
      end

      # Payment succeeded - now check seat availability with lock
      @booking.trial_class.with_lock do
        confirmed_count = @booking.trial_class.bookings.confirmed.count
        
        if confirmed_count >= @booking.trial_class.capacity
          @booking.update!(status: :seat_unavailable)
          @booking.payment_attempts.create!(status: :succeeded, note: "seat lost to race")
        else
          @booking.update!(status: :confirmed)
          @booking.payment_attempts.create!(status: :succeeded)
        end
      end

      @booking
    end
  end
end
