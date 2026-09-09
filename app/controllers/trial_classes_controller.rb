class TrialClassesController < ApplicationController
  def index
    trial_classes = TrialClass.all
    confirmed_counts = Booking.confirmed.group(:trial_class_id).count

    data = trial_classes.map do |trial_class|
      confirmed_count = confirmed_counts[trial_class.id] || 0
      {
        id: trial_class.id,
        subject: trial_class.subject,
        starts_at: trial_class.starts_at,
        capacity: trial_class.capacity,
        seats_remaining: trial_class.seats_remaining(confirmed_count)
      }
    end

    render json: { data: data }
  end

  def roster
    trial_class = TrialClass.find(params[:id])
    students = trial_class.bookings.confirmed.includes(:student).map do |booking|
      {
        id: booking.student.id,
        name: booking.student.name
      }
    end

    render json: { data: students }
  end
end
