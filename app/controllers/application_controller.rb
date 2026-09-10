class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  protected

  # Default to JSON format for API requests; HTML requests use Accept header or .html extension
  def default_to_json_format
    # Strategy: distinguish HTML requests (browser) from JSON API requests
    # - Explicit .html path → HTML
    # - Accept header with text/html as FIRST preference (q=1.0 or no q) → HTML (real browser)
    # - Otherwise (RSpec with q=0.9, or explicit JSON APIs) → JSON
    # - Explicit format param → use that

    if params[:format].nil?
      accept_header = request.headers["Accept"].to_s

      if request.path.end_with?(".html")
        # Explicit .html path → HTML
        request.format = :html
      elsif accept_header.start_with?("text/html") || accept_header.start_with?("text/html;")
        # Real browser with text/html as first preference → HTML
        request.format = :html
      else
        # API request or generic accept (RSpec, curl) → JSON
        request.format = :json
      end
    end
  end
end
