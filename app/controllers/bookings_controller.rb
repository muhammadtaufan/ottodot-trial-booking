class BookingsController < ApplicationController
  # JSON API requests don't send CSRF tokens (no cookie-based session auth).
  # HTML form requests include CSRF tokens automatically via Rails form helpers.
  # Use before_action to conditionally skip CSRF verification for JSON-only requests.
  before_action :skip_csrf_for_json_api
  before_action :default_to_json_format

  private

  def skip_csrf_for_json_api
    # Skip CSRF verification only for JSON API requests
    # This allows the JSON endpoints to work without CSRF tokens while HTML forms
    # still verify tokens (Rails default protect_from_forgery behavior)
    skip_forgery_protection if request.format.json? ||
                              (params[:format].nil? &&
                               request.content_type&.include?("application/json"))
  end

  public

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
      error_response = {
        errors: [
          {
            status: "409",
            title: "Duplicate booking",
            detail: "A confirmed booking already exists for this student and trial class"
          }
        ]
      }

      if request.format.html?
        flash[:alert] = "A confirmed booking already exists for this student and trial class"
        redirect_to trial_classes_path(format: :html)
      else
        render json: error_response, status: :conflict
      end
      return
    end

    booking = Booking.create!(
      student_id: student_id,
      trial_class_id: trial_class_id,
      status: :pending_payment
    )

    if request.format.html?
      redirect_to booking_path(booking, format: :html)
    else
      render json: { data: booking_data(booking) }, status: :created
    end
  end

  def show
    booking = Booking.find(params[:id])

    if request.format.html?
      @booking = booking
      @trial_class = booking.trial_class
      @student = booking.student
    else
      render json: { data: booking_data(booking) }
    end
  rescue ActiveRecord::RecordNotFound
    error_response = {
      errors: [
        {
          status: "404",
          title: "Not found",
          detail: "Booking not found"
        }
      ]
    }

    if request.format.html?
      flash[:alert] = "Booking not found"
      redirect_to trial_classes_path(format: :html)
    else
      render json: error_response, status: :not_found
    end
  end

  def pay
    booking = Booking.find(params[:id])
    simulate_param = params.permit(:simulate).fetch(:simulate, "success")
    confirmed_booking = Booking::Confirmation.new(booking, simulate: simulate_param).call

    if request.format.html?
      @booking = confirmed_booking
      @trial_class = confirmed_booking.trial_class
      @student = confirmed_booking.student
      render :show
    else
      render json: { data: booking_data(confirmed_booking) }
    end
  rescue ActiveRecord::RecordNotFound
    error_response = {
      errors: [
        {
          status: "404",
          title: "Not found",
          detail: "Booking not found"
        }
      ]
    }

    if request.format.html?
      flash[:alert] = "Booking not found"
      redirect_to trial_classes_path(format: :html)
    else
      render json: error_response, status: :not_found
    end
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
