class BookingsController < ApplicationController
  def create
    booking_params = params.permit(:student_id, :trial_class_id)
    student_id = booking_params.require(:student_id)
    trial_class_id = booking_params.require(:trial_class_id)

    # Check for existing confirmed booking
    existing_confirmed = Booking.find_by(
      student_id: student_id,
      trial_class_id: trial_class_id,
      status: :confirmed
    )

    if existing_confirmed
      return render json: {
        errors: [
          {
            status: "409",
            title: "Duplicate booking",
            detail: "A confirmed booking already exists for this student and trial class"
          }
        ]
      }, status: :conflict
    end

    booking = Booking.create!(
      student_id: student_id,
      trial_class_id: trial_class_id,
      status: :pending_payment
    )

    render json: { data: booking_data(booking) }, status: :created
  end

  def show
    booking = Booking.find(params[:id])
    render json: { data: booking_data(booking) }
  rescue ActiveRecord::RecordNotFound
    render json: {
      errors: [
        {
          status: "404",
          title: "Not found",
          detail: "Booking not found"
        }
      ]
    }, status: :not_found
  end

  def pay
    booking = Booking.find(params[:id])
    simulate_param = params.permit(:simulate).fetch(:simulate, "success")
    confirmed_booking = Booking::Confirmation.new(booking, simulate: simulate_param).call
    render json: { data: booking_data(confirmed_booking) }
  rescue ActiveRecord::RecordNotFound
    render json: {
      errors: [
        {
          status: "404",
          title: "Not found",
          detail: "Booking not found"
        }
      ]
    }, status: :not_found
  end

  private

  def booking_data(booking)
    {
      id: booking.id,
      status: booking.status,
      student_id: booking.student_id,
      trial_class_id: booking.trial_class_id,
      student: {
        id: booking.student.id,
        name: booking.student.name
      },
      trial_class: {
        id: booking.trial_class.id,
        subject: booking.trial_class.subject,
        capacity: booking.trial_class.capacity
      },
      created_at: booking.created_at,
      updated_at: booking.updated_at
    }
  end
end
